import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/skill.dart';
import '../../providers/skill_provider.dart';
import '../../theme/app_theme.dart';

class SkillScreen extends StatelessWidget {
  final Function(String prompt)? onExecuteSkill;

  const SkillScreen({super.key, this.onExecuteSkill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('スキル'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            ),
            onPressed: () => _showCreateDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<SkillProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.skills.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.skills.length,
            itemBuilder: (context, index) {
              return _buildSkillCard(context, provider.skills[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_alt_rounded,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'スキルがありません',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<SkillProvider>().resetToDefaults(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('プリセットを復元'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(BuildContext context, Skill skill) {
    final color = _parseColor(skill.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.darkBorder),
      ),
      child: InkWell(
        onTap: () => _showExecuteDialog(context, skill),
        onLongPress: () => _showOptionsSheet(context, skill),
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
                child: Text(
                  skill.icon ?? '⚡',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (skill.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        skill.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (skill.variables.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: skill.variables.map((v) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '{{${v.name}}}',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color: color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExecuteDialog(BuildContext context, Skill skill) {
    final controllers = <String, TextEditingController>{};
    for (final variable in skill.variables) {
      controllers[variable.name] = TextEditingController(text: variable.defaultValue ?? '');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(skill.icon ?? '⚡', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.name,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: skill.variables.map((variable) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controllers[variable.name],
                  maxLines: variable.name == 'text' || variable.name == 'code' ? 5 : 1,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: '${variable.label}${variable.required ? ' *' : ''}',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    helperText: variable.description,
                    helperStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // 変数を収集
              final values = <String, String>{};
              controllers.forEach((key, controller) {
                values[key] = controller.text;
              });

              // プロンプトを生成
              final prompt = skill.generatePrompt(values);
              Navigator.pop(context);
              
              // 結果を返す
              if (onExecuteSkill != null) {
                onExecuteSkill!(prompt);
                Navigator.pop(context);  // スキル画面も閉じる
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('実行'),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, Skill skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
                title: const Text('編集', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, skill);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text('削除', style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  context.read<SkillProvider>().deleteSkill(skill.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final templateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('新規スキル', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('スキル名', Icons.label_rounded),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('説明', Icons.description_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: templateController,
                maxLines: 5,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('プロンプト', Icons.edit_note_rounded)
                    .copyWith(helperText: '変数は {{変数名}} で指定'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              await context.read<SkillProvider>().createSkill(
                name: nameController.text.trim(),
                description: descController.text.trim(),
                promptTemplate: templateController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Skill skill) {
    final nameController = TextEditingController(text: skill.name);
    final descController = TextEditingController(text: skill.description);
    final templateController = TextEditingController(text: skill.promptTemplate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('スキルを編集', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('スキル名', Icons.label_rounded),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('説明', Icons.description_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: templateController,
                maxLines: 5,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDecoration('プロンプト', Icons.edit_note_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              await context.read<SkillProvider>().updateSkill(
                skill.copyWith(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  promptTemplate: templateController.text.trim(),
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textMuted),
      prefixIcon: Icon(icon, color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.darkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.primaryColor;
    }
  }
}
