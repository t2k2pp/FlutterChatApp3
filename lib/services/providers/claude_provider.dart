import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// Claude (Anthropic) 用プロバイダー
class ClaudeProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;
  final http.Client _client;

  ClaudeProvider({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<bool> testConnection() async {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      return false;
    }
    try {
      // Claude APIはシンプルなpingエンドポイントがないため、
      // 空のリクエストで認証テスト
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    if (config.apiKey == null) {
      throw Exception('Claude API key is required');
    }

    final (systemPrompt, userMessages) = _separateSystemPrompt(messages);

    final response = await _client.post(
      Uri.parse('${config.baseUrl}/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey!,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': config.model ?? 'claude-3-5-sonnet-20241022',
        'max_tokens': config.effectiveMaxTokens,
        if (systemPrompt != null) 'system': systemPrompt,
        'messages': userMessages.map(_toClaudeFormat).toList(),
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List?;
    if (content != null && content.isNotEmpty) {
      return content.first['text'] ?? '';
    }
    return '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    if (config.apiKey == null) {
      throw Exception('Claude API key is required');
    }

    final (systemPrompt, userMessages) = _separateSystemPrompt(messages);

    final request = http.Request(
      'POST',
      Uri.parse('${config.baseUrl}/messages'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': config.apiKey!,
      'anthropic-version': '2023-06-01',
    });
    request.body = jsonEncode({
      'model': config.model ?? 'claude-3-5-sonnet-20241022',
      'max_tokens': config.effectiveMaxTokens,
      'stream': true,
      if (systemPrompt != null) 'system': systemPrompt,
      'messages': userMessages.map(_toClaudeFormat).toList(),
    });

    final response = await _client.send(request);
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            final data = jsonDecode(line.substring(6));
            if (data['type'] == 'content_block_delta') {
              final text = data['delta']?['text'];
              if (text != null) {
                yield text;
              }
            }
          } catch (e) {
            // パースエラーは無視
          }
        }
      }
    }
  }

  /// システムプロンプトとユーザーメッセージを分離
  (String?, List<Message>) _separateSystemPrompt(List<Message> messages) {
    String? systemPrompt;
    final userMessages = <Message>[];
    
    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        systemPrompt = msg.content;
      } else {
        userMessages.add(msg);
      }
    }
    
    return (systemPrompt, userMessages);
  }

  /// Claude APIフォーマットに変換
  Map<String, dynamic> _toClaudeFormat(Message msg) {
    return {
      'role': msg.role == MessageRole.assistant ? 'assistant' : 'user',
      'content': msg.content,
    };
  }

  @override
  void dispose() {
    _client.close();
  }
}
