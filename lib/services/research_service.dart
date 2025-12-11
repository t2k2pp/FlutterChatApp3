import 'dart:async';
import '../models/message.dart';
import '../services/searxng_service.dart';
import 'llm_provider.dart';

/// リサーチ設定
class ResearchConfig {
  final int maxIterations;        // 最大ループ回数
  final int confidenceThreshold;  // 確信度閾値 (0-100)
  final int maxSourcesPerSearch;  // 1回の検索で取得する最大ソース数

  const ResearchConfig({
    this.maxIterations = 3,
    this.confidenceThreshold = 80,
    this.maxSourcesPerSearch = 5,
  });

  ResearchConfig copyWith({
    int? maxIterations,
    int? confidenceThreshold,
    int? maxSourcesPerSearch,
  }) {
    return ResearchConfig(
      maxIterations: maxIterations ?? this.maxIterations,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      maxSourcesPerSearch: maxSourcesPerSearch ?? this.maxSourcesPerSearch,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxIterations': maxIterations,
    'confidenceThreshold': confidenceThreshold,
    'maxSourcesPerSearch': maxSourcesPerSearch,
  };

  factory ResearchConfig.fromJson(Map<String, dynamic> json) {
    return ResearchConfig(
      maxIterations: json['maxIterations'] as int? ?? 3,
      confidenceThreshold: json['confidenceThreshold'] as int? ?? 80,
      maxSourcesPerSearch: json['maxSourcesPerSearch'] as int? ?? 5,
    );
  }
}

/// リサーチ進捗状態
class ResearchProgress {
  final String phase;           // 現在のフェーズ
  final int currentIteration;   // 現在のループ回数
  final int maxIterations;      // 最大ループ回数
  final String message;         // 進捗メッセージ
  final int? confidence;        // 現在の確信度

  const ResearchProgress({
    required this.phase,
    this.currentIteration = 0,
    this.maxIterations = 3,
    required this.message,
    this.confidence,
  });
}

/// リサーチ結果
class ResearchResult {
  final String query;
  final String answer;
  final List<SearchResult> sources;
  final int totalIterations;
  final int finalConfidence;
  final List<String> searchQueries;  // 実行した検索クエリ一覧
  final DateTime timestamp;

