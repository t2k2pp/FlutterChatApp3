import 'dart:convert';
import 'package:uuid/uuid.dart';

/// スキルファイルの種類
enum SkillFileType {
  instruction,  // SKILL.md - メイン指示
  prompt,       // プロンプトテンプレート
  script,       // 補助スクリプト
  reference,    // 参照資料
  example,      // 例示
}

/// スキル内のファイル
class SkillFile {
  final String name;
  final SkillFileType type;
  final String content;
  final String? description;

  const SkillFile({
    required this.name,
    required this.type,
    required this.content,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'content': content,
    'description': description,
  };

  factory SkillFile.fromJson(Map<String, dynamic> json) {
    return SkillFile(
      name: json['name'] ?? '',
      type: SkillFileType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SkillFileType.instruction,
      ),
      content: json['content'] ?? '',
      description: json['description'],
    );
  }
}

/// スキルのトリガー条件
class SkillTrigger {
  final List<String> keywords;      // キーワードマッチ
  final List<String> patterns;      // 正規表現パターン
  final bool manualOnly;            // 手動起動のみ

  const SkillTrigger({
    this.keywords = const [],
    this.patterns = const [],
    this.manualOnly = false,
  });

  Map<String, dynamic> toJson() => {
    'keywords': keywords,
    'patterns': patterns,
    'manualOnly': manualOnly,
  };

  factory SkillTrigger.fromJson(Map<String, dynamic> json) {
    return SkillTrigger(
      keywords: List<String>.from(json['keywords'] ?? []),
      patterns: List<String>.from(json['patterns'] ?? []),
      manualOnly: json['manualOnly'] ?? false,
    );
  }

