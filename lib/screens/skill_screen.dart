import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/skill.dart';
import '../../providers/skill_provider.dart';
import '../../theme/app_theme.dart';

class SkillScreen extends StatelessWidget {
  final Function(String)? onExecuteSkill;

  const SkillScreen({super.key, this.onExecuteSkill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('スキル'),
        actions: [
          // 自動検出トグル
          Consumer<SkillProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.autoDetectEnabled 
                      ? Icons.auto_awesome 
                      : Icons.auto_awesome_outlined,
                  color: provider.autoDetectEnabled 
                      ? AppTheme.accentColor 
                      : AppTheme.textMuted,
                ),
                tooltip: '自動検出 ${provider.autoDetectEnabled ? "ON" : "OFF"}',
                onPressed: () {
                  provider.setAutoDetect(!provider.autoDetectEnabled);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showSkillEditor(context, null),
          ),
        ],
      ),
      body: Consumer<SkillProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // 有効なスキル
              if (provider.activeSkills.isNotEmpty)
                _buildActiveSkillsBar(context, provider),
              // スキル一覧
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.skills.length,
                  itemBuilder: (context, index) {
                    return _buildSkillCard(context, provider.skills[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveSkillsBar(BuildContext context, SkillProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on, size: 18, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Text(
            '有効:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: provider.activeSkills.map((skill) {
                return Chip(
                  label: Text(
                    '${skill.icon} ${skill.name}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => provider.deactivateSkill(skill.id),
                  backgroundColor: _parseColor(skill.color).withValues(alpha: 0.2),
                  side: BorderSide(color: _parseColor(skill.color)),
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: () => provider.deactivateAllSkills(),
            child: const Text('全解除'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(BuildContext context, Skill skill) {
    final provider = context.read<SkillProvider>();
    final isActive = provider.activeSkills.any((s) => s.id == skill.id);
    final color = _parseColor(skill.color);

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
        onTap: () {
          if (isActive) {
            provider.deactivateSkill(skill.id);
          } else {
            provider.activateSkill(skill);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(skill.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              skill.name,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (skill.isBuiltIn) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.textMuted.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ビルトイン',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: color,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skill.description,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppTheme.textMuted),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _showSkillEditor(context, skill);
                          break;
                        case 'delete':
                          provider.deleteSkill(skill.id);
                          break;
                        case 'view':
                          _showSkillDetails(context, skill);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('詳細を見る'),
                      ),
                      if (!skill.isBuiltIn) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('編集'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            '削除',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              // トリガー情報
              if (skill.trigger.keywords.isNotEmpty ||
                  skill.trigger.patterns.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...skill.trigger.keywords.take(3).map((kw) => _buildTag(kw)),
                    if (skill.trigger.keywords.length > 3)
                      _buildTag('+${skill.trigger.keywords.length - 3}'),
                  ],
                ),
              ],
              // ファイル数
              const SizedBox(height: 8),
              Text(
                '${skill.files.length}ファイル',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }

  void _showSkillDetails(BuildContext context, Skill skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(skill.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        skill.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  skill.description,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'ファイル構成',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: skill.files.length,
                    itemBuilder: (context, index) {
                      final file = skill.files[index];
                      return _buildFileCard(file);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileCard(SkillFile file) {
    IconData icon;
    switch (file.type) {
      case SkillFileType.instruction:
        icon = Icons.description;
        break;
      case SkillFileType.prompt:
        icon = Icons.chat;
        break;
      case SkillFileType.script:
        icon = Icons.code;
        break;
      case SkillFileType.reference:
        icon = Icons.book;
        break;
      case SkillFileType.example:
        icon = Icons.lightbulb;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkBackground,
      child: ExpansionTile(
        leading: Icon(icon, color: AppTheme.textSecondary),
        title: Text(
          file.name,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        ),
        subtitle: file.description != null
            ? Text(
                file.description!,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              )
            : null,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkCard,
            child: SelectableText(
              file.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSkillEditor(BuildContext context, Skill? existingSkill) {
    final provider = context.read<SkillProvider>();
    final skill = existingSkill ?? provider.createNewSkill();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkillEditorScreen(
          skill: skill,
          isNew: existingSkill == null,
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.accentColor;
    }
  }
}

/// スキル編集画面
class SkillEditorScreen extends StatefulWidget {
  final Skill skill;
  final bool isNew;

  const SkillEditorScreen({
    super.key,
    required this.skill,
    this.isNew = false,
  });

  @override
  State<SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends State<SkillEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _keywordsController;
  late List<SkillFile> _files;
  late List<TextEditingController> _fileControllers;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.skill.name);
    _descriptionController = TextEditingController(text: widget.skill.description);
    _keywordsController = TextEditingController(
      text: widget.skill.trigger.keywords.join(', '),
    );
    _files = List.from(widget.skill.files);
    _fileControllers = _files.map((f) => TextEditingController(text: f.content)).toList();
    _icon = widget.skill.icon;
    _color = widget.skill.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _keywordsController.dispose();
    for (final c in _fileControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: Text(widget.isNew ? '新規スキル' : 'スキル編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _saveSkill,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本情報
          _buildTextField(_nameController, '名前', Icons.label),
          const SizedBox(height: 16),
          _buildTextField(_descriptionController, '説明', Icons.description),
          const SizedBox(height: 16),
          _buildTextField(_keywordsController, 'トリガーキーワード（カンマ区切り）', Icons.flash_on),
          const SizedBox(height: 24),
          
          // ファイル一覧
          Row(
            children: [
              Text(
                'ファイル',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addFile,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._files.asMap().entries.map((entry) {
            return _buildFileEditor(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFileEditor(int index, SkillFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          file.name,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          file.type.name,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: () {
            setState(() {
              _files.removeAt(index);
              _fileControllers[index].dispose();
              _fileControllers.removeAt(index);
            });
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _fileControllers[index],
              maxLines: 10,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _files[index] = SkillFile(
                  name: file.name,
                  type: file.type,
                  content: value,
                  description: file.description,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addFile() {
    final content = '# 新規ファイル\n\n内容を記述';
    setState(() {
      _files.add(SkillFile(
        name: 'new_file.md',
        type: SkillFileType.reference,
        content: content,
      ));
      _fileControllers.add(TextEditingController(text: content));
    });
  }

  void _saveSkill() {
    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final updatedSkill = widget.skill.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      icon: _icon,
      color: _color,
      files: _files,
      trigger: SkillTrigger(keywords: keywords),
    );

    final provider = context.read<SkillProvider>();
    if (widget.isNew) {
      provider.addSkill(updatedSkill);
    } else {
      provider.updateSkill(updatedSkill);
    }

    Navigator.pop(context);
  }
}
