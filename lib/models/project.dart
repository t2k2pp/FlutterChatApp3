import 'package:uuid/uuid.dart';

/// プロジェクト（Gem）モデル
/// Claude Projects や Gemini Gems に相当する機能
class Project {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? icon;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    String? id,
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.icon,
    this.color = '#6366F1',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'icon': icon,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      systemPrompt: json['systemPrompt'] ?? '',
      icon: json['icon'],
      color: json['color'] ?? '#6366F1',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// デフォルトプロジェクト（プロジェクト未選択時）
  static Project get defaultProject => Project(
        id: 'default',
        name: '一般',
        description: '汎用的な会話',
        systemPrompt: '',
        icon: '💬',
        color: '#6366F1',
      );
}

/// プリセットプロジェクトのテンプレート
class ProjectTemplates {
  static List<Project> get templates => [
        Project(
          name: 'コーディングアシスタント',
          description: 'プログラミングの質問や補助',
          systemPrompt: 'あなたは優秀なプログラミングアシスタントです。コードの説明、デバッグ、最適化を手伝います。コードブロックを使って読みやすく回答してください。',
          icon: '💻',
          color: '#10B981',
        ),
        Project(
          name: '文章校正',
          description: '文章の添削と改善提案',
          systemPrompt: 'あなたは文章校正のエキスパートです。文章の誤字脱字、文法ミス、表現の改善を指摘し、より良い文章を提案してください。',
          icon: '✏️',
          color: '#F59E0B',
        ),
        Project(
          name: '翻訳',
          description: '日英翻訳アシスタント',
          systemPrompt: 'あなたは翻訳の専門家です。日本語と英語の翻訳を正確かつ自然に行います。文脈やニュアンスを考慮した翻訳を心がけてください。',
          icon: '🌐',
          color: '#3B82F6',
        ),
        Project(
          name: '要約',
          description: '長文の要約作成',
          systemPrompt: 'あなたは要約の専門家です。与えられたテキストを簡潔に要約し、重要なポイントを箇条書きで整理してください。',
          icon: '📝',
          color: '#8B5CF6',
        ),
        Project(
          name: 'ブレインストーミング',
          description: 'アイデア出しのパートナー',
          systemPrompt: 'あなたはクリエイティブなブレインストーミングパートナーです。ユーザーのアイデアを広げ、新しい視点や発想を提案してください。批判せず、まずはアイデアを出し尽くすことを優先します。',
          icon: '💡',
          color: '#EC4899',
        ),
      ];
}