  /// メッセージがトリガー条件にマッチするか
  bool matches(String message) {
    if (manualOnly) return false;
    
    final lowerMsg = message.toLowerCase();
    
    // キーワードマッチ
    for (final keyword in keywords) {
      if (lowerMsg.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    
    // パターンマッチ
    for (final pattern in patterns) {
      try {
        if (RegExp(pattern, caseSensitive: false).hasMatch(message)) {
          return true;
        }
      } catch (e) {
        // 無効な正規表現は無視
      }
    }
    
    return false;
  }
}

/// スキル（Claude Skills準拠）
class Skill {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final List<SkillFile> files;
  final SkillTrigger trigger;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  Skill({
    String? id,
    required this.name,
    required this.description,
    this.icon = '🛠️',
    this.color = '#6366f1',
    required this.files,
    SkillTrigger? trigger,
    this.isBuiltIn = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        trigger = trigger ?? const SkillTrigger(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// メイン指示ファイル（SKILL.md）を取得
  SkillFile? get mainInstruction {
    return files.where((f) => f.type == SkillFileType.instruction).firstOrNull;
  }

  /// スキルをシステムプロンプトコンテキストに変換
  String toContext() {
    final buffer = StringBuffer();
    buffer.writeln('【スキル: $name】');
    buffer.writeln(description);
    buffer.writeln();

    // メイン指示
    if (mainInstruction != null) {
      buffer.writeln('## 指示');
      buffer.writeln(mainInstruction!.content);
      buffer.writeln();
    }

    // 参照資料
    final references = files.where((f) => f.type == SkillFileType.reference);
    if (references.isNotEmpty) {
      buffer.writeln('## 参照資料');
      for (final ref in references) {
        buffer.writeln('### ${ref.name}');
        buffer.writeln(ref.content);
        buffer.writeln();
      }
    }

    // 例示
    final examples = files.where((f) => f.type == SkillFileType.example);
    if (examples.isNotEmpty) {
      buffer.writeln('## 例');
      for (final ex in examples) {
        buffer.writeln('### ${ex.name}');
        buffer.writeln(ex.content);
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  Skill copyWith({
    String? name,
    String? description,
    String? icon,
    String? color,
    List<SkillFile>? files,
    SkillTrigger? trigger,
    bool? isBuiltIn,
  }) {
    return Skill(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      files: files ?? this.files,
      trigger: trigger ?? this.trigger,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color,
    'files': files.map((f) => f.toJson()).toList(),
    'trigger': trigger.toJson(),
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🛠️',
      color: json['color'] ?? '#6366f1',
      files: (json['files'] as List?)
          ?.map((f) => SkillFile.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
      trigger: json['trigger'] != null 
          ? SkillTrigger.fromJson(json['trigger'] as Map<String, dynamic>)
          : null,
      isBuiltIn: json['isBuiltIn'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }
}

/// ビルトインスキル
class BuiltInSkills {
  static Skill get codeReview => Skill(
    id: 'builtin-code-review',
    name: 'コードレビュー',
    description: 'コードの品質、バグ、改善点を分析します',
    icon: '🔍',
    color: '#10b981',
    isBuiltIn: true,
    trigger: const SkillTrigger(
      keywords: ['レビュー', 'コードレビュー', 'review'],
      patterns: [r'.*コード.*確認.*', r'.*バグ.*探.*'],
    ),
    files: [
      const SkillFile(
        name: 'SKILL.md',
        type: SkillFileType.instruction,
        content: '''# コードレビュースキル

以下の観点でコードをレビューしてください：

## チェック項目
1. **バグ・エラー**: 潜在的なバグ、ランタイムエラー、エッジケース
2. **セキュリティ**: SQLインジェクション、XSS、認証・認可の問題
3. **パフォーマンス**: N+1問題、不要なループ、メモリリーク
4. **可読性**: 命名規則、コメント、コード構造
5. **ベストプラクティス**: 言語固有のイディオム、設計パターン

## 出力形式
- 重要度（🔴高/🟡中/🟢低）でグループ化
- 問題のある行番号を明記
- 修正例を提示''',
      ),
      const SkillFile(
        name: 'severity_guide.md',
        type: SkillFileType.reference,
        content: '''## 重要度ガイド
- 🔴 高: セキュリティ問題、データ損失、クラッシュ
- 🟡 中: パフォーマンス問題、可読性低下
- 🟢 低: スタイル、ベストプラクティス''',
      ),
    ],
  );

  static Skill get documentWriter => Skill(
    id: 'builtin-document-writer',
    name: 'ドキュメント作成',
    description: '技術文書、README、APIドキュメントを作成します',
    icon: '📝',
    color: '#3b82f6',
    isBuiltIn: true,
    trigger: const SkillTrigger(
      keywords: ['ドキュメント', 'README', '説明書', 'マニュアル'],
    ),
    files: [
      const SkillFile(
        name: 'SKILL.md',
        type: SkillFileType.instruction,
        content: '''# ドキュメント作成スキル

技術文書を作成する際のガイドラインです。

## 原則
1. **明確性**: 専門用語は定義する、曖昧な表現を避ける
2. **構造化**: 見出し、リスト、コードブロックを活用
3. **実用性**: コード例、使用例を含める
4. **メンテナンス**: 更新日、バージョンを明記

## ドキュメント種類
- README: プロジェクト概要、インストール、クイックスタート
- API: エンドポイント、パラメータ、レスポンス例
- ガイド: ステップバイステップの手順''',
      ),
    ],
  );

  static Skill get translator => Skill(
    id: 'builtin-translator',
    name: '翻訳',
    description: '日本語⇔英語の翻訳を行います',
    icon: '🌐',
    color: '#8b5cf6',
    isBuiltIn: true,
    trigger: const SkillTrigger(
      keywords: ['翻訳', 'translate', '英訳', '和訳'],
    ),
    files: [
      const SkillFile(
        name: 'SKILL.md',
        type: SkillFileType.instruction,
        content: '''# 翻訳スキル

## ルール
1. 原文の意図とニュアンスを保持
2. 技術用語は一般的な訳語を使用（カタカナ可）
3. 文化的コンテキストを考慮
4. コードコメントは原文言語を維持するか確認

## 出力形式
```
【原文】
（元のテキスト）

【翻訳】
（翻訳結果）

【注釈】
（必要に応じて訳注）
```''',
      ),
    ],
  );

  static Skill get summarizer => Skill(
    id: 'builtin-summarizer',
    name: '要約',
    description: 'テキストを簡潔に要約します',
    icon: '📋',
    color: '#f59e0b',
    isBuiltIn: true,
    trigger: const SkillTrigger(
      keywords: ['要約', 'まとめ', 'サマリー', 'summary'],
    ),
    files: [
      const SkillFile(
        name: 'SKILL.md',
        type: SkillFileType.instruction,
        content: '''# 要約スキル

## 要約のレベル
1. **一言要約**: 1文で核心を表現
2. **概要**: 3〜5文で主要ポイントをカバー
3. **詳細要約**: 箇条書きで構造化

## 原則
- 重要な情報を優先
- 客観的な表現
- 原文にない解釈を加えない''',
      ),
    ],
  );

  static Skill get debugHelper => Skill(
    id: 'builtin-debug-helper',
    name: 'デバッグ支援',
    description: 'エラーの原因特定と解決策を提案します',
    icon: '🐛',
    color: '#ef4444',
    isBuiltIn: true,
    trigger: const SkillTrigger(
      keywords: ['エラー', 'バグ', 'debug', 'error', '動かない', '落ちる'],
      patterns: [r'.*Exception.*', r'.*Error.*'],
    ),
    files: [
      const SkillFile(
        name: 'SKILL.md',
        type: SkillFileType.instruction,
        content: '''# デバッグ支援スキル

## 分析プロセス
1. **エラーメッセージの解析**: スタックトレース、エラーコード
2. **原因の特定**: 根本原因を推測
3. **解決策の提案**: 複数のアプローチを優先度順に

## 出力形式
```
## エラー概要
（何が起きているか）

## 原因
（なぜ起きているか）

## 解決策
1. （最も可能性の高い解決策）
2. （代替案）

## 予防策
（今後同様の問題を避ける方法）
```''',
      ),
    ],
  );

  static List<Skill> get all => [
    codeReview,
    documentWriter,
    translator,
    summarizer,
    debugHelper,
  ];
}
