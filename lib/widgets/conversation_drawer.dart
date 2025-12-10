import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/llm_provider_manager.dart';
import '../../services/export_service.dart';
import '../../screens/settings_screen.dart';
import '../../theme/app_theme.dart';

class ConversationDrawer extends StatelessWidget {
  const ConversationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppTheme.darkSurface,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildConversationList(context),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Llama.cpp',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.createNewConversation();
              Navigator.pop(context);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final conversations = provider.conversations;

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  '会話がありません',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final isSelected = conversation.id == provider.currentConversation?.id;

            return _buildConversationTile(
              context,
              conversation.id,
              conversation.title,
              conversation.messages.length,
              conversation.updatedAt,
              isSelected,
            );
          },
        );
      },
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    String id,
    String title,
    int messageCount,
    DateTime updatedAt,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<ChatProvider>().selectConversation(id);
            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chat_rounded,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$messageCount メッセージ • ${_formatDate(updatedAt)}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  color: AppTheme.darkCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    _buildPopupMenuItem(
                      'export',
                      Icons.file_download_outlined,
                      'エクスポート',
                    ),
                    _buildPopupMenuItem(
                      'delete',
                      Icons.delete_outline_rounded,
                      '削除',
                      isDestructive: true,
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(context, id, title);
                    } else if (value == 'export') {
                      _exportConversation(context, id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDestructive ? Colors.red.shade400 : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red.shade400 : AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _exportConversation(BuildContext context, String id) {
    final provider = context.read<ChatProvider>();
    final conversation = provider.conversations.firstWhere((c) => c.id == id);
    final markdown = ExportService.exportToMarkdown(conversation);
    
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showDeleteConfirmation(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '会話を削除',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '「$title」を削除しますか？\nこの操作は取り消せません。',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () {
              context.read<ChatProvider>().deleteConversation(id);
              Navigator.pop(context);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.darkBorder),
            ),
          ),
          child: Column(
            children: [
              // エクスポートボタン
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showExportAllDialog(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '全会話をエクスポート',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 接続状態と設定
              Consumer<LlmProviderManager>(
                builder: (context, llmManager, _) {
                  final config = llmManager.currentConfig;
                  final isConnected = llmManager.isConnected;
                  
                  return Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config?.name ?? 'プロバイダー未設定',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (config?.model != null)
                              Text(
                                config!.model!,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                        tooltip: '設定',
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportAllDialog(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final markdown = ExportService.exportMultipleToMarkdown(provider.conversations);
    
    Clipboard.setData(ClipboardData(text: markdown));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('${provider.conversations.length}件の会話をコピーしました'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
