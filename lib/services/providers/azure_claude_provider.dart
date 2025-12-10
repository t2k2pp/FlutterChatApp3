import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../llm_provider.dart';

/// Azure AI Foundry Claude用プロバイダー
class AzureClaudeProvider implements LlmProvider {
  @override
  final LlmProviderConfig config;

  AzureClaudeProvider({required this.config});

  /// Azure AI Foundry Claude API URLを構築
  String get _messagesEndpoint {
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$baseUrl/anthropic/v1/messages';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': config.apiKey ?? '',
    'anthropic-version': '2023-06-01',
  };

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(_messagesEndpoint),
        headers: _headers,
        body: jsonEncode({
          'model': config.model ?? 'claude-3-5-sonnet-20241022',
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getChatCompletion(List<Message> messages) async {
    final apiMessages = _convertMessages(messages);
    final systemPrompt = _extractSystemPrompt(messages);
    
    final body = <String, dynamic>{
      'model': config.model ?? 'claude-3-5-sonnet-20241022',
      'max_tokens': config.effectiveMaxTokens,
      'messages': apiMessages,
    };
    
    if (systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final response = await http.post(
      Uri.parse(_messagesEndpoint),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Azure Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final content = data['content'] as List?;
    if (content != null && content.isNotEmpty) {
      return content[0]['text'] ?? '';
    }
    return '';
  }

  @override
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    final apiMessages = _convertMessages(messages);
    final systemPrompt = _extractSystemPrompt(messages);
    
    final body = <String, dynamic>{
      'model': config.model ?? 'claude-3-5-sonnet-20241022',
      'max_tokens': config.effectiveMaxTokens,
      'messages': apiMessages,
      'stream': true,
    };
    
    if (systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final request = http.Request('POST', Uri.parse(_messagesEndpoint));
    request.headers.addAll(_headers);
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('Azure Claude API error: ${streamedResponse.statusCode} - $body');
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr == '[DONE]') continue;
            
            try {
              final data = jsonDecode(jsonStr);
              final type = data['type'];
              
              if (type == 'content_block_delta') {
                final delta = data['delta'];
                if (delta != null && delta['type'] == 'text_delta') {
                  final text = delta['text'];
                  if (text != null && text.isNotEmpty) {
                    yield text;
                  }
                }
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

  String _extractSystemPrompt(List<Message> messages) {
    final systemMessages = messages.where((m) => m.role == MessageRole.system);
    if (systemMessages.isEmpty) return '';
    return systemMessages.map((m) => m.content).join('\n\n');
  }

  List<Map<String, dynamic>> _convertMessages(List<Message> messages) {
    return messages
        .where((msg) => msg.role != MessageRole.system)
        .map((msg) {
      return {
        'role': msg.role == MessageRole.assistant ? 'assistant' : 'user',
        'content': msg.content,
      };
    }).toList();
  }

  @override
  void dispose() {}
}
