import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// Google Gemini用プロバイダー
class GeminiProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;
  final http.Client _client;

  GeminiProvider({
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
        Uri.parse('${config.baseUrl}/models?key=${config.apiKey}'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    if (config.apiKey == null) {
      throw Exception('Gemini API key is required');
    }

    final model = config.model ?? 'gemini-1.5-flash';
    final (systemInstruction, contents) = _convertMessages(messages);

    final response = await _client.post(
      Uri.parse('${config.baseUrl}/models/$model:generateContent?key=${config.apiKey}'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (systemInstruction != null) 'systemInstruction': systemInstruction,
        'contents': contents,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts[0]['text'] ?? '';
      }
    }
    return '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    if (config.apiKey == null) {
      throw Exception('Gemini API key is required');
    }

    final model = config.model ?? 'gemini-1.5-flash';
    final (systemInstruction, contents) = _convertMessages(messages);

    final request = http.Request(
      'POST',
      Uri.parse('${config.baseUrl}/models/$model:streamGenerateContent?key=${config.apiKey}&alt=sse'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      if (systemInstruction != null) 'systemInstruction': systemInstruction,
      'contents': contents,
    });

    final response = await _client.send(request);
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            final data = jsonDecode(line.substring(6));
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'];
                if (text != null) {
                  yield text;
                }
              }
            }
          } catch (e) {
            // パースエラーは無視
          }
        }
      }
    }
  }

  /// メッセージをGemini APIフォーマットに変換
  (Map<String, dynamic>?, List<Map<String, dynamic>>) _convertMessages(List<Message> messages) {
    Map<String, dynamic>? systemInstruction;
    final contents = <Map<String, dynamic>>[];
    
    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        systemInstruction = {
          'parts': [{'text': msg.content}]
        };
      } else {
        final role = msg.role == MessageRole.assistant ? 'model' : 'user';
        contents.add({
          'role': role,
          'parts': [{'text': msg.content}],
        });
      }
    }
    
    return (systemInstruction, contents);
  }

  @override
  void dispose() {
    _client.close();
  }
}
