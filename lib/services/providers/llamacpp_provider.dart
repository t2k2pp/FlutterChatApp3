import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// Llama.cpp用プロバイダー
class LlamaCppProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;
  final http.Client _client;

  LlamaCppProvider({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('${config.baseUrl}/models'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    final response = await _client.post(
      Uri.parse('${config.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'messages': messages.map((m) => m.toApiFormat()).toList(),
        'stream': false,
        if (config.model != null) 'model': config.model,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${config.baseUrl}/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode({
      'messages': messages.map((m) => m.toApiFormat()).toList(),
      'stream': true,
      if (config.model != null) 'model': config.model,
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

  @override
  void dispose() {
    _client.close();
  }
}
