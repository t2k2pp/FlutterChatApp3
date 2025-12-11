import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/watson_config.dart';
import '../providers/chat_provider.dart';
import '../providers/llm_provider_manager.dart';
import '../providers/watson_provider.dart';
import '../providers/search_provider.dart';
import '../services/llm_provider.dart';
import '../theme/app_theme.dart';
import 'llm_provider_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _systemPromptController;
  late TextEditingController _searxngUrlController;

  @override
  void initState() {
    super.initState();
    final chatProvider = context.read<ChatProvider>();
    final searchProvider = context.read<SearchProvider>();
    _systemPromptController = TextEditingController(text: chatProvider.systemPrompt);
    _searxngUrlController = TextEditingController(text: searchProvider.searxngUrl);
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _searxngUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LLMプロバイダー
          _buildSectionCard(
            icon: Icons.cloud_outlined,
            iconColor: AppTheme.primaryColor,
            title: 'LLMプロバイダー',
            child: _buildLlmProviderSection(),
          ),
          const SizedBox(height: 16),

          // Watson
          _buildSectionCard(
            icon: Icons.psychology,
            iconColor: AppTheme.accentColor,
            title: 'Watson（AIアシスタント補佐）',
            child: _buildWatsonSection(),
          ),
          const SizedBox(height: 16),

          // 検索
          _buildSectionCard(
            icon: Icons.search,
            iconColor: Colors.blue,
            title: 'Web検索',
            child: _buildSearchSection(),
          ),
          const SizedBox(height: 16),

          // システムプロンプト
          _buildSectionCard(
            icon: Icons.edit_note,
            iconColor: Colors.orange,
            title: 'システムプロンプト',
            child: _buildSystemPromptSection(),
          ),
          const SizedBox(height: 16),

          // バージョン情報
          _buildVersionInfo(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildLlmProviderSection() {
    return Consumer<LlmProviderManager>(
      builder: (context, manager, _) {
        final current = manager.currentConfig;
        return Column(
          children: [
            // 現在のプロバイダー
            _buildInfoRow(
              label: '現在のプロバイダー',
              value: current?.name ?? '未設定',
              trailing: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: manager.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (current?.model != null)
              _buildInfoRow(label: 'モデル', value: current!.model!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LlmProviderScreen()),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('プロバイダーを管理'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.darkBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWatsonSection() {
    return Consumer2<WatsonProvider, LlmProviderManager>(
      builder: (context, watson, llmManager, _) {
        final config = watson.config;
        return Column(
          children: [
            // Watson有効/無効
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Watson', style: TextStyle(color: AppTheme.textPrimary)),
                Switch(
                  value: config.enabled,
                  onChanged: (v) => watson.updateConfig(config.copyWith(enabled: v)),
                  activeColor: AppTheme.accentColor,
                ),
              ],
            ),
            if (config.enabled) ...[
              const SizedBox(height: 12),
              // 介入レベル
              _buildDropdown<WatsonInterruptLevel>(
                label: '介入レベル',
                value: config.interruptLevel,
                items: WatsonInterruptLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(_getInterruptLevelName(level)),
                  );
                }).toList(),
                onChanged: (v) => watson.setInterruptLevel(v!),
              ),
              const SizedBox(height: 12),
              // 使用モデル
              _buildDropdown<int?>(
                label: '使用モデル',
                value: config.providerIndex,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('メインAIと同じ'),
                  ),
                  ...llmManager.providers.asMap().entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value.name),
                    );
                  }),
                ],
                onChanged: (v) => watson.setProviderIndex(v),
              ),
              const SizedBox(height: 12),
              // 起動ワード
              InkWell(
                onTap: () => _showActivationWordsDialog(context, watson, config),
                child: _buildInfoRow(
                  label: '起動ワード',
                  value: config.activationWords.take(3).join(', ') +
                      (config.activationWords.length > 3 ? '...' : ''),
                  trailing: const Icon(Icons.edit, size: 16, color: AppTheme.textMuted),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchSection() {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, _) {
        return Column(
          children: [
            // Web検索有効/無効
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Web検索', style: TextStyle(color: AppTheme.textPrimary)),
                Switch(
                  value: searchProvider.isEnabled,
                  onChanged: (v) => searchProvider.setEnabled(v),
                  activeColor: Colors.blue,
                ),
              ],
            ),
            if (searchProvider.isEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _searxngUrlController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _buildInputDecoration('SearXNG URL', Icons.link),
                onChanged: (v) => searchProvider.setSearxngUrl(v),
              ),
              const SizedBox(height: 12),
              // 詳細検索（DeepSearch）
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('詳細検索 (Deep Search)', style: TextStyle(color: AppTheme.textPrimary)),
                  Switch(
                    value: searchProvider.deepSearchEnabled,
                    onChanged: (v) => searchProvider.setDeepSearchEnabled(v),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // リサーチ設定
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, size: 18, color: Colors.purple.shade300),
                        const SizedBox(width: 8),
                        Text(
                          'リサーチ機能 (Agentic Research)',
                          style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      label: '最大ループ回数',
                      value: '${searchProvider.researchConfig.maxIterations}回',
                      trailing: SizedBox(
                        width: 120,
                        child: Slider(
                          value: searchProvider.researchConfig.maxIterations.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          onChanged: (v) => searchProvider.updateResearchConfig(
                            searchProvider.researchConfig.copyWith(maxIterations: v.round()),
                          ),
                          activeColor: Colors.purple.shade300,
                        ),
                      ),
                    ),
                    _buildInfoRow(
                      label: '確信度閾値',
                      value: '${searchProvider.researchConfig.confidenceThreshold}%',
                      trailing: SizedBox(
                        width: 120,
                        child: Slider(
                          value: searchProvider.researchConfig.confidenceThreshold.toDouble(),
                          min: 50,
                          max: 100,
                          divisions: 10,
                          onChanged: (v) => searchProvider.updateResearchConfig(
                            searchProvider.researchConfig.copyWith(confidenceThreshold: v.round()),
                          ),
                          activeColor: Colors.purple.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Agentic Web検索設定
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: Colors.amber.shade300),
                            const SizedBox(width: 8),
                            Text(
                              'Agentic Web検索',
                              style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Switch(
                          value: searchProvider.agenticConfig.enabled,
                          onChanged: (v) => searchProvider.updateAgenticConfig(
                            searchProvider.agenticConfig.copyWith(enabled: v),
                          ),
                          activeColor: Colors.amber.shade300,
                        ),
                      ],
                    ),
                    if (searchProvider.agenticConfig.enabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'AIが必要と判断した際に自動でWeb検索を実行します',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSystemPromptSection() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'グローバルシステムプロンプト',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _systemPromptController,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: _buildInputDecoration('AIへの指示（全会話に適用）', Icons.edit_note),
              onChanged: (v) => chatProvider.updateSettings(systemPrompt: v),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Flutter AI Chat App',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'v1.0.0',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppTheme.darkCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          underline: const SizedBox(),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      filled: true,
      fillColor: AppTheme.darkBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _getInterruptLevelName(WatsonInterruptLevel level) {
    switch (level) {
      case WatsonInterruptLevel.off:
        return 'OFF';
      case WatsonInterruptLevel.passive:
        return '消極的';
      case WatsonInterruptLevel.normal:
        return '普通';
      case WatsonInterruptLevel.proactive:
        return '積極的';
    }
  }

  void _showActivationWordsDialog(
    BuildContext context,
    WatsonProvider watson,
    WatsonConfig config,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('起動ワード', style: TextStyle(color: AppTheme.textPrimary)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'これらの言葉を含むメッセージでWatsonを呼び出せます',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...config.activationWords.map((word) {
                      return Chip(
                        label: Text(word, style: const TextStyle(fontSize: 13)),
                        backgroundColor: AppTheme.darkBackground,
                        side: const BorderSide(color: AppTheme.darkBorder),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          final newWords = config.activationWords
                              .where((w) => w != word)
                              .toList();
                          watson.setActivationWords(newWords);
                          setDialogState(() {});
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '新しい起動ワード',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty && !config.activationWords.contains(value.trim())) {
                            watson.setActivationWords([...config.activationWords, value.trim()]);
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
