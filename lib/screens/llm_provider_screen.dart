import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/llm_provider_manager.dart';
import '../../services/llm_provider.dart';
import '../../theme/app_theme.dart';

class LlmProviderScreen extends StatelessWidget {
  const LlmProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('LLMプロバイダー'),
        actions: [
          PopupMenuButton<LlmProviderType>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            ),
            onSelected: (type) {
              context.read<LlmProviderManager>().addDefaultProvider(type);
            },
            itemBuilder: (context) => [
              _buildMenuItem(LlmProviderType.llamaCpp, 'Llama.cpp (ローカル)', Icons.computer),
              _buildMenuItem(LlmProviderType.claude, 'Claude (Anthropic)', Icons.psychology),
              _buildMenuItem(LlmProviderType.openai, 'ChatGPT (OpenAI)', Icons.chat),
              _buildMenuItem(LlmProviderType.gemini, 'Gemini (Google)', Icons.auto_awesome),
              _buildMenuItem(LlmProviderType.azureOpenai, 'Azure OpenAI', Icons.cloud),
              _buildMenuItem(LlmProviderType.azureClaude, 'Azure Claude', Icons.cloud_circle),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<LlmProviderManager>(
        builder: (context, manager, child) {
          if (manager.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (manager.providers.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: manager.providers.length,
            itemBuilder: (context, index) {
              return _buildProviderCard(context, manager, index);
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<LlmProviderType> _buildMenuItem(
    LlmProviderType type,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'プロバイダーがありません',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    LlmProviderManager manager,
    int index,
  ) {
    final config = manager.providers[index];
    final isActive = index == manager.currentIndex;
    final color = _getProviderColor(config.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? color.withValues(alpha: 0.1) : AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? color : AppTheme.darkBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => manager.switchProvider(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getProviderIcon(config.type),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          config.name,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '使用中',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.model ?? config.baseUrl,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (config.apiKey != null && config.apiKey!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.key, size: 12, color: Colors.green.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'APIキー設定済み',
                            style: TextStyle(color: Colors.green.shade400, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // アクションボタン
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textMuted),
                onSelected: (action) => _handleAction(context, manager, index, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('編集')),
                  const PopupMenuItem(value: 'test', child: Text('接続テスト')),
                  if (manager.providers.length > 1)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('削除', style: TextStyle(color: Colors.red.shade400)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    LlmProviderManager manager,
    int index,
    String action,
  ) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, manager, index);
        break;
      case 'test':
        _testConnection(context, manager, index);
        break;
      case 'delete':
        manager.removeProvider(index);
        break;
    }
  }

  void _testConnection(
    BuildContext context,
    LlmProviderManager manager,
    int index,
  ) async {
    // 一時的にそのプロバイダーに切り替えてテスト
    await manager.switchProvider(index);
    final connected = await manager.testConnection();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connected ? '接続成功！' : '接続失敗'),
          backgroundColor: connected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showEditDialog(
    BuildContext context,
    LlmProviderManager manager,
    int index,
  ) {
    final config = manager.providers[index];
    final nameController = TextEditingController(text: config.name);
    final urlController = TextEditingController(text: config.baseUrl);
    final keyController = TextEditingController(text: config.apiKey ?? '');
    final modelController = TextEditingController(text: config.model ?? '');
    final deploymentController = TextEditingController(text: config.deploymentName ?? '');
    final apiVersionController = TextEditingController(text: config.apiVersion ?? '2024-02-15-preview');
    final maxTokensController = TextEditingController(text: (config.maxTokens ?? 8192).toString());
    final isAzure = config.type == LlmProviderType.azureOpenai;
    final isClaude = config.type == LlmProviderType.claude || config.type == LlmProviderType.azureClaude;
    bool useMaxTokens = config.useMaxTokens;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${config.name}を編集', style: const TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, '表示名', Icons.label),
                const SizedBox(height: 16),
                _buildTextField(urlController, isAzure ? 'リソースURL' : 'API URL', Icons.link),
                const SizedBox(height: 16),
                _buildTextField(keyController, 'APIキー', Icons.key, obscure: true),
                const SizedBox(height: 16),
                if (isAzure) ...[
                  _buildTextField(deploymentController, 'デプロイメント名', Icons.rocket_launch),
                  const SizedBox(height: 16),
                  _buildTextField(apiVersionController, 'APIバージョン', Icons.history),
                ] else
                  _buildTextField(modelController, 'モデル', Icons.smart_toy),
                const SizedBox(height: 16),
                // max_tokens設定
                if (isClaude) ...[
                  // Claude系は必須なので入力欄のみ
                  _buildTextField(maxTokensController, '最大出力トークン (必須)', Icons.data_usage),
                ] else ...[
                  // OpenAI系はON/OFF + 入力欄
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '最大トークン制限',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: useMaxTokens,
                        onChanged: (v) => setDialogState(() => useMaxTokens = v),
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  if (useMaxTokens) ...[
                    const SizedBox(height: 8),
                    _buildTextField(maxTokensController, '最大出力トークン', Icons.data_usage),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('キャンセル', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final maxTokens = int.tryParse(maxTokensController.text.trim()) ?? 8192;
                manager.updateProvider(
                  index,
                  config.copyWith(
                    name: nameController.text.trim(),
                    baseUrl: urlController.text.trim(),
                    apiKey: keyController.text.trim().isEmpty ? null : keyController.text.trim(),
                    model: modelController.text.trim().isEmpty ? null : modelController.text.trim(),
                    deploymentName: deploymentController.text.trim().isEmpty ? null : deploymentController.text.trim(),
                    apiVersion: apiVersionController.text.trim().isEmpty ? null : apiVersionController.text.trim(),
                    maxTokens: maxTokens,
                    useMaxTokens: useMaxTokens,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Color _getProviderColor(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.llamaCpp:
        return Colors.orange;
      case LlmProviderType.claude:
        return const Color(0xFFCC785C);
      case LlmProviderType.openai:
        return const Color(0xFF10A37F);
      case LlmProviderType.gemini:
        return const Color(0xFF4285F4);
      case LlmProviderType.azureOpenai:
        return const Color(0xFF0078D4);  // Azure blue
      case LlmProviderType.azureClaude:
        return const Color(0xFF9B4DCA);  // Purple for Claude
    }
  }

  IconData _getProviderIcon(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.llamaCpp:
        return Icons.computer;
      case LlmProviderType.claude:
        return Icons.psychology;
      case LlmProviderType.openai:
        return Icons.chat;
      case LlmProviderType.gemini:
        return Icons.auto_awesome;
      case LlmProviderType.azureOpenai:
        return Icons.cloud;
      case LlmProviderType.azureClaude:
        return Icons.cloud_circle;
    }
  }
}
