import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/watson_config.dart';
import '../providers/watson_provider.dart';
import '../providers/llm_provider_manager.dart';
import '../theme/app_theme.dart';

class WatsonSettingsScreen extends StatelessWidget {
  const WatsonSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Watson設定'),
      ),
      body: Consumer2<WatsonProvider, LlmProviderManager>(
        builder: (context, watsonProvider, llmManager, child) {
          final config = watsonProvider.config;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 有効/無効スイッチ
              _buildSwitchTile(
                icon: Icons.psychology,
                title: 'Watson',
                subtitle: 'AIアシスタントの補佐役',
                value: config.enabled,
                onChanged: (value) {
                  watsonProvider.updateConfig(config.copyWith(enabled: value));
                },
              ),
              const SizedBox(height: 24),

              // 介入レベル
              _buildSectionTitle('介入レベル'),
              const SizedBox(height: 12),
              _buildInterruptLevelSelector(context, watsonProvider, config),
              const SizedBox(height: 24),

              // モデル選択
              _buildSectionTitle('使用するモデル'),
              const SizedBox(height: 12),
              _buildModelSelector(context, watsonProvider, llmManager),
              const SizedBox(height: 24),

              // 起動ワード
              _buildSectionTitle('起動ワード'),
              const SizedBox(height: 8),
              Text(
                'これらの言葉を含むメッセージでWatsonを呼び出せます',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _buildActivationWordsList(context, watsonProvider, config),
              const SizedBox(height: 24),

              // 介入履歴
              if (watsonProvider.interjections.isNotEmpty) ...[
                _buildSectionTitle('最近の介入 (${watsonProvider.interjections.length})'),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => watsonProvider.clearHistory(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('履歴をクリア'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (value ? AppTheme.accentColor : AppTheme.textMuted).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.accentColor : AppTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInterruptLevelSelector(
    BuildContext context,
    WatsonProvider provider,
    WatsonConfig config,
  ) {
    return Column(
      children: WatsonInterruptLevel.values.map((level) {
        final isSelected = config.interruptLevel == level;
        final info = _getLevelInfo(level);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => provider.setInterruptLevel(level),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? info.color.withValues(alpha: 0.1) 
                      : AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? info.color : AppTheme.darkBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(info.icon, color: info.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.label,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          Text(
                            info.description,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: info.color, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModelSelector(
    BuildContext context,
    WatsonProvider watsonProvider,
    LlmProviderManager llmManager,
  ) {
    final providers = llmManager.providers;
    final selectedIndex = watsonProvider.config.providerIndex;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // メインと同じ
          _buildModelOption(
            icon: Icons.sync,
            label: 'メインAIと同じ',
            subtitle: providers.isNotEmpty ? providers[llmManager.currentIndex].name : '',
            isSelected: selectedIndex == null,
            onTap: () => watsonProvider.setProviderIndex(null),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          // 他のプロバイダー
          ...providers.asMap().entries.map((entry) {
            return _buildModelOption(
              icon: Icons.smart_toy,
              label: entry.value.name,
              subtitle: entry.value.model ?? entry.value.baseUrl,
              isSelected: selectedIndex == entry.key,
              onTap: () => watsonProvider.setProviderIndex(entry.key),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModelOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accentColor : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: AppTheme.accentColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivationWordsList(
    BuildContext context,
    WatsonProvider provider,
    WatsonConfig config,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...config.activationWords.map((word) {
          return Chip(
            label: Text(word, style: const TextStyle(fontSize: 13)),
            backgroundColor: AppTheme.darkCard,
            side: const BorderSide(color: AppTheme.darkBorder),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              final newWords = config.activationWords
                  .where((w) => w != word)
                  .toList();
              provider.setActivationWords(newWords);
            },
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('追加', style: TextStyle(fontSize: 13)),
          backgroundColor: AppTheme.darkCard,
          side: const BorderSide(color: AppTheme.darkBorder),
          onPressed: () => _showAddWordDialog(context, provider, config),
        ),
      ],
    );
  }

  void _showAddWordDialog(
    BuildContext context,
    WatsonProvider provider,
    WatsonConfig config,
  ) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('起動ワードを追加', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '例: ねえワトソン',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final word = controller.text.trim();
              if (word.isNotEmpty && !config.activationWords.contains(word)) {
                provider.setActivationWords([...config.activationWords, word]);
              }
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  _LevelInfo _getLevelInfo(WatsonInterruptLevel level) {
    switch (level) {
      case WatsonInterruptLevel.off:
        return _LevelInfo(
          label: 'OFF',
          description: '自動介入しない（手動呼び出しのみ）',
          icon: Icons.pause_circle_outline,
          color: AppTheme.textMuted,
        );
      case WatsonInterruptLevel.passive:
        return _LevelInfo(
          label: '消極的',
          description: '明らかな誤りや危険な情報のみ指摘',
          icon: Icons.visibility_outlined,
          color: Colors.blue,
        );
      case WatsonInterruptLevel.normal:
        return _LevelInfo(
          label: '普通',
          description: '事実誤認、論理矛盾、重要な欠落を指摘',
          icon: Icons.balance,
          color: Colors.orange,
        );
      case WatsonInterruptLevel.proactive:
        return _LevelInfo(
          label: '積極的',
          description: '詳細分析と代替案を積極的に提案',
          icon: Icons.tips_and_updates,
          color: Colors.green,
        );
    }
  }
}

class _LevelInfo {
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  _LevelInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}
