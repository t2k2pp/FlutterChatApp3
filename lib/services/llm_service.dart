import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class LlmService {
  final String baseUrl;
  final String model;
  final http.Client _client;

  LlmService({
    this.baseUrl = 'http://192.168.1.24:11437/v1',
    this.model = 'default',
  }) : _client = http.Client();

  /// ストリーミングでチャット補完を取得
  Stream<String> streamChatCompletion(List<Message> messages) async* {
    final url = Uri.parse('$baseUrl/chat/completions');
    
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toApiFormat()).toList(),
      'stream': true,
      'temperature': 0.7,
    });

    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = body;

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // SSEフォーマットをパース
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              return;
            }
            if (data.isNotEmpty) {
              try {
                final json = jsonDecode(data);
                final delta = json['choices']?[0]?['delta'];
                if (delta != null && delta['content'] != null) {
                  yield delta['content'] as String;
                }
              } catch (e) {
                // JSONパースエラーは無視
              }
            }
          }
        }
      }
    } catch (e) {
      throw Exception('通信エラー: $e');
    }
  }

  /// 非ストリーミングでチャット補完を取得
  Future<String> getChatCompletion(List<Message> messages) async {
    final url = Uri.parse('$baseUrl/chat/completions');
    
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toApiFormat()).toList(),
      'stream': false,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      return json['choices'][0]['message']['content'] as String;
    } catch (e) {
      throw Exception('通信エラー: $e');
    }
  }

  /// サーバーへの接続確認
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/models');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
