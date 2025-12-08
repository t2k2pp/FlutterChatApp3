import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/conversation_drawer.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

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
          Expanded(
            child: _buildMessageList(),
          ),
          _buildErrorBanner(),
          _buildInput(),
        ],
      ),
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
                          .withOpacity(0.5),
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
                    color: AppTheme.primaryColor.withOpacity(0.3),
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
            color: Colors.red.shade900.withOpacity(0.3),
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
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        return ChatInput(
          isLoading: provider.isLoading,
          onSend: (text) {
            provider.sendMessage(text);
          },
          onStop: () {
            provider.stopGeneration();
          },
        );
      },
    );
  }
}
