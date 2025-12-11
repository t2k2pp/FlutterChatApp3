import 'package:flutter/foundation.dart';
import '../services/agentic_search_service.dart';
import '../services/deep_search_service.dart';
import '../services/llm_provider.dart';
import '../services/llm_service.dart';
import '../services/research_service.dart';
import '../services/searxng_service.dart';
import '../services/storage_service.dart';

/// 検索モード
enum SearchMode {
  simple,    // 簡易検索
  deep,      // 詳細検索
  research,  // リサーチ（Agentic Research）
}

class SearchProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  SearxngService? _searxng;
  DeepSearchService? _deepSearch;
  ResearchService? _research;
  AgenticSearchService? _agenticSearch;
  LlmProvider? _llmProvider;
  
  SearchConfig _config = const SearchConfig();
  ResearchConfig _researchConfig = const ResearchConfig();
  AgenticSearchConfig _agenticConfig = const AgenticSearchConfig();
  
  List<SearchResult> _lastResults = [];
  DeepSearchResult? _lastDeepSearchResult;
  ResearchProgress? _lastResearchProgress;
  
  bool _isSearching = false;
  bool _isDeepSearching = false;
  bool _isResearching = false;
  bool _isConnected = false;
  String? _error;
  String _progress = '';
  bool _isEnabled = true;
  bool _deepSearchEnabled = false;
  SearchMode _searchMode = SearchMode.simple;

  // Getters
  SearchConfig get config => _config;
  ResearchConfig get researchConfig => _researchConfig;
  AgenticSearchConfig get agenticConfig => _agenticConfig;
  List<SearchResult> get lastResults => _lastResults;
  DeepSearchResult? get lastDeepSearchResult => _lastDeepSearchResult;
  ResearchProgress? get lastResearchProgress => _lastResearchProgress;
  bool get isSearching => _isSearching;
  bool get isDeepSearching => _isDeepSearching;
  bool get isResearching => _isResearching;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String get progress => _progress;
  bool get isEnabled => _isEnabled;
  bool get deepSearchEnabled => _deepSearchEnabled;
  String get searxngUrl => _config.baseUrl;
  SearchMode get searchMode => _searchMode;

  SearchProvider() {
    _initialize();
  }

  void initialize(LlmService llmService) {
    _searxng = SearxngService(config: _config);
    _deepSearch = DeepSearchService(
      searxng: _searxng!,
      llm: llmService,
    );
  }

  /// LLMプロバイダーを設定（リサーチ・Agentic検索用）
  void setLlmProvider(LlmProvider? provider) {
    _llmProvider = provider;
    if (provider != null && _searxng != null) {
      _research = ResearchService(
        searxng: _searxng!,
        llm: provider,
        config: _researchConfig,
      );
      _agenticSearch = AgenticSearchService(
        searxng: _searxng!,
        llm: provider,
        config: _agenticConfig,
      );
    }
    notifyListeners();
  }

  Future<void> _initialize() async {
    await _loadConfig();
    _searxng = SearxngService(config: _config);
    await testConnection();
  }

  Future<void> _loadConfig() async {
    final settings = await _storage.loadSettings();
    final searchData = settings['search'];
    if (searchData != null) {
      _config = SearchConfig.fromJson(searchData as Map<String, dynamic>);
    }
    final researchData = settings['research'];
    if (researchData != null) {
      _researchConfig = ResearchConfig.fromJson(researchData as Map<String, dynamic>);
    }
    final agenticData = settings['agenticSearch'];
    if (agenticData != null) {
      _agenticConfig = AgenticSearchConfig.fromJson(agenticData as Map<String, dynamic>);
    }
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    final settings = await _storage.loadSettings();
    settings['search'] = _config.toJson();
    settings['research'] = _researchConfig.toJson();
    settings['agenticSearch'] = _agenticConfig.toJson();
    await _storage.saveSettings(settings);
  }

  /// 設定を更新
  Future<void> updateConfig(SearchConfig newConfig) async {
    _config = newConfig;
    _searxng = SearxngService(config: _config);
    await _saveConfig();
    await testConnection();
    notifyListeners();
  }

  /// リサーチ設定を更新
  Future<void> updateResearchConfig(ResearchConfig newConfig) async {
    _researchConfig = newConfig;
    if (_llmProvider != null && _searxng != null) {
      _research = ResearchService(
        searxng: _searxng!,
        llm: _llmProvider!,
        config: _researchConfig,
      );
    }
    await _saveConfig();
    notifyListeners();
  }

  /// Agentic検索設定を更新
  Future<void> updateAgenticConfig(AgenticSearchConfig newConfig) async {
    _agenticConfig = newConfig;
    if (_llmProvider != null && _searxng != null) {
      _agenticSearch = AgenticSearchService(
        searxng: _searxng!,
        llm: _llmProvider!,
        config: _agenticConfig,
      );
    }
    await _saveConfig();
    notifyListeners();
  }

  /// 検索モードを設定
  void setSearchMode(SearchMode mode) {
    _searchMode = mode;
    notifyListeners();
  }

  /// 検索の有効/無効を設定
  void setEnabled(bool value) {
    _isEnabled = value;
    notifyListeners();
  }

  /// DeepSearchの有効/無効を設定
  void setDeepSearchEnabled(bool value) {
    _deepSearchEnabled = value;
    notifyListeners();
  }

  /// SearXNG URLを設定
  Future<void> setSearxngUrl(String url) async {
    await updateConfig(_config.copyWith(baseUrl: url));
  }

  /// 接続テスト
  Future<void> testConnection() async {
    if (_searxng == null) return;
    _isConnected = await _searxng!.testConnection();
    notifyListeners();
  }

  /// Web検索（簡易）
  Future<List<SearchResult>> search(String query) async {
    if (_searxng == null) return [];
    
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _lastResults = await _searxng!.search(query);
      return _lastResults;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// DeepSearch（詳細検索）
  Future<DeepSearchResult?> deepSearch(String query) async {
    if (_deepSearch == null) return null;
    
    _isDeepSearching = true;
    _error = null;
    _progress = '';
    notifyListeners();

    try {
      _lastDeepSearchResult = await _deepSearch!.research(
        query,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
      return _lastDeepSearchResult;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isDeepSearching = false;
      notifyListeners();
    }
  }

  /// リサーチ（Agentic Research）
  Stream<ResearchProgress> research(String query) async* {
    if (_research == null) {
      yield ResearchProgress(
        phase: 'error',
        message: 'リサーチサービスが初期化されていません',
      );
      return;
    }
    
    _isResearching = true;
    _error = null;
    notifyListeners();

    try {
      await for (final progress in _research!.research(query)) {
        _lastResearchProgress = progress;
        _progress = progress.message;
        notifyListeners();
        yield progress;
      }
    } catch (e) {
      _error = e.toString();
      yield ResearchProgress(
        phase: 'error',
        message: 'エラー: $e',
      );
    } finally {
      _isResearching = false;
      notifyListeners();
    }
  }

  /// Agentic Web検索（通常会話時の自動検索）
  Future<AgenticSearchResult> agenticSearch(
    List<dynamic> conversationHistory,
    String userMessage,
  ) async {
    if (_agenticSearch == null || !_agenticConfig.enabled) {
      return const AgenticSearchResult(searchPerformed: false);
    }

    try {
      // TODO: conversationHistoryをMessage型に変換する必要がある場合は変換
      return await _agenticSearch!.analyzeAndSearch([], userMessage);
    } catch (e) {
      return const AgenticSearchResult(searchPerformed: false);
    }
  }

  /// 検索結果をAI用コンテキストに変換
  String getSearchContext() {
    return SearxngService.formatForContext(_lastResults);
  }

  /// DeepSearch結果をAI用コンテキストに変換
  String getDeepSearchContext() {
    if (_lastDeepSearchResult == null) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('【詳細検索結果】');
    buffer.writeln('クエリ: ${_lastDeepSearchResult!.query}');
    buffer.writeln();
    buffer.writeln(_lastDeepSearchResult!.summary);
    buffer.writeln();
    buffer.writeln('参照ソース:');
    for (var i = 0; i < _lastDeepSearchResult!.sources.length; i++) {
      buffer.writeln('  ${i + 1}. ${_lastDeepSearchResult!.sources[i]}');
    }
    return buffer.toString();
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searxng?.dispose();
    super.dispose();
  }
}
