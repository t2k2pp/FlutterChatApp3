import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: _buildMessageContent(context, isUser),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: isUser ? AppTheme.userMessageGradient : AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isUser ? AppTheme.primaryColor : AppTheme.accentColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.auto_awesome,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isUser) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        gradient: isUser ? AppTheme.userMessageGradient : null,
        color: isUser ? null : AppTheme.assistantMessageBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isUser
            ? null
            : Border.all(
                color: AppTheme.darkBorder,
                width: 1,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              )
            else
              _buildMarkdownContent(),
            if (message.isStreaming) ...[
              const SizedBox(height: 8),
              _buildTypingIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownContent() {
    return MarkdownBody(
      data: message.content.isEmpty ? '...' : message.content,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        code: TextStyle(
          backgroundColor: AppTheme.darkCard.withOpacity(0.5),
          color: AppTheme.accentColor,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryColor,
              width: 3,
            ),
          ),
        ),
        h1: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h3: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        listBullet: const TextStyle(color: AppTheme.textSecondary),
        a: const TextStyle(
          color: AppTheme.accentColor,
          decoration: TextDecoration.underline,
        ),
      ),
      selectable: false,
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: 4),
        _buildDot(1),
        const SizedBox(width: 4),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
