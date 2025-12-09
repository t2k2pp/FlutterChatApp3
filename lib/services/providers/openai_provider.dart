import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// OpenAI (ChatGPT) 用プロバイダー
class OpenAIProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;
  final http.Client _client;

  OpenAIProvider({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<bool> testConnection() async {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      return false;
    }
    try {
      final response = await _client.get(
        Uri.parse('${config.baseUrl}/models'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
        },
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    if (config.apiKey == null) {
      throw Exception('OpenAI API key is required');
    }

    final response = await _client.post(
      Uri.parse('${config.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.model ?? 'gpt-4o',
        'messages': messages.map(_toOpenAIFormat).toList(),
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    if (config.apiKey == null) {
      throw Exception('OpenAI API key is required');
    }

    final request = http.Request(
      'POST',
      Uri.parse('${config.baseUrl}/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    });
    request.body = jsonEncode({
      'model': config.model ?? 'gpt-4o',
      'messages': messages.map(_toOpenAIFormat).toList(),
      'stream': true,
    });

    final response = await _client.send(request);
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ') && !line.contains('[DONE]')) {
          try {
            final data = jsonDecode(line.substring(6));
            final content = data['choices']?[0]?['delta']?['content'];
            if (content != null) {
              yield content;
            }
          } catch (e) {
            // パースエラーは無視
          }
        }
      }
    }
  }

  /// OpenAI APIフォーマットに変換
  Map<String, dynamic> _toOpenAIFormat(Message msg) {
    String role;
    switch (msg.role) {
      case MessageRole.system:
        role = 'system';
        break;
      case MessageRole.assistant:
      case MessageRole.watson:
        role = 'assistant';
        break;
      case MessageRole.user:
      default:
        role = 'user';
    }
    return {
      'role': role,
      'content': msg.content,
    };
  }

  @override
  void dispose() {
    _client.close();
  }
}
