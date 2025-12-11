import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/llm_service.dart';
import '../services/llm_provider.dart';
import '../services/storage_service.dart';
import '../services/agentic_search_service.dart';
import '../services/searxng_service.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  LlmService _llmService = LlmService();
  LlmProvider? _llmProvider;
  AgenticSearchService? _agenticSearchService;
  SearxngService? _searxngService;
  
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  String _systemPrompt = '';
  String _apiUrl = 'http://192.168.1.24:11437/v1';
  StreamSubscription<String>? _streamSubscription;
  bool _agenticSearchEnabled = false;

  // Getters
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String get systemPrompt => _systemPrompt;
  String get apiUrl => _apiUrl;
  bool get agenticSearchEnabled => _agenticSearchEnabled;

  ChatProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await _loadConversations();
    await testConnection();
    
    // 会話がなければ新規作成
    if (_conversations.isEmpty) {
      createNewConversation();
    } else {
      _currentConversation = _conversations.first;
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final settings = await _storage.loadSettings();
    _apiUrl = settings['apiUrl'] ?? 'http://192.168.1.24:11437/v1';
    _systemPrompt = settings['systemPrompt'] ?? '';
    _llmService = LlmService(baseUrl: _apiUrl);
  }

  Future<void> _loadConversations() async {
    _conversations = await _storage.loadConversations();
    // 更新日時で降順ソート
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _saveConversations() async {
    await _storage.saveConversations(_conversations);
  }

  /// 外部からLlmProviderを設定
  void setLlmProvider(LlmProvider? provider) {
    _llmProvider = provider;
    _updateAgenticSearchService();
    notifyListeners();
  }

  /// SearxngServiceを設定（SearchProviderから呼び出し）
  void setSearxngService(SearxngService? service) {
    _searxngService = service;
    _updateAgenticSearchService();
  }

  /// Agentic検索の有効/無効を設定
  void setAgenticSearchEnabled(bool enabled) {
    _agenticSearchEnabled = enabled;
    notifyListeners();
  }

  /// AgenticSearchServiceを更新
  void _updateAgenticSearchService() {
    if (_llmProvider != null && _searxngService != null) {
      _agenticSearchService = AgenticSearchService(
        searxng: _searxngService!,
        llm: _llmProvider!,
        config: AgenticSearchConfig(enabled: _agenticSearchEnabled),
      );
    }
  }

  Future<void> testConnection() async {
    if (_llmProvider != null) {
      _isConnected = await _llmProvider!.testConnection();
    } else {
      _isConnected = await _llmService.testConnection();
    }
    notifyListeners();
  }

  void createNewConversation() {
    final conversation = Conversation();
    _conversations.insert(0, conversation);
    _currentConversation = conversation;
    _saveConversations();
    notifyListeners();
  }

  void selectConversation(String id) {
    _currentConversation = _conversations.firstWhere((c) => c.id == id);
    notifyListeners();
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    if (_currentConversation?.id == id) {
      _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
      if (_currentConversation == null) {
        createNewConversation();
      }
    }
    _saveConversations();
    notifyListeners();
  }

  Future<void> sendMessage(
    String content, {
    String? projectSystemPrompt,
    String? skillContext,
  }) async {
    if (content.trim().isEmpty || _currentConversation == null) return;

    _error = null;
    _isLoading = true;
    notifyListeners();

    // Agentic Web検索: 必要に応じて自動でWeb検索を実行
    String enhancedContent = content.trim();
    String? agenticSearchContext;
    
    // デバッグ: Agentic検索の状態を確認
    debugPrint('Agentic Search Status: enabled=$_agenticSearchEnabled, service=${_agenticSearchService != null}, llm=${_llmProvider != null}, searxng=${_searxngService != null}');
    
    if (_agenticSearchEnabled && _agenticSearchService != null) {
      try {
        debugPrint('Agentic Search: Analyzing if search is needed...');
        final searchResult = await _agenticSearchService!.analyzeAndSearch(
          _currentConversation!.messages,
          content.trim(),
        );
        
        if (searchResult.searchPerformed && searchResult.enhancedContext != null) {
          debugPrint('Agentic Search: Search performed - ${searchResult.searchReason}');
          debugPrint('Agentic Search: Results count - ${searchResult.results.length}');
          debugPrint('Agentic Search: Context length - ${searchResult.enhancedContext!.length} chars');
          if (searchResult.enhancedContext!.length < 500) {
            debugPrint('Agentic Search: Context - ${searchResult.enhancedContext}');
          } else {
            debugPrint('Agentic Search: Context (first 500) - ${searchResult.enhancedContext!.substring(0, 500)}...');
          }
          agenticSearchContext = searchResult.enhancedContext;
        } else {
          debugPrint('Agentic Search: No search needed (performed=${searchResult.searchPerformed}, context=${searchResult.enhancedContext != null})');
        }
      } catch (e) {
        debugPrint('Agentic Search error: $e');
        // エラー時は通常のメッセージ処理を続行
      }
    } else {
      debugPrint('Agentic Search: Skipped (enabled=$_agenticSearchEnabled, service=${_agenticSearchService != null})');
    }

    // ユーザーメッセージを追加
    final userMessage = Message(
      role: MessageRole.user,
      content: enhancedContent,
    );

    final messages = [..._currentConversation!.messages, userMessage];
    
    // タイトルの自動生成（最初のメッセージの場合）
    String title = _currentConversation!.title;
    if (_currentConversation!.messages.isEmpty) {
      title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }

    _currentConversation = _currentConversation!.copyWith(
      title: title,
      messages: messages,
      updatedAt: DateTime.now(),
    );
    _updateConversationInList();
    notifyListeners();

    // AIの応答用メッセージを追加
    final assistantMessage = Message(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );

    _currentConversation = _currentConversation!.copyWith(
      messages: [...messages, assistantMessage],
    );
    _updateConversationInList();
    notifyListeners();

    try {
      // システムプロンプトを含むメッセージリストを作成
      // プロジェクトのシステムプロンプトを優先、なければグローバル設定を使用
      List<Message> apiMessages = [];
      String effectiveSystemPrompt = projectSystemPrompt?.isNotEmpty == true 
          ? projectSystemPrompt! 
          : _systemPrompt;
      
      // スキルコンテキストを追加
      if (skillContext?.isNotEmpty == true) {
        effectiveSystemPrompt = effectiveSystemPrompt.isNotEmpty
            ? '$effectiveSystemPrompt\n\n$skillContext'
            : skillContext!;
      }

      // Agentic検索結果をシステムプロンプトに追加
      if (agenticSearchContext != null && agenticSearchContext.isNotEmpty) {
        final searchInstruction = '''
【Web検索結果】
以下は自動的に収集された最新のWeb情報です。回答の参考にしてください。

$agenticSearchContext''';
        effectiveSystemPrompt = effectiveSystemPrompt.isNotEmpty
            ? '$effectiveSystemPrompt\n\n$searchInstruction'
            : searchInstruction;
      }
      
      if (effectiveSystemPrompt.isNotEmpty) {
        apiMessages.add(Message(
          role: MessageRole.system,
          content: effectiveSystemPrompt,
        ));
      }
      apiMessages.addAll(messages);

      // ストリーミングで応答を取得
      String fullResponse = '';
      final stream = _llmProvider != null 
          ? _llmProvider!.streamChatCompletion(apiMessages)
          : _llmService.streamChatCompletion(apiMessages);
      await for (final chunk in stream) {
        fullResponse += chunk;
        
        final updatedAssistantMessage = assistantMessage.copyWith(
          content: fullResponse,
          isStreaming: true,
        );

        _currentConversation = _currentConversation!.copyWith(
          messages: [...messages, updatedAssistantMessage],
        );
        _updateConversationInList();
        notifyListeners();
      }

      // ストリーミング完了
      final finalAssistantMessage = assistantMessage.copyWith(
        content: fullResponse,
        isStreaming: false,
      );

      _currentConversation = _currentConversation!.copyWith(
        messages: [...messages, finalAssistantMessage],
        updatedAt: DateTime.now(),
      );
      _updateConversationInList();
      await _saveConversations();

    } catch (e) {
      _error = e.toString();
      // エラー時はAIメッセージを削除
      _currentConversation = _currentConversation!.copyWith(
        messages: messages,
      );
      _updateConversationInList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateConversationInList() {
    final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
    if (index != -1) {
      _conversations[index] = _currentConversation!;
    }
  }

  /// ユーザーメッセージを直接追加（リサーチ結果表示用）
  void addUserMessage(String content) {
    if (_currentConversation == null) return;

    final userMessage = Message(
      role: MessageRole.user,
      content: content.trim(),
    );

    // タイトルの自動生成（最初のメッセージの場合）
    String title = _currentConversation!.title;
    if (_currentConversation!.messages.isEmpty) {
      title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }

    _currentConversation = _currentConversation!.copyWith(
      title: title,
      messages: [..._currentConversation!.messages, userMessage],
      updatedAt: DateTime.now(),
    );
    _updateConversationInList();
    _saveConversations();
    notifyListeners();
  }

  /// アシスタントメッセージを直接追加（リサーチ結果表示用）
  void addAssistantMessage(String content) {
    if (_currentConversation == null) return;

    final assistantMessage = Message(
      role: MessageRole.assistant,
      content: content.trim(),
    );

    _currentConversation = _currentConversation!.copyWith(
      messages: [..._currentConversation!.messages, assistantMessage],
      updatedAt: DateTime.now(),
    );
    _updateConversationInList();
    _saveConversations();
    notifyListeners();
  }

  void stopGeneration() {
    _streamSubscription?.cancel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSettings({
    String? apiUrl,
    String? systemPrompt,
  }) async {
    if (apiUrl != null) {
      _apiUrl = apiUrl;
      _llmService = LlmService(baseUrl: apiUrl);
    }
    if (systemPrompt != null) {
      _systemPrompt = systemPrompt;
    }
    
    await _storage.saveSettings({
      'apiUrl': _apiUrl,
      'systemPrompt': _systemPrompt,
    });
    
    await testConnection();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _llmService.dispose();
    super.dispose();
  }
}
