import 'package:flutter/foundation.dart';
import '../services/llm_provider.dart';
import '../services/providers/llamacpp_provider.dart';
import '../services/providers/claude_provider.dart';
import '../services/providers/openai_provider.dart';
import '../services/providers/gemini_provider.dart';
import '../services/storage_service.dart';

class LlmProviderManager extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  List<LlmProviderConfig> _providers = [];
  int _currentIndex = 0;
  LlmProvider? _currentProvider;
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LlmProviderConfig> get providers => _providers;
  int get currentIndex => _currentIndex;
  LlmProviderConfig? get currentConfig => 
      _providers.isNotEmpty ? _providers[_currentIndex] : null;
  LlmProvider? get currentProvider => _currentProvider;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  LlmProviderManager() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadProviders();
    await _initCurrentProvider();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProviders() async {
    final settings = await _storage.loadSettings();
    final providersData = settings['llmProviders'] as List?;
    
    if (providersData != null && providersData.isNotEmpty) {
      _providers = providersData
          .map((p) => LlmProviderConfig.fromJson(p as Map<String, dynamic>))
          .toList();
      _currentIndex = settings['currentProviderIndex'] ?? 0;
      if (_currentIndex >= _providers.length) {
        _currentIndex = 0;
      }
    } else {
      // デフォルトプロバイダーを追加
      _providers = [
        LlmProviderConfig.defaultLlamaCpp,
      ];
    }
  }

  Future<void> _saveProviders() async {
    final settings = await _storage.loadSettings();
    settings['llmProviders'] = _providers.map((p) => p.toJson()).toList();
    settings['currentProviderIndex'] = _currentIndex;
    await _storage.saveSettings(settings);
  }

  Future<void> _initCurrentProvider() async {
    _currentProvider?.dispose();
    _currentProvider = null;
    _isConnected = false;

    if (_providers.isEmpty) return;

    final config = _providers[_currentIndex];
    _currentProvider = _createProvider(config);
    
    if (_currentProvider != null) {
      _isConnected = await _currentProvider!.testConnection();
    }

    notifyListeners();
  }

  /// プロバイダーを作成
  LlmProvider _createProvider(LlmProviderConfig config) {
    switch (config.type) {
      case LlmProviderType.llamaCpp:
        return LlamaCppProvider(config: config);
      case LlmProviderType.claude:
        return ClaudeProvider(config: config);
      case LlmProviderType.openai:
        return OpenAIProvider(config: config);
      case LlmProviderType.gemini:
        return GeminiProvider(config: config);
    }
  }

  /// プロバイダーを追加
  Future<void> addProvider(LlmProviderConfig config) async {
    _providers.add(config);
    await _saveProviders();
    notifyListeners();
  }

  /// プロバイダーを更新
  Future<void> updateProvider(int index, LlmProviderConfig config) async {
    if (index < 0 || index >= _providers.length) return;
    
    _providers[index] = config;
    await _saveProviders();
    
    if (index == _currentIndex) {
      await _initCurrentProvider();
    }
    notifyListeners();
  }

  /// プロバイダーを削除
  Future<void> removeProvider(int index) async {
    if (index < 0 || index >= _providers.length) return;
    if (_providers.length <= 1) return;  // 最低1つは維持

    _providers.removeAt(index);
    if (_currentIndex >= _providers.length) {
      _currentIndex = _providers.length - 1;
    }
    await _saveProviders();
    await _initCurrentProvider();
    notifyListeners();
  }

  /// プロバイダーを切り替え
  Future<void> switchProvider(int index) async {
    if (index < 0 || index >= _providers.length) return;
    if (index == _currentIndex) return;

    _currentIndex = index;
    await _saveProviders();
    await _initCurrentProvider();
    notifyListeners();
  }

  /// 接続テスト
  Future<bool> testConnection() async {
    if (_currentProvider == null) return false;
    _isConnected = await _currentProvider!.testConnection();
    notifyListeners();
    return _isConnected;
  }

  /// デフォルトプロバイダーを追加
  Future<void> addDefaultProvider(LlmProviderType type) async {
    LlmProviderConfig config;
    switch (type) {
      case LlmProviderType.llamaCpp:
        config = LlmProviderConfig.defaultLlamaCpp;
        break;
      case LlmProviderType.claude:
        config = LlmProviderConfig.defaultClaude;
        break;
      case LlmProviderType.openai:
        config = LlmProviderConfig.defaultOpenAI;
        break;
      case LlmProviderType.gemini:
        config = LlmProviderConfig.defaultGemini;
        break;
    }
    await addProvider(config);
  }

  @override
  void dispose() {
    _currentProvider?.dispose();
    super.dispose();
  }
}