  ResearchResult({
    required this.query,
    required this.answer,
    required this.sources,
    required this.totalIterations,
    required this.finalConfidence,
    required this.searchQueries,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// リサーチサービス - Agentic Research機能
class ResearchService {
  final SearxngService _searxng;
  final LlmProvider _llm;
  final ResearchConfig config;

  ResearchService({
    required SearxngService searxng,
    required LlmProvider llm,
    this.config = const ResearchConfig(),
  })  : _searxng = searxng,
        _llm = llm;

  /// リサーチを実行
  Stream<ResearchProgress> research(String query) async* {
    final allSources = <SearchResult>[];
    final searchQueries = <String>[];
    String currentAnswer = '';
    int confidence = 0;

    // ===== Phase 1: 計画フェーズ =====
    yield ResearchProgress(
      phase: 'planning',
      message: '調査計画を立案中...',
    );

    final researchPlan = await _planResearch(query);
    yield ResearchProgress(
      phase: 'planning',
      message: '調査計画: ${researchPlan.length > 50 ? researchPlan.substring(0, 50) : researchPlan}...',
    );

    // ===== Phase 2: 初回検索（必須） =====
    yield ResearchProgress(
      phase: 'initial_search',
      currentIteration: 1,
      maxIterations: config.maxIterations,
      message: '初回検索を実行中...',
    );

    final initialQueries = await _generateSearchQueries(query, researchPlan);
    for (final searchQuery in initialQueries.take(2)) {
      searchQueries.add(searchQuery);
      try {
        final results = await _searxng.search(
          searchQuery,
          maxResults: config.maxSourcesPerSearch,
        );
        allSources.addAll(results);
        yield ResearchProgress(
          phase: 'initial_search',
          currentIteration: 1,
          maxIterations: config.maxIterations,
          message: '「$searchQuery」で${results.length}件取得',
        );
      } catch (e) {
        // 検索エラーは継続
      }
    }

    // ===== Phase 3: 評価ループ =====
    for (int iteration = 1; iteration <= config.maxIterations; iteration++) {
      yield ResearchProgress(
        phase: 'evaluation',
        currentIteration: iteration,
        maxIterations: config.maxIterations,
        message: '回答を生成・評価中 ($iteration/${config.maxIterations})...',
      );

      // 現在の情報で回答を生成
      final answerResult = await _generateAnswer(query, allSources);
      currentAnswer = answerResult.answer;
      confidence = answerResult.confidence;

      yield ResearchProgress(
        phase: 'evaluation',
        currentIteration: iteration,
        maxIterations: config.maxIterations,
        message: '確信度: $confidence%',
        confidence: confidence,
      );

      // 確信度が閾値以上なら終了
      if (confidence >= config.confidenceThreshold) {
        yield ResearchProgress(
          phase: 'complete',
          currentIteration: iteration,
          maxIterations: config.maxIterations,
          message: '十分な確信度に達しました',
          confidence: confidence,
        );
        break;
      }

      // 最後のイテレーションなら追加検索しない
      if (iteration >= config.maxIterations) {
        yield ResearchProgress(
          phase: 'complete',
          currentIteration: iteration,
          maxIterations: config.maxIterations,
          message: '最大ループ回数に達しました',
          confidence: confidence,
        );
        break;
      }

      // 追加検索が必要
      yield ResearchProgress(
        phase: 'additional_search',
        currentIteration: iteration,
        maxIterations: config.maxIterations,
        message: '追加情報を検索中...',
        confidence: confidence,
      );

      // 不足情報の検索クエリを生成
      final additionalQueries = await _generateAdditionalQueries(
        query,
        currentAnswer,
        answerResult.missingInfo,
      );

      for (final searchQuery in additionalQueries.take(2)) {
        if (searchQueries.contains(searchQuery)) continue;  // 重複スキップ
        searchQueries.add(searchQuery);
        try {
          final results = await _searxng.search(
            searchQuery,
            maxResults: config.maxSourcesPerSearch,
          );
          allSources.addAll(results);
          yield ResearchProgress(
            phase: 'additional_search',
            currentIteration: iteration,
            maxIterations: config.maxIterations,
            message: '「$searchQuery」で${results.length}件追加',
            confidence: confidence,
          );
        } catch (e) {
          // 検索エラーは継続
        }
      }
    }

    // 最終結果をyield（特別なphase）
    yield ResearchProgress(
      phase: 'result',
      currentIteration: config.maxIterations,
      maxIterations: config.maxIterations,
      message: currentAnswer,  // 最終回答をmessageに格納
      confidence: confidence,
    );
  }

  /// 調査計画を立案
  Future<String> _planResearch(String query) async {
    try {
      final response = await _llm.getChatCompletion([
        Message(
          role: MessageRole.system,
          content: '''あなたは調査計画の専門家です。
ユーザーの質問に対して、どのような情報を調べる必要があるか分析してください。
簡潔に3-5項目で回答してください。''',
        ),
        Message(
          role: MessageRole.user,
          content: '以下の質問に回答するために、何を調べる必要がありますか？\n\n質問: $query',
        ),
      ]);
      return response;
    } catch (e) {
      return query;  // エラー時はクエリをそのまま返す
    }
  }

  /// 検索クエリを生成
  Future<List<String>> _generateSearchQueries(String query, String plan) async {
    try {
      final response = await _llm.getChatCompletion([
        Message(
          role: MessageRole.system,
          content: '''あなたは検索クエリ生成の専門家です。
調査計画に基づいて、効果的なWeb検索クエリを生成してください。
各クエリは1行ずつ、最大3つまで出力してください。''',
        ),
        Message(
          role: MessageRole.user,
          content: '質問: $query\n\n調査計画:\n$plan\n\n検索クエリを生成してください:',
        ),
      ]);

      return response
          .split('\n')
          .map((s) => s.replaceAll(RegExp(r'^[\d\.\-\*]+\s*'), '').trim())
          .where((s) => s.isNotEmpty && s.length > 2)
          .take(3)
          .toList();
    } catch (e) {
      return [query];
    }
  }

  /// 回答を生成し確信度を評価
  Future<_AnswerResult> _generateAnswer(
    String query,
    List<SearchResult> sources,
  ) async {
    final context = SearxngService.formatForContext(sources);

    try {
      final response = await _llm.getChatCompletion([
        Message(
          role: MessageRole.system,
          content: '''あなたは調査・分析の専門家です。
Web検索結果を基に質問に回答し、回答の確信度を評価してください。

以下のJSON形式で回答してください:
{
  "answer": "回答テキスト",
  "confidence": 0-100の数値,
  "missing_info": "不足している情報（あれば）"
}''',
        ),
        Message(
          role: MessageRole.user,
          content: '''質問: $query

検索結果:
$context

上記の情報を基に回答してください。情報が不足している場合は確信度を低くし、不足情報を明記してください。''',
        ),
      ]);

      // JSONを抽出してパース
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        try {
          final json = _parseJson(jsonMatch.group(0)!);
          return _AnswerResult(
            answer: json['answer'] as String? ?? response,
            confidence: (json['confidence'] as num?)?.toInt() ?? 50,
            missingInfo: json['missing_info'] as String? ?? '',
          );
        } catch (e) {
          // JSONパースエラー
        }
      }

      // JSONパースに失敗した場合
      return _AnswerResult(
        answer: response,
        confidence: 60,
        missingInfo: '',
      );
    } catch (e) {
      return _AnswerResult(
        answer: 'エラーが発生しました: $e',
        confidence: 0,
        missingInfo: 'すべての情報',
      );
    }
  }

  /// 追加検索クエリを生成
  Future<List<String>> _generateAdditionalQueries(
    String query,
    String currentAnswer,
    String missingInfo,
  ) async {
    if (missingInfo.isEmpty) {
      return [query];
    }

    try {
      final response = await _llm.getChatCompletion([
        Message(
          role: MessageRole.system,
          content: '''あなたは検索クエリ生成の専門家です。
不足情報を補うための追加検索クエリを生成してください。
各クエリは1行ずつ、最大2つまで出力してください。''',
        ),
        Message(
          role: MessageRole.user,
          content: '''元の質問: $query

不足している情報: $missingInfo

この不足情報を補うための検索クエリを生成してください:''',
        ),
      ]);

      return response
          .split('\n')
          .map((s) => s.replaceAll(RegExp(r'^[\d\.\-\*]+\s*'), '').trim())
          .where((s) => s.isNotEmpty && s.length > 2)
          .take(2)
          .toList();
    } catch (e) {
      return [missingInfo];
    }
  }

  /// 簡易JSONパーサー
  Map<String, dynamic> _parseJson(String jsonStr) {
    // Dartの標準jsonDecodeを使用
    return Map<String, dynamic>.from(
      (jsonStr.contains('{')) 
        ? _simpleJsonParse(jsonStr)
        : {},
    );
  }

  Map<String, dynamic> _simpleJsonParse(String jsonStr) {
    try {
      // 正規表現でキー・バリューを抽出
      final result = <String, dynamic>{};
      
      // answer抽出
      final answerMatch = RegExp(r'"answer"\s*:\s*"([^"]*)"').firstMatch(jsonStr);
      if (answerMatch != null) {
        result['answer'] = answerMatch.group(1);
      }
      
      // confidence抽出
      final confMatch = RegExp(r'"confidence"\s*:\s*(\d+)').firstMatch(jsonStr);
      if (confMatch != null) {
        result['confidence'] = int.parse(confMatch.group(1)!);
      }
      
      // missing_info抽出
      final missingMatch = RegExp(r'"missing_info"\s*:\s*"([^"]*)"').firstMatch(jsonStr);
      if (missingMatch != null) {
        result['missing_info'] = missingMatch.group(1);
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}

/// 内部用: 回答結果
class _AnswerResult {
  final String answer;
  final int confidence;
  final String missingInfo;

  _AnswerResult({
    required this.answer,
    required this.confidence,
    required this.missingInfo,
  });
}
