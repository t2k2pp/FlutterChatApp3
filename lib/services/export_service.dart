import '../models/conversation.dart';
import '../models/message.dart';

class ExportService {
  /// 会話をMarkdown形式でエクスポート
  static String exportToMarkdown(Conversation conversation) {
    final buffer = StringBuffer();
    
    // ヘッダー
    buffer.writeln('# ${conversation.title}');
    buffer.writeln();
    buffer.writeln('> 作成日: ${_formatDateTime(conversation.createdAt)}');
    buffer.writeln('> 更新日: ${_formatDateTime(conversation.updatedAt)}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    // メッセージ
    for (final message in conversation.messages) {
      final roleLabel = message.role == MessageRole.user ? '👤 **ユーザー**' : '🤖 **AI**';
      final timestamp = _formatTime(message.timestamp);
      
      buffer.writeln('## $roleLabel');
      buffer.writeln('*$timestamp*');
      buffer.writeln();
      buffer.writeln(message.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// 複数の会話をまとめてエクスポート
  static String exportMultipleToMarkdown(List<Conversation> conversations) {
    final buffer = StringBuffer();
    
    buffer.writeln('# チャット履歴');
    buffer.writeln();
    buffer.writeln('> エクスポート日時: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('> 会話数: ${conversations.length}');
    buffer.writeln();
    
    for (var i = 0; i < conversations.length; i++) {
      final conversation = conversations[i];
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('# ${i + 1}. ${conversation.title}');
      buffer.writeln();
      buffer.writeln('> 更新日: ${_formatDateTime(conversation.updatedAt)}');
      buffer.writeln('> メッセージ数: ${conversation.messages.length}');
      buffer.writeln();
      
      for (final message in conversation.messages) {
        final roleLabel = message.role == MessageRole.user ? '👤 ユーザー' : '🤖 AI';
        buffer.writeln('### $roleLabel');
        buffer.writeln();
        buffer.writeln(message.content);
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
