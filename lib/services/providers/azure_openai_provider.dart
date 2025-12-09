import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// Azure OpenAI Service用プロバイダー
class AzureOpenAIProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;

  AzureOpenAIProvider({required this.config});

  /// Azure OpenAI API URLを構築
  String get _chatEndpoint {
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/$'), '');
    final deployment = config.deploymentName ?? 'gpt-4o';
    final apiVersion = config.apiVersion ?? '2024-02-15-preview';
    return '$baseUrl/openai/deployments/$deployment/chat/completions?api-version=$apiVersion';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'api-key': config.apiKey ?? '',
  };

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(_chatEndpoint),
        headers: _headers,
        body: jsonEncode({
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    final apiMessages = _convertMessages(messages);
    
    final response = await http.post(
      Uri.parse(_chatEndpoint),
      headers: _headers,
      body: jsonEncode({
        'messages': apiMessages,
        'max_tokens': 4096,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Azure OpenAI API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices']?[0]?['message']?['content'] ?? '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    final apiMessages = _convertMessages(messages);
    
    final request = http.Request('POST', Uri.parse(_chatEndpoint));
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'messages': apiMessages,
      'max_tokens': 4096,
      'temperature': 0.7,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('Azure OpenAI API error: ${streamedResponse.statusCode} - $body');
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line == 'data: [DONE]') continue;
          
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              final data = jsonDecode(jsonStr);
              final delta = data['choices']?[0]?['delta'];
              final content = delta?['content'];
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            } catch (e) {
              // JSON parse error, skip
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _convertMessages(List<Message> messages) {
    return messages.map((msg) {
      String role;
      switch (msg.role) {
        case MessageRole.user:
          role = 'user';
          break;
        case MessageRole.assistant:
          role = 'assistant';
          break;
        case MessageRole.system:
          role = 'system';
          break;
        default:
          role = 'user';
      }
      return {
        'role': role,
        'content': msg.content,
      };
    }).toList();
  }

  @override
  void dispose() {}
}
