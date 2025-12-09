import 'dart:async';
import '../services/searxng_service.dart';
import 'llm_service.dart';

/// DeepSearch結果
class DeepSearchResult {
  final String query;
  final List<SearchResult> searchResults;
  final String summary;
  final List<String> sources;
  final DateTime timestamp;

  DeepSearchResult({
    required this.query,
    required this.searchResults,
    required this.summary,
    required this.sources,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// DeepSearchサービス - 複数ソースから深い調査を行う
class DeepSearchService {
  final SearxngService _searxng;
  final LlmService _llm;

  DeepSearchService({
    required SearxngService searxng,
    required LlmService llm,
  })  : _searxng = searxng,
        _llm = llm;

  /// 深い調査を実行
  Future<DeepSearchResult> research(
    String query, {
    int maxSources = 5,
    Function(String)? onProgress,
  }) async {
    onProgress?.call('検索クエリを分析中...');
    
    // 1. メインクエリで検索
    final mainResults = await _searxng.search(query, maxResults: maxSources);
    onProgress?.call('${mainResults.length}件の検索結果を取得');

    if (mainResults.isEmpty) {
      return DeepSearchResult(
        query: query,
        searchResults: [],
        summary: '検索結果が見つかりませんでした。',
        sources: [],
      );
    }

    // 2. 関連クエリを生成
    onProgress?.call('関連キーワードを分析中...');
    final relatedQueries = await _generateRelatedQueries(query);
    
    // 3. 関連クエリでも検索
    final allResults = [...mainResults];
    for (final relatedQuery in relatedQueries.take(2)) {
      onProgress?.call('「$relatedQuery」で検索中...');
      try {
        final results = await _searxng.search(relatedQuery, maxResults: 3);
        allResults.addAll(results);
      } catch (e) {
        // 関連検索エラーは無視
      }
    }

    // 4. 重複を除去
    final uniqueResults = _deduplicateResults(allResults);
    onProgress?.call('${uniqueResults.length}件のソースを分析中...');

    // 5. 結果を要約
    final summary = await _synthesizeResults(query, uniqueResults);
    onProgress?.call('完了');

    return DeepSearchResult(
      query: query,
      searchResults: uniqueResults,
      summary: summary,
      sources: uniqueResults.map((r) => r.url).toList(),
    );
  }

  /// 関連クエリを生成
  Future<List<String>> _generateRelatedQueries(String query) async {
    try {
      final response = await _llm.getChatCompletion([
        _createSystemMessage(),
        _createUserMessage('''
以下のクエリに関連する検索キーワードを3つ生成してください。
各キーワードは改行で区切って出力してください。

クエリ: $query
'''),
      ]);

      return response
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('-') && !s.startsWith('*'))
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 検索結果を統合・要約
  Future<String> _synthesizeResults(String query, List<SearchResult> results) async {
    final context = SearxngService.formatForContext(results);
    
    try {
      return await _llm.getChatCompletion([
        _createSystemMessage(),
        _createUserMessage('''
以下のWeb検索結果を基に、「$query」について包括的な回答を作成してください。

$context

回答作成のルール:
1. 複数のソースからの情報を統合する
2. 重要な事実やデータを含める
3. 情報源を明記する（例: [出典1]）
4. 信頼性が低い情報には注意書きを付ける
5. 回答は日本語で作成する
'''),
      ]);
    } catch (e) {
      return '情報の統合中にエラーが発生しました: $e';
    }
  }

  /// 重複結果を除去
  List<SearchResult> _deduplicateResults(List<SearchResult> results) {
    final seen = <String>{};
    return results.where((r) {
      final normalized = r.url.toLowerCase().replaceAll(RegExp(r'/$'), '');
      if (seen.contains(normalized)) {
        return false;
      }
      seen.add(normalized);
      return true;
    }).toList();
  }

  dynamic _createSystemMessage() {
    return {
      'role': 'system',
      'content': 'あなたは情報収集と分析の専門家です。Web検索結果を分析し、正確で有益な情報を提供してください。',
    };
  }

  dynamic _createUserMessage(String content) {
    return {
      'role': 'user',
      'content': content,
    };
  }
}
