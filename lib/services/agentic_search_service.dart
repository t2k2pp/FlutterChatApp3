import '../models/message.dart';
import '../services/searxng_service.dart';
import 'llm_provider.dart';

/// Agentic検索設定
class AgenticSearchConfig {
  final bool enabled;                // 有効/無効
  final int maxAutoSearches;         // 自動検索の最大回数
  final int minQueryLength;          // 検索トリガーの最小クエリ長

  const AgenticSearchConfig({
    this.enabled = true,
    this.maxAutoSearches = 2,
    this.minQueryLength = 10,
  });

  AgenticSearchConfig copyWith({
    bool? enabled,
    int? maxAutoSearches,
    int? minQueryLength,
  }) {
    return AgenticSearchConfig(
      enabled: enabled ?? this.enabled,
      maxAutoSearches: maxAutoSearches ?? this.maxAutoSearches,
      minQueryLength: minQueryLength ?? this.minQueryLength,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxAutoSearches': maxAutoSearches,
    'minQueryLength': minQueryLength,
  };

  factory AgenticSearchConfig.fromJson(Map<String, dynamic> json) {
    return AgenticSearchConfig(
      enabled: json['enabled'] as bool? ?? true,
      maxAutoSearches: json['maxAutoSearches'] as int? ?? 2,
      minQueryLength: json['minQueryLength'] as int? ?? 10,
    );
  }
}

/// Agentic検索結果
class AgenticSearchResult {
  final bool searchPerformed;        // 検索を実行したか
  final String? searchReason;        // 検索理由
  final List<SearchResult> results;  // 検索結果
  final String? enhancedContext;     // 強化されたコンテキスト

  const AgenticSearchResult({
    required this.searchPerformed,
    this.searchReason,
    this.results = const [],
    this.enhancedContext,
  });
}

/// Agentic検索サービス - 通常会話時にAIが必要と判断した際に自動検索
class AgenticSearchService {
  final SearxngService _searxng;
  final LlmProvider _llm;
  final AgenticSearchConfig config;

  AgenticSearchService({
    required SearxngService searxng,
    required LlmProvider llm,
    this.config = const AgenticSearchConfig(),
  })  : _searxng = searxng,
        _llm = llm;

  /// メッセージを分析し、必要であればWeb検索を実行
  Future<AgenticSearchResult> analyzeAndSearch(
    List<Message> conversationHistory,
    String userMessage,
  ) async {
    if (!config.enabled) {
      return const AgenticSearchResult(searchPerformed: false);
    }

    if (userMessage.length < config.minQueryLength) {
      return const AgenticSearchResult(searchPerformed: false);
    }

    // Step 1: 検索が必要かどうかを判断
    final needsSearch = await _analyzeNeedForSearch(
      conversationHistory,
      userMessage,
    );

    if (!needsSearch.needed) {
      return const AgenticSearchResult(searchPerformed: false);
    }

    // Step 2: 検索クエリを生成
    final searchQuery = needsSearch.suggestedQuery ?? userMessage;

    // Step 3: 検索を実行
    try {
      final results = await _searxng.search(searchQuery, maxResults: 5);
      
      if (results.isEmpty) {
        return AgenticSearchResult(
          searchPerformed: true,
          searchReason: needsSearch.reason,
          results: [],
        );
      }

      // Step 4: 検索結果をコンテキストとして整形
      final context = SearxngService.formatForContext(results);

      return AgenticSearchResult(
        searchPerformed: true,
        searchReason: needsSearch.reason,
        results: results,
        enhancedContext: context,
      );
    } catch (e) {
      return AgenticSearchResult(
        searchPerformed: true,
        searchReason: needsSearch.reason,
        results: [],
      );
    }
  }

