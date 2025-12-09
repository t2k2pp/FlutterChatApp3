import 'dart:async';
import '../models/message.dart';
import '../models/watson_config.dart';
import 'llm_service.dart';

/// Watsonサービス - メインAIの応答を監視し、必要に応じて介入
class WatsonService {
  final LlmService _llmService;
  final WatsonConfig config;

  WatsonService({
    required LlmService llmService,
    this.config = const WatsonConfig(),
  }) : _llmService = llmService;

  /// メインAIの応答を分析し、必要に応じて介入
  Future<WatsonInterjection?> analyzeResponse({
    required List<Message> conversation,
    required String mainAiResponse,
  }) async {
    if (!config.enabled || config.interruptLevel == WatsonInterruptLevel.off) {
      return null;
    }

    try {
      // Watson用のメッセージを構築
      final watsonMessages = <Message>[
        Message(
          role: MessageRole.system,
          content: config.effectiveSystemPrompt,
        ),
        Message(
          role: MessageRole.user,
          content: _buildAnalysisPrompt(conversation, mainAiResponse),
        ),
      ];

      // Watsonに分析を依頼
      final response = await _llmService.getChatCompletion(watsonMessages);
      
      // 「問題なし」系の応答かどうかを判定
      final isNoIssue = _isNoIssueResponse(response);
      
      if (isNoIssue && config.interruptLevel != WatsonInterruptLevel.proactive) {
        return null;  // 控えめ/普通モードでは問題なしの場合は介入しない
      }

      // ハルシネーション警告かどうかを判定
      final isHallucination = _detectHallucination(response);

      return WatsonInterjection(
        content: response,
        isHallucinationWarning: isHallucination,
      );
    } catch (e) {
      // Watson分析に失敗しても、メインの会話には影響しない
      return null;
    }
  }

  /// ストリーミングで分析（将来の拡張用）
  Stream<String> streamAnalysis({
    required List<Message> conversation,
    required String mainAiResponse,
  }) async* {
    if (!config.enabled || config.interruptLevel == WatsonInterruptLevel.off) {
      return;
    }

    final watsonMessages = <Message>[
      Message(
        role: MessageRole.system,
        content: config.effectiveSystemPrompt,
      ),
      Message(
        role: MessageRole.user,
        content: _buildAnalysisPrompt(conversation, mainAiResponse),
      ),
    ];

    await for (final chunk in _llmService.streamChatCompletion(watsonMessages)) {
      yield chunk;
    }
  }

  String _buildAnalysisPrompt(List<Message> conversation, String mainAiResponse) {
    final buffer = StringBuffer();
    buffer.writeln('以下の会話とAIの回答を分析してください。');
    buffer.writeln();
    buffer.writeln('【会話履歴】');
    
    // 直近の会話のみ含める（トークン節約）
    final recentMessages = conversation.length > 4 
        ? conversation.sublist(conversation.length - 4) 
        : conversation;
    
    for (final msg in recentMessages) {
      final role = msg.role == MessageRole.user ? 'ユーザー' : 'AI';
      buffer.writeln('$role: ${msg.content}');
    }
    
    buffer.writeln();
    buffer.writeln('【分析対象のAI回答】');
    buffer.writeln(mainAiResponse);
    
    return buffer.toString();
  }

  bool _isNoIssueResponse(String response) {
    final lowerResponse = response.toLowerCase();
    final noIssuePatterns = [
      '問題は見つかりませんでした',
      '問題ありません',
      '特に指摘する点はありません',
      '正確です',
      '適切です',
      'no issues',
      'looks good',
      'no problems',
    ];
    
    return noIssuePatterns.any((pattern) => 
        lowerResponse.contains(pattern.toLowerCase()));
  }

  bool _detectHallucination(String response) {
    final hallucinationPatterns = [
      '事実と異なる',
      '誤りがあります',
      '不正確',
      '誤解を招く',
      'ハルシネーション',
      '確認が必要',
      '検証してください',
      '注意が必要',
      'incorrect',
      'inaccurate',
      'hallucination',
    ];
    
    final lowerResponse = response.toLowerCase();
    return hallucinationPatterns.any((pattern) => 
        lowerResponse.contains(pattern.toLowerCase()));
  }
}
