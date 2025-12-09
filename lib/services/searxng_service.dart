import 'dart:convert';
import 'package:http/http.dart' as http;

/// SearXNG検索結果
class SearchResult {
  final String title;
  final String url;
  final String content;
  final String? engine;
  final double? score;

  SearchResult({
    required this.title,
    required this.url,
    required this.content,
    this.engine,
    this.score,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      content: json['content'] ?? '',
      engine: json['engine'],
      score: json['score']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'content': content,
    'engine': engine,
    'score': score,
  };
}

/// SearXNG設定
class SearchConfig {
  final String baseUrl;
  final int maxResults;
  final List<String> engines;
  final String language;
  final bool safesearch;

  const SearchConfig({
    this.baseUrl = 'http://192.168.1.24:8081',
    this.maxResults = 10,
    this.engines = const ['google', 'bing', 'duckduckgo'],
    this.language = 'ja',
    this.safesearch = true,
  });

  SearchConfig copyWith({
    String? baseUrl,
    int? maxResults,
    List<String>? engines,
    String? language,
    bool? safesearch,
  }) {
    return SearchConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      maxResults: maxResults ?? this.maxResults,
      engines: engines ?? this.engines,
      language: language ?? this.language,
      safesearch: safesearch ?? this.safesearch,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'maxResults': maxResults,
    'engines': engines,
    'language': language,
    'safesearch': safesearch,
  };

  factory SearchConfig.fromJson(Map<String, dynamic> json) {
    return SearchConfig(
      baseUrl: json['baseUrl'] ?? 'http://192.168.1.24:8081',
      maxResults: json['maxResults'] ?? 10,
      engines: List<String>.from(json['engines'] ?? ['google', 'bing', 'duckduckgo']),
      language: json['language'] ?? 'ja',
      safesearch: json['safesearch'] ?? true,
    );
  }
}

/// SearXNGサービス
class SearxngService {
  final SearchConfig config;
  final http.Client _client;

  SearxngService({
    this.config = const SearchConfig(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Web検索を実行
  Future<List<SearchResult>> search(String query, {int? maxResults}) async {
    final limit = maxResults ?? config.maxResults;
    
    final uri = Uri.parse('${config.baseUrl}/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'language': config.language,
        'safesearch': config.safesearch ? '1' : '0',
        'engines': config.engines.join(','),
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?)?.take(limit) ?? [];

      return results
          .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  /// 接続テスト
  Future<bool> testConnection() async {
    try {
      final response = await _client.get(
        Uri.parse(config.baseUrl),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 検索結果をAI用のコンテキストに変換
  static String formatForContext(List<SearchResult> results) {
    if (results.isEmpty) {
      return '検索結果はありませんでした。';
    }

    final buffer = StringBuffer();
    buffer.writeln('【Web検索結果】');
    buffer.writeln();

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('${i + 1}. ${r.title}');
      buffer.writeln('   URL: ${r.url}');
      buffer.writeln('   ${r.content}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  void dispose() {
    _client.close();
  }
}
