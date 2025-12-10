import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/watson_config.dart';
import '../services/llm_provider.dart';
import '../services/storage_service.dart';

class WatsonProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  WatsonConfig _config = const WatsonConfig();
  List<WatsonInterjection> _interjections = [];
  bool _isAnalyzing = false;
  String? _currentAnalysis;
  WatsonInterjection? _pendingInterjection;
  
  // LLMプロバイダー情報
  List<LlmProviderConfig> _availableProviders = [];
  LlmProvider? _watsonLlmProvider;

  // Getters
  WatsonConfig get config => _config;
  List<WatsonInterjection> get interjections => _interjections;
  bool get isAnalyzing => _isAnalyzing;
  String? get currentAnalysis => _currentAnalysis;
  WatsonInterjection? get pendingInterjection => _pendingInterjection;
  bool get hasUnsharedInterjection => _pendingInterjection != null && !_pendingInterjection!.sharedWithMainAI;
  List<LlmProviderConfig> get availableProviders => _availableProviders;
  
  /// 現在使用中のプロバイダー名
  String get currentProviderName {
    if (_config.providerIndex != null && 
        _config.providerIndex! < _availableProviders.length) {
      return _availableProviders[_config.providerIndex!].name;
    }
    return 'メインと同じ';
  }

  WatsonProvider() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final settings = await _storage.loadSettings();
    final watsonData = settings['watson'];
    if (watsonData != null) {
      _config = WatsonConfig.fromJson(watsonData as Map<String, dynamic>);
    }
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    final settings = await _storage.loadSettings();
    settings['watson'] = _config.toJson();
    await _storage.saveSettings(settings);
  }

  /// 利用可能なプロバイダーを設定
  void setAvailableProviders(List<LlmProviderConfig> providers) {
    _availableProviders = providers;
    notifyListeners();
  }

  /// Watson用のLLMプロバイダーを設定
  void setWatsonProvider(LlmProvider? provider) {
    _watsonLlmProvider = provider;
  }

  /// Watson設定を更新
  Future<void> updateConfig(WatsonConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    notifyListeners();
  }

  /// 介入レベルを変更
  Future<void> setInterruptLevel(WatsonInterruptLevel level) async {
    await updateConfig(_config.copyWith(interruptLevel: level));
  }

  /// プロバイダーを変更
  Future<void> setProviderIndex(int? index) async {
    await updateConfig(_config.copyWith(providerIndex: index));
  }

  /// 起動ワードを更新
  Future<void> setActivationWords(List<String> words) async {
    await updateConfig(_config.copyWith(activationWords: words));
  }

  /// メインAIの応答を自動分析
  Future<void> analyzeMainResponse({
    required List<Message> conversation,
    required String mainAiResponse,
  }) async {
    if (_watsonLlmProvider == null || !_config.enabled) return;
    if (_config.interruptLevel == WatsonInterruptLevel.off) return;

    _isAnalyzing = true;
    _currentAnalysis = null;
    notifyListeners();

    try {
      final interjection = await _analyzeWithProvider(
        conversation: conversation,
        mainAiResponse: mainAiResponse,
        isManualCall: false,
      );

      if (interjection != null) {
        _pendingInterjection = interjection;
        _interjections.add(interjection);
      }
    } catch (e) {
      debugPrint('Watson analysis error: $e');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// 起動ワードでWatsonを呼び出し
  Future<String?> callWatson({
    required List<Message> conversation,
    required String userMessage,
  }) async {
    if (_watsonLlmProvider == null) return null;

    _isAnalyzing = true;
    _currentAnalysis = null;
    notifyListeners();

    try {
      // 最後のAI応答を取得
      String? lastAiResponse;
      for (int i = conversation.length - 1; i >= 0; i--) {
        if (conversation[i].role == MessageRole.assistant) {
          lastAiResponse = conversation[i].content;
          break;
        }
      }

      if (lastAiResponse == null) {
        return 'まだメインAIからの回答がありません。';
      }

      final interjection = await _analyzeWithProvider(
        conversation: conversation,
        mainAiResponse: lastAiResponse,
        isManualCall: true,
        additionalContext: userMessage,
      );

      if (interjection != null) {
        _pendingInterjection = interjection;
        _interjections.add(interjection);
        return interjection.content;
      }
      return 'Watson: 分析できませんでした。';
    } catch (e) {
      debugPrint('Watson call error: $e');
      return 'Watson: エラーが発生しました。';
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// プロバイダーを使って分析を実行
  Future<WatsonInterjection?> _analyzeWithProvider({
    required List<Message> conversation,
    required String mainAiResponse,
    required bool isManualCall,
    String? additionalContext,
  }) async {
    if (_watsonLlmProvider == null) return null;

    final systemPrompt = _config.effectiveSystemPrompt;
    if (systemPrompt.isEmpty) return null;

    // 会話の要約を作成
    final conversationSummary = conversation
        .where((m) => m.role != MessageRole.system)
        .take(5)
        .map((m) => '${m.role == MessageRole.user ? "ユーザー" : "AI"}: ${m.content.length > 200 ? m.content.substring(0, 200) + "..." : m.content}')
        .join('\n');

    String userPrompt = '''以下のAIの回答を分析してください。

【最近の会話】
$conversationSummary

【メインAIの回答】
$mainAiResponse
''';

    if (additionalContext != null) {
      userPrompt += '\n【ユーザーからの追加質問】\n$additionalContext';
    }

    final messages = [
      Message(role: MessageRole.system, content: systemPrompt),
      Message(role: MessageRole.user, content: userPrompt),
    ];

    try {
      final response = await _watsonLlmProvider!.getChatCompletion(messages);
      
      // 消極的モードで問題なしの場合はスキップ
      if (_config.interruptLevel == WatsonInterruptLevel.passive && !isManualCall) {
        if (_isNoIssueResponse(response)) {
          return null;
        }
      }

      return WatsonInterjection(
        content: response,
        isHallucinationWarning: _detectHallucination(response),
        isManualCall: isManualCall,
      );
    } catch (e) {
      debugPrint('Watson provider error: $e');
      return null;
    }
  }

  bool _isNoIssueResponse(String response) {
    final patterns = [
      '問題は見つかりませんでした',
      '問題ありません',
      '特に問題',
      '問題ない',
      '正確です',
      '適切です',
    ];
    for (final pattern in patterns) {
      if (response.contains(pattern)) return true;
    }
    return response.length < 50;
  }

  bool _detectHallucination(String response) {
    final patterns = [
      '事実と異なる',
      '誤り',
      '不正確',
      'ハルシネーション',
      '誤情報',
      '間違って',
    ];
    for (final pattern in patterns) {
      if (response.contains(pattern)) return true;
    }
    return false;
  }

  /// メッセージに起動ワードが含まれているか
  bool shouldRespondToCall(String message) {
    return _config.containsActivationWord(message);
  }

  /// Watsonの意見をメインAIと共有
  void shareWithMainAI() {
    if (_pendingInterjection != null) {
      _pendingInterjection = _pendingInterjection!.copyWith(sharedWithMainAI: true);
      notifyListeners();
    }
  }

  /// 保留中の介入をクリア
  void dismissPendingInterjection() {
    _pendingInterjection = null;
    notifyListeners();
  }

  /// 介入履歴をクリア
  void clearHistory() {
    _interjections.clear();
    _pendingInterjection = null;
    notifyListeners();
  }
}
