import 'package:uuid/uuid.dart';

/// スキル（定型処理）モデル
class Skill {
  final String id;
  final String name;
  final String description;
  final String promptTemplate;
  final String? icon;
  final String color;
  final List<SkillVariable> variables;
  final DateTime createdAt;
  final DateTime updatedAt;

  Skill({
    String? id,
    required this.name,
    this.description = '',
    required this.promptTemplate,
    this.icon,
    this.color = '#6366F1',
    this.variables = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? promptTemplate,
    String? icon,
    String? color,
    List<SkillVariable>? variables,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      variables: variables ?? this.variables,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 変数を埋め込んでプロンプトを生成
  String generatePrompt(Map<String, String> variableValues) {
    String result = promptTemplate;
    for (final variable in variables) {
      final value = variableValues[variable.name] ?? variable.defaultValue ?? '';
      result = result.replaceAll('{{${variable.name}}}', value);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'promptTemplate': promptTemplate,
    'icon': icon,
    'color': color,
    'variables': variables.map((v) => v.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      promptTemplate: json['promptTemplate'],
      icon: json['icon'],
      color: json['color'] ?? '#6366F1',
      variables: (json['variables'] as List?)
          ?.map((v) => SkillVariable.fromJson(v))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

/// スキル変数
class SkillVariable {
  final String name;
  final String label;
  final String? description;
  final String? defaultValue;
  final bool required;

  const SkillVariable({
    required this.name,
    required this.label,
    this.description,
    this.defaultValue,
    this.required = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'description': description,
    'defaultValue': defaultValue,
    'required': required,
  };

  factory SkillVariable.fromJson(Map<String, dynamic> json) {
    return SkillVariable(
      name: json['name'],
      label: json['label'],
      description: json['description'],
      defaultValue: json['defaultValue'],
      required: json['required'] ?? false,
    );
  }
}

/// プリセットスキルのテンプレート
class SkillTemplates {
  static List<Skill> get templates => [
    Skill(
      name: '要約',
      description: 'テキストを要約する',
      icon: '📝',
      color: '#8B5CF6',
      promptTemplate: '''以下のテキストを簡潔に要約してください。

{{text}}

要約のポイント:
- 重要な情報を漏らさず含める
- 箇条書きで整理
- 原文の{{length}}程度の長さに''',
      variables: [
        const SkillVariable(name: 'text', label: 'テキスト', required: true),
        const SkillVariable(name: 'length', label: '要約の長さ', defaultValue: '3分の1'),
      ],
    ),
    Skill(
      name: '翻訳',
      description: '日英・英日翻訳',
      icon: '🌐',
      color: '#3B82F6',
      promptTemplate: '''以下のテキストを{{targetLang}}に翻訳してください。
自然で読みやすい翻訳を心がけてください。

{{text}}''',
      variables: [
        const SkillVariable(name: 'text', label: 'テキスト', required: true),
        const SkillVariable(name: 'targetLang', label: '翻訳先言語', defaultValue: '英語'),
      ],
    ),
    Skill(
      name: 'コードレビュー',
      description: 'コードの問題点を指摘',
      icon: '🔍',
      color: '#10B981',
      promptTemplate: '''以下のコードをレビューしてください。

```{{language}}
{{code}}
```

以下の観点から分析してください:
1. バグや潜在的な問題
2. パフォーマンスの改善点
3. 可読性の改善点
4. ベストプラクティスへの準拠''',
      variables: [
        const SkillVariable(name: 'code', label: 'コード', required: true),
        const SkillVariable(name: 'language', label: '言語', defaultValue: 'dart'),
      ],
    ),
    Skill(
      name: '文章校正',
      description: '文章の誤りを修正',
      icon: '✏️',
      color: '#F59E0B',
      promptTemplate: '''以下の文章を校正してください。

{{text}}

修正すべき点:
- 誤字脱字
- 文法の誤り
- 表現の改善
- より適切な言い回し

修正版と、変更点の説明をお願いします。''',
      variables: [
        const SkillVariable(name: 'text', label: 'テキスト', required: true),
      ],
    ),
    Skill(
      name: 'アイデア出し',
      description: 'ブレインストーミング',
      icon: '💡',
      color: '#EC4899',
      promptTemplate: '''「{{topic}}」について、{{count}}個のアイデアを出してください。

条件: {{conditions}}

創造的で実現可能なアイデアを、それぞれ簡潔に説明してください。''',
      variables: [
        const SkillVariable(name: 'topic', label: 'トピック', required: true),
        const SkillVariable(name: 'count', label: 'アイデア数', defaultValue: '5'),
        const SkillVariable(name: 'conditions', label: '条件', defaultValue: '特になし'),
      ],
    ),
  ];
}
