import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/skill_provider.dart';
import '../../providers/llm_provider_manager.dart';
import '../../services/export_service.dart';
import '../../services/searxng_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/conversation_drawer.dart';
import '../../widgets/message_bubble.dart';
import 'project_screen.dart';
import 'skill_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  SearchMode _searchMode = SearchMode.off;

  @override
  void initState() {
    super.initState();
    // プロバイダー間の連携を初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAgenticSearch();
    });
  }

  void _initializeAgenticSearch() {
    final searchProvider = context.read<SearchProvider>();
    final chatProvider = context.read<ChatProvider>();
    final llmManager = context.read<LlmProviderManager>();
    
    // LLMProviderManagerから現在のLLMProviderをChatProviderに設定
    if (llmManager.currentProvider != null) {
      chatProvider.setLlmProvider(llmManager.currentProvider);
      debugPrint('Agentic Init: LLM Provider set');
    } else {
      debugPrint('Agentic Init: LLM Provider is null');
    }
    
    // SearchProviderからSearxngServiceをChatProviderに設定
    if (searchProvider.searxngService != null) {
      chatProvider.setSearxngService(searchProvider.searxngService);
      debugPrint('Agentic Init: SearxNG Service set');
    } else {
      debugPrint('Agentic Init: SearxNG Service is null');
    }
    
    // AgenticSearchConfigの設定をChatProviderに反映
    chatProvider.setAgenticSearchEnabled(searchProvider.agenticConfig.enabled);
    debugPrint('Agentic Init: Enabled=${searchProvider.agenticConfig.enabled}');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      drawer: const ConversationDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProjectBar(),
          Expanded(
            child: _buildMessageList(),
          ),
          _buildErrorBanner(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildProjectBar() {
    return Consumer<ProjectProvider>(
      builder: (context, provider, child) {
        final project = provider.currentProject;
        
        return Material(
          color: AppTheme.darkSurface,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.darkBorder),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      project?.icon ?? '💬',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project?.name ?? '一般',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (project?.description.isNotEmpty == true)
                          Text(
                            project!.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.darkSurface,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Icon(
              Icons.menu_rounded,
              size: 18,
            ),
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: provider.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (provider.isConnected ? Colors.green : Colors.red)
                          .withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  provider.currentConversation?.title ?? 'AI Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        // エクスポートボタン
        Consumer<ChatProvider>(
          builder: (context, provider, child) {
            if (provider.currentConversation == null || 
                provider.currentConversation!.messages.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Icon(Icons.file_download_outlined, size: 18),
              ),
              onPressed: () => _exportCurrentConversation(context),
            );
          },
        ),
        // 新規会話ボタン
        Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                provider.createNewConversation();
              },
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _exportCurrentConversation(BuildContext context) {
    final provider = context.read<ChatProvider>();
    if (provider.currentConversation == null) return;
    
    final markdown = ExportService.exportToMarkdown(provider.currentConversation!);
    Clipboard.setData(ClipboardData(text: markdown));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('会話をクリップボードにコピーしました'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final messages = provider.currentConversation?.messages ?? [];

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        // 新しいメッセージが追加されたらスクロール
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return MessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Chat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Llama.cppで駆動する会話AI',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      '自己紹介してください',
      '今日の天気について話そう',
      'プログラミングの質問',
      '物語を作って',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(
            suggestion,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          backgroundColor: AppTheme.darkCard,
          side: BorderSide(color: AppTheme.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: () {
            context.read<ChatProvider>().sendMessage(suggestion);
          },
        );
      }).toList(),
    );
  }

  Widget _buildErrorBanner() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.error == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(color: Colors.red.shade700),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.error!,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.red.shade400,
                  size: 18,
                ),
                onPressed: () {
                  provider.clearError();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Consumer4<ChatProvider, ProjectProvider, SearchProvider, SkillProvider>(
      builder: (context, chatProvider, projectProvider, searchProvider, skillProvider, child) {
        return ChatInput(
          isLoading: chatProvider.isLoading,
          searchMode: _searchMode,
          onSend: (text) async {
            final systemPrompt = projectProvider.currentSystemPrompt;
            final skillContext = skillProvider.getActiveSkillsContext();
            
            // Agentic検索用にプロバイダーを動的に設定
            final llmManager = context.read<LlmProviderManager>();
            if (llmManager.currentProvider != null) {
              chatProvider.setLlmProvider(llmManager.currentProvider);
            }
            if (searchProvider.searxngService != null) {
              chatProvider.setSearxngService(searchProvider.searxngService);
            }
            chatProvider.setAgenticSearchEnabled(searchProvider.agenticConfig.enabled);
            
            switch (_searchMode) {
              case SearchMode.off:
                // 検索なし
                chatProvider.sendMessage(text, projectSystemPrompt: systemPrompt, skillContext: skillContext);
                break;
              case SearchMode.simple:
                // 簡易検索
                await _sendWithSearch(text, chatProvider, searchProvider, systemPrompt, skillContext);
                break;
              case SearchMode.deep:
                // 詳細検索
                await _sendWithDeepSearch(text, chatProvider, searchProvider, systemPrompt, skillContext);
                break;
              case SearchMode.research:
                // リサーチ
                await _sendWithResearch(text, chatProvider, searchProvider, systemPrompt, skillContext);
                break;
            }
          },
          onStop: () {
            chatProvider.stopGeneration();
          },
          onSearchModeChanged: (mode) {
            setState(() => _searchMode = mode);
          },
          onSkillTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SkillScreen(
                  onExecuteSkill: (prompt) {
                    final systemPrompt = projectProvider.currentSystemPrompt;
                    chatProvider.sendMessage(prompt, projectSystemPrompt: systemPrompt);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendWithSearch(
    String query,
    ChatProvider chatProvider,
    SearchProvider searchProvider,
    String systemPrompt,
    String skillContext,
  ) async {
    // 検索を実行
    final results = await searchProvider.search(query);
    
    if (results.isEmpty) {
      // 検索結果なしの場合はそのまま送信
      chatProvider.sendMessage(query, projectSystemPrompt: systemPrompt, skillContext: skillContext);
      return;
    }

    // 検索結果をコンテキストに追加
    final searchContext = SearxngService.formatForContext(results);
    final enhancedPrompt = '''$query

$searchContext

上記のWeb検索結果を参考に、質問に回答してください。''';
    
    chatProvider.sendMessage(enhancedPrompt, projectSystemPrompt: systemPrompt, skillContext: skillContext);
  }

  /// 詳細検索（DeepSearch）でメッセージを送信
  Future<void> _sendWithDeepSearch(
    String query,
    ChatProvider chatProvider,
    SearchProvider searchProvider,
    String systemPrompt,
    String skillContext,
  ) async {
    // DeepSearchを実行
    final result = await searchProvider.deepSearch(query);
    
    if (result == null || result.searchResults.isEmpty) {
      // 検索結果なしの場合はそのまま送信
      chatProvider.sendMessage(query, projectSystemPrompt: systemPrompt, skillContext: skillContext);
      return;
    }

    // DeepSearch結果をコンテキストに追加
    final enhancedPrompt = '''$query

【詳細検索結果】
${result.summary}

参照ソース:
${result.sources.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

上記の検索結果を参考に、質問に回答してください。''';
    
    chatProvider.sendMessage(enhancedPrompt, projectSystemPrompt: systemPrompt, skillContext: skillContext);
  }

  /// リサーチでメッセージを送信
  Future<void> _sendWithResearch(
    String query,
    ChatProvider chatProvider,
    SearchProvider searchProvider,
    String systemPrompt,
    String skillContext,
  ) async {
    // リサーチを実行（ストリームで進捗を受け取る）
    String finalAnswer = '';
    
    await for (final progress in searchProvider.research(query)) {
      // 進捗をデバッグログに出力（UIにも表示できる）
      debugPrint('Research progress: ${progress.phase} - ${progress.message}');
      
      if (progress.phase == 'result') {
        finalAnswer = progress.message;
      }
    }

    if (finalAnswer.isEmpty) {
      // リサーチ結果なしの場合はそのまま送信
      chatProvider.sendMessage(query, projectSystemPrompt: systemPrompt, skillContext: skillContext);
      return;
    }

    // リサーチ結果をそのまま表示（検索結果は内部で統合済み）
    // ユーザーメッセージを追加
    chatProvider.addUserMessage(query);
    
    // アシスタントメッセージとしてリサーチ結果を追加
    chatProvider.addAssistantMessage('''【リサーチ結果】

$finalAnswer''');
  }
}
