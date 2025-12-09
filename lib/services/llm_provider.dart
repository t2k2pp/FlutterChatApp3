import '../models/message.dart';

/// LLMプロバイダーの種類
enum LlmProviderType {
  llamaCpp,      // ローカルLlama.cpp
  claude,        // Anthropic Claude
  openai,        // OpenAI ChatGPT
  gemini,        // Google Gemini
  azureOpenai,   // Azure OpenAI Service
}

/// LLMプロバイダーの設定
class LlmProviderConfig {
  final LlmProviderType type;
  final String name;
  final String baseUrl;
  final String? apiKey;
  final String? model;
  final String? deploymentName;  // Azure用デプロイメント名
  final String? apiVersion;      // Azure用APIバージョン
  final Map<String, dynamic>? options;

  const LlmProviderConfig({
    required this.type,
    required this.name,
    required this.baseUrl,
    this.apiKey,
    this.model,
    this.deploymentName,
    this.apiVersion,
    this.options,
  });

  LlmProviderConfig copyWith({
    LlmProviderType? type,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? deploymentName,
    String? apiVersion,
    Map<String, dynamic>? options,
  }) {
    return LlmProviderConfig(
      type: type ?? this.type,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      deploymentName: deploymentName ?? this.deploymentName,
      apiVersion: apiVersion ?? this.apiVersion,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'deploymentName': deploymentName,
    'apiVersion': apiVersion,
    'options': options,
  };

  factory LlmProviderConfig.fromJson(Map<String, dynamic> json) {
    return LlmProviderConfig(
      type: LlmProviderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LlmProviderType.llamaCpp,
      ),
      name: json['name'] ?? '',
      baseUrl: json['baseUrl'] ?? '',
      apiKey: json['apiKey'],
      model: json['model'],
      deploymentName: json['deploymentName'],
      apiVersion: json['apiVersion'],
      options: json['options'] as Map<String, dynamic>?,
    );
  }

  /// デフォルト設定
  static LlmProviderConfig get defaultLlamaCpp => const LlmProviderConfig(
    type: LlmProviderType.llamaCpp,
    name: 'Llama.cpp (ローカル)',
    baseUrl: 'http://192.168.1.24:11437/v1',
  );

  static LlmProviderConfig get defaultClaude => const LlmProviderConfig(
    type: LlmProviderType.claude,
    name: 'Claude',
    baseUrl: 'https://api.anthropic.com/v1',
    model: 'claude-3-5-sonnet-20241022',
  );

  static LlmProviderConfig get defaultOpenAI => const LlmProviderConfig(
    type: LlmProviderType.openai,
    name: 'ChatGPT',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o',
  );

  static LlmProviderConfig get defaultGemini => const LlmProviderConfig(
    type: LlmProviderType.gemini,
    name: 'Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-1.5-flash',
  );

  static LlmProviderConfig get defaultAzureOpenAI => const LlmProviderConfig(
    type: LlmProviderType.azureOpenai,
    name: 'Azure OpenAI',
    baseUrl: 'https://your-resource.openai.azure.com',
    deploymentName: 'gpt-4o',
    apiVersion: '2024-02-15-preview',
  );
}

/// LLMプロバイダーのインターフェース
abstract class LlmProvider {
  LlmProviderConfig get config;

  /// 接続テスト
  Future<bool> testConnection();

  /// チャット補完（同期）
  Future<String> getChatCompletion(List<Message> messages);

  /// チャット補完（ストリーミング）
  Stream<String> streamChatCompletion(List<Message> messages);

  /// リソース解放
  void dispose();
}
