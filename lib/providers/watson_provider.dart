import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/watson_config.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';
import '../services/watson_service.dart';

class WatsonProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  WatsonService? _watsonService;
  
  WatsonConfig _config = const WatsonConfig();
  List<WatsonInterjection> _interjections = [];
  bool _isAnalyzing = false;
  String? _currentAnalysis;
  WatsonInterjection? _pendingInterjection;

  // Getters
  WatsonConfig get config => _config;
  List<WatsonInterjection> get interjections => _interjections;
  bool get isAnalyzing => _isAnalyzing;
  String? get currentAnalysis => _currentAnalysis;
  WatsonInterjection? get pendingInterjection => _pendingInterjection;
  bool get hasUnsharedInterjection => _pendingInterjection != null && !_pendingInterjection!.sharedWithMainAI;

  WatsonProvider() {
    _loadConfig();
  }

  void initialize(LlmService llmService) {
    _watsonService = WatsonService(
      llmService: llmService,
      config: _config,
    );
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

  /// Watson設定を更新
  Future<void> updateConfig(WatsonConfig newConfig) async {
    _config = newConfig;
    if (_watsonService != null) {
      // サービスを再作成
      final llmService = LlmService();  // TODO: 既存のサービスを再利用
      _watsonService = WatsonService(
        llmService: llmService,
        config: _config,
      );
    }
    await _saveConfig();
    notifyListeners();
  }

  /// メインAIの応答を分析
  Future<void> analyzeMainResponse({
    required List<Message> conversation,
    required String mainAiResponse,
  }) async {
    if (_watsonService == null || !_config.enabled) return;
    if (_config.interruptLevel == WatsonInterruptLevel.off) return;

    _isAnalyzing = true;
    _currentAnalysis = null;
    notifyListeners();

    try {
      final interjection = await _watsonService!.analyzeResponse(
        conversation: conversation,
        mainAiResponse: mainAiResponse,
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

  /// Watsonを呼び出す（"Watson"などの呼びかけに反応）
  bool shouldRespondToCall(String message) {
    if (!_config.enabled) return false;
    
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('watson') ||
           lowerMessage.contains('わとそん') ||
           lowerMessage.contains('ワトソン');
  }
}
