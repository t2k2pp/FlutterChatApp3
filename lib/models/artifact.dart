import 'package:uuid/uuid.dart';

enum ArtifactType {
  html,
  javascript,
  css,
  combined,  // HTML+JS+CSS統合
  markdown,
  mermaid,
  code,
}

class Artifact {
  final String id;
  final String title;
  final ArtifactType type;
  final String content;
  final Map<String, String>? files;  // 複数ファイル対応: {'index.html': '...', 'style.css': '...'}
  final DateTime createdAt;
  final DateTime updatedAt;

  Artifact({
    String? id,
    required this.title,
    required this.type,
    required this.content,
    this.files,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Artifact copyWith({
    String? id,
    String? title,
    ArtifactType? type,
    String? content,
    Map<String, String>? files,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Artifact(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'content': content,
      'files': files,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'],
      title: json['title'],
      type: ArtifactType.values.firstWhere((e) => e.name == json['type']),
      content: json['content'],
      files: json['files'] != null 
          ? Map<String, String>.from(json['files']) 
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// HTMLプレビュー用の完全なHTMLを生成
  String toPreviewHtml() {
    if (type == ArtifactType.html || type == ArtifactType.combined) {
      if (files != null && files!.isNotEmpty) {
        // 複数ファイルの場合、結合
        final html = files!['index.html'] ?? files!['main.html'] ?? content;
        final css = files!['style.css'] ?? files!['styles.css'] ?? '';
        final js = files!['script.js'] ?? files!['main.js'] ?? '';
        
        return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    $css
  </style>
</head>
<body>
  $html
  <script>
    $js
  </script>
</body>
</html>
''';
      }
      return content;
    }
    
    // その他の場合はそのまま返す
    return content;
  }
}

/// AIの応答からアーティファクトを抽出するユーティリティ
class ArtifactParser {
  static final RegExp _artifactPattern = RegExp(
    r'```(?:artifact|html|javascript|css|mermaid)(?:\s+title="([^"]*)")?\n([\s\S]*?)```',
    multiLine: true,
  );

  static final RegExp _htmlPattern = RegExp(
    r'```html\n([\s\S]*?)```',
    multiLine: true,
  );

  static final RegExp _cssPattern = RegExp(
    r'```css\n([\s\S]*?)```',
    multiLine: true,
  );

  static final RegExp _jsPattern = RegExp(
    r'```(?:javascript|js)\n([\s\S]*?)```',
    multiLine: true,
  );

  /// メッセージからアーティファクトを抽出
  static List<Artifact> extractArtifacts(String message) {
    final artifacts = <Artifact>[];
    
    // 複合アーティファクト（HTML+CSS+JS）を検出
    final htmlMatches = _htmlPattern.allMatches(message).toList();
    final cssMatches = _cssPattern.allMatches(message).toList();
    final jsMatches = _jsPattern.allMatches(message).toList();

    if (htmlMatches.isNotEmpty) {
      final files = <String, String>{};
      
      for (var i = 0; i < htmlMatches.length; i++) {
        files['index${i > 0 ? i : ''}.html'] = htmlMatches[i].group(1) ?? '';
      }
      
      for (var i = 0; i < cssMatches.length; i++) {
        files['style${i > 0 ? i : ''}.css'] = cssMatches[i].group(1) ?? '';
      }
      
      for (var i = 0; i < jsMatches.length; i++) {
        files['script${i > 0 ? i : ''}.js'] = jsMatches[i].group(1) ?? '';
      }

      if (files.isNotEmpty) {
        artifacts.add(Artifact(
          title: 'コードプレビュー',
          type: cssMatches.isNotEmpty || jsMatches.isNotEmpty 
              ? ArtifactType.combined 
              : ArtifactType.html,
          content: files['index.html'] ?? files.values.first,
          files: files,
        ));
      }
    }

    return artifacts;
  }

  /// メッセージにアーティファクトが含まれているか確認
  static bool hasArtifact(String message) {
    return _htmlPattern.hasMatch(message) ||
           _artifactPattern.hasMatch(message);
  }
}