  /// 検索が必要かどうかを分析
  Future<_SearchNeedAnalysis> _analyzeNeedForSearch(
    List<Message> history,
    String userMessage,
  ) async {
    // 明らかに検索が不要なケース
    if (_isSimpleGreeting(userMessage)) {
      return _SearchNeedAnalysis(needed: false);
    }

    // 明らかに検索が必要なケース（時事的なキーワード）
    if (_containsTimelyKeywords(userMessage)) {
      return _SearchNeedAnalysis(
        needed: true,
        reason: '最新情報が必要と判断',
        suggestedQuery: userMessage,
      );
    }

    try {
      // LLMに判断を委ねる
      final response = await _llm.getChatCompletion([
        Message(
          role: MessageRole.system,
          content: '''あなたは検索の必要性を判断する専門家です。

ユーザーのメッセージに対して、Web検索が必要かどうかを判断してください。

【検索が有効なケース】
- 正確に回答できる自信がない場合
- 最新情報や時事ニュースが必要な場合
- ユーザーから調査・検索を求められた場合
- 創作でアイデアを拾いたい場合
- 最新ライブラリの知識が必要な場合

【検索が不要なケース】
- 挨拶や雑談
- 文章の修正依頼（構造化、敬語、誤字脱字チェック）
- 「検索せずに答えて」と言われた場合
- 一般的な知識で回答できる場合

【回答フォーマット】
検索が必要な場合：
{"needsSearch": true, "query": "検索キーワード"}

検索が不要な場合：
{"needsSearch": false}

※必ずJSON形式のみで回答してください。説明文は不要です。''',
        ),
        Message(
          role: MessageRole.user,
          content: userMessage,
        ),
      ]);

      // JSONを抽出
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = _parseSimpleJson(jsonMatch.group(0)!);
        return _SearchNeedAnalysis(
          needed: json['needsSearch'] == true || json['needsSearch'] == 'true',
          reason: json['reason'] as String?,
          suggestedQuery: json['query'] as String?,
        );
      }

      return _SearchNeedAnalysis(needed: false);
    } catch (e) {
      // エラー時は検索しない
      return _SearchNeedAnalysis(needed: false);
    }
  }

  /// 簡単な挨拶かどうか
  bool _isSimpleGreeting(String message) {
    final greetings = ['こんにちは', 'おはよう', 'こんばんは', 'ありがとう', 'よろしく', 'はい', 'いいえ', 'ok', 'thanks'];
    final lower = message.toLowerCase().trim();
    return greetings.any((g) => lower == g || lower.startsWith('$g '));
  }

  /// 時事的なキーワードを含むか
  bool _containsTimelyKeywords(String message) {
    final keywords = ['最新', '今日', '昨日', '今週', '今月', '2024', '2025', 'ニュース', '速報', '現在の', '最近の'];
    return keywords.any((k) => message.contains(k));
  }

  /// 簡易JSONパーサー
  Map<String, dynamic> _parseSimpleJson(String jsonStr) {
    try {
      final result = <String, dynamic>{};
      
      // needsSearch抽出（キャメルケース対応）
      if (jsonStr.contains('"needsSearch": true') || jsonStr.contains('"needsSearch":true')) {
        result['needsSearch'] = true;
      } else if (jsonStr.contains('"needsSearch": false') || jsonStr.contains('"needsSearch":false')) {
        result['needsSearch'] = false;
      }
      // 旧形式（スネークケース）もフォールバック対応
      if (!result.containsKey('needsSearch')) {
        if (jsonStr.contains('"needs_search": true') || jsonStr.contains('"needs_search":true')) {
          result['needsSearch'] = true;
        } else if (jsonStr.contains('"needs_search": false') || jsonStr.contains('"needs_search":false')) {
          result['needsSearch'] = false;
        }
      }
      
      // query抽出
      final queryMatch = RegExp(r'"query"\s*:\s*"([^"]*)"').firstMatch(jsonStr);
      if (queryMatch != null) {
        result['query'] = queryMatch.group(1);
      }
      // 旧形式もフォールバック
      if (!result.containsKey('query')) {
        final oldQueryMatch = RegExp(r'"search_query"\s*:\s*"([^"]*)"').firstMatch(jsonStr);
        if (oldQueryMatch != null) {
          result['query'] = oldQueryMatch.group(1);
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}

/// 内部用: 検索必要性分析結果
class _SearchNeedAnalysis {
  final bool needed;
  final String? reason;
  final String? suggestedQuery;

  _SearchNeedAnalysis({
    required this.needed,
    this.reason,
    this.suggestedQuery,
  });
}
