import 'package:uuid/uuid.dart';

/// Watsonの割り込みレベル
enum WatsonInterruptLevel {
  off,        // 完全オフ
  passive,    // 消極的（明らかな誤りのみ）
  normal,     // 普通
  proactive,  // 積極的（おせっかい）
}

/// Watson設定
class WatsonConfig {
  final bool enabled;
  final WatsonInterruptLevel interruptLevel;
  final String? customSystemPrompt;
  final int? providerIndex;  // 使用するLLMプロバイダーのインデックス
  final List<String> activationWords;  // 起動ワード

  const WatsonConfig({
    this.enabled = true,
    this.interruptLevel = WatsonInterruptLevel.normal,
    this.customSystemPrompt,
    this.providerIndex,
    this.activationWords = const ['watson', 'ワトソン', 'わとそん', 'ねえワトソン'],
  });

  WatsonConfig copyWith({
    bool? enabled,
    WatsonInterruptLevel? interruptLevel,
    String? customSystemPrompt,
    int? providerIndex,
    List<String>? activationWords,
  }) {
    return WatsonConfig(
      enabled: enabled ?? this.enabled,
      interruptLevel: interruptLevel ?? this.interruptLevel,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
      providerIndex: providerIndex ?? this.providerIndex,
      activationWords: activationWords ?? this.activationWords,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'interruptLevel': interruptLevel.name,
    'customSystemPrompt': customSystemPrompt,
    'providerIndex': providerIndex,
    'activationWords': activationWords,
  };

  factory WatsonConfig.fromJson(Map<String, dynamic> json) {
    return WatsonConfig(
      enabled: json['enabled'] ?? true,
      interruptLevel: WatsonInterruptLevel.values.firstWhere(
        (e) => e.name == json['interruptLevel'],
        orElse: () => WatsonInterruptLevel.normal,
      ),
      customSystemPrompt: json['customSystemPrompt'],
      providerIndex: json['providerIndex'],
      activationWords: (json['activationWords'] as List?)
          ?.map((e) => e as String)
          .toList() ?? const ['watson', 'ワトソン', 'わとそん', 'ねえワトソン'],
    );
  }

  /// 介入レベルの日本語名
  String get interruptLevelName {
    switch (interruptLevel) {
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

  /// デフォルトのシステムプロンプト
  String get effectiveSystemPrompt {
    if (customSystemPrompt != null && customSystemPrompt!.isNotEmpty) {
      return customSystemPrompt!;
    }
    return _getDefaultPromptForLevel(interruptLevel);
  }

  static String _getDefaultPromptForLevel(WatsonInterruptLevel level) {
    switch (level) {
      case WatsonInterruptLevel.off:
        return '';
      case WatsonInterruptLevel.passive:
        return '''あなたはWatson（ワトソン）という名前のAIアシスタントの補佐役です。
メインのAIアシスタントの回答を確認し、明らかな誤りや危険な情報がある場合のみ指摘してください。
軽微な問題や主観的な意見の違いは無視してください。
指摘する際は簡潔に、「確認した方が良い点があります」という形で伝えてください。
問題がない場合は何も言わないでください。''';
      case WatsonInterruptLevel.normal:
        return '''あなたはWatson（ワトソン）という名前のAIアシスタントの補佐役です。
メインのAIアシスタントの回答を確認し、以下の問題がある場合に指摘してください：
- 事実誤認や不正確な情報
- 論理的な矛盾
- 重要な情報の欠落
- 誤解を招く可能性のある表現

指摘は建設的に行い、代替案や補足情報も提供してください。
問題がない場合は「特に問題は見つかりませんでした」と簡潔に回答してください。''';
      case WatsonInterruptLevel.proactive:
        return '''あなたはWatson（ワトソン）という名前のAIアシスタントの補佐役です。
メインのAIアシスタントの回答を詳細に分析し、以下の観点から積極的にフィードバックを提供してください：
- 事実の正確性
- 論理の一貫性
- 説明の完全性
- より良い代替案の提案
- 潜在的なリスクや注意点
- 追加で考慮すべき視点

常に建設的で有益なフィードバックを心がけ、ユーザーの理解を深める補足情報を積極的に提供してください。''';
    }
  }

  /// メッセージに起動ワードが含まれているか
  bool containsActivationWord(String message) {
    if (!enabled) return false;
    
    final lowerMessage = message.toLowerCase();
    for (final word in activationWords) {
      if (lowerMessage.contains(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

/// Watsonの介入結果
class WatsonInterjection {
  final String id;
  final String content;
  final bool isHallucinationWarning;
  final DateTime timestamp;
  final bool sharedWithMainAI;
  final bool isManualCall;  // 起動ワードで呼び出されたか

  WatsonInterjection({
    String? id,
    required this.content,
    this.isHallucinationWarning = false,
    DateTime? timestamp,
    this.sharedWithMainAI = false,
    this.isManualCall = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  WatsonInterjection copyWith({
    String? id,
    String? content,
    bool? isHallucinationWarning,
    DateTime? timestamp,
    bool? sharedWithMainAI,
    bool? isManualCall,
  }) {
    return WatsonInterjection(
      id: id ?? this.id,
      content: content ?? this.content,
      isHallucinationWarning: isHallucinationWarning ?? this.isHallucinationWarning,
      timestamp: timestamp ?? this.timestamp,
      sharedWithMainAI: sharedWithMainAI ?? this.sharedWithMainAI,
      isManualCall: isManualCall ?? this.isManualCall,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isHallucinationWarning': isHallucinationWarning,
    'timestamp': timestamp.toIso8601String(),
    'sharedWithMainAI': sharedWithMainAI,
    'isManualCall': isManualCall,
  };

  factory WatsonInterjection.fromJson(Map<String, dynamic> json) {
    return WatsonInterjection(
      id: json['id'],
      content: json['content'],
      isHallucinationWarning: json['isHallucinationWarning'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      sharedWithMainAI: json['sharedWithMainAI'] ?? false,
      isManualCall: json['isManualCall'] ?? false,
    );
  }
}
