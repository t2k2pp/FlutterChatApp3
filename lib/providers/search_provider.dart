import 'package:flutter/foundation.dart';
import '../services/deep_search_service.dart';
import '../services/llm_service.dart';
import '../services/searxng_service.dart';
import '../services/storage_service.dart';

class SearchProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  SearxngService? _searxng;
  DeepSearchService? _deepSearch;
  
  SearchConfig _config = const SearchConfig();
  List<SearchResult> _lastResults = [];
  DeepSearchResult? _lastDeepSearchResult;
  bool _isSearching = false;
  bool _isDeepSearching = false;
  bool _isConnected = false;
  String? _error;
  String _progress = '';
  bool _isEnabled = true;
  bool _deepSearchEnabled = false;

  // Getters
  SearchConfig get config => _config;
  List<SearchResult> get lastResults => _lastResults;
  DeepSearchResult? get lastDeepSearchResult => _lastDeepSearchResult;
  bool get isSearching => _isSearching;
  bool get isDeepSearching => _isDeepSearching;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String get progress => _progress;
  bool get isEnabled => _isEnabled;
  bool get deepSearchEnabled => _deepSearchEnabled;
  String get searxngUrl => _config.baseUrl;

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
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    final settings = await _storage.loadSettings();
    settings['search'] = _config.toJson();
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

  /// Web検索
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

  /// DeepSearch（深い調査）
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

  /// 検索結果をAI用コンテキストに変換
  String getSearchContext() {
    return SearxngService.formatForContext(_lastResults);
  }

  /// DeepSearch結果をAI用コンテキストに変換
  String getDeepSearchContext() {
    if (_lastDeepSearchResult == null) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('【深層調査結果】');
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
