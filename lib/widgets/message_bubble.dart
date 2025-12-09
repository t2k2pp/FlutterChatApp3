import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/artifact.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';
import 'artifact_renderer.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    this.onCopy,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showActions = false;
  bool _copied = false;
  bool _showThinking = false;
  bool _showCode = false;
  List<Artifact> _artifacts = [];

  @override
  void initState() {
    super.initState();
    _parseArtifacts();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      _parseArtifacts();
    }
  }

  void _parseArtifacts() {
    _artifacts = ArtifactParser.extractArtifacts(widget.message.content);
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.message.content));
    setState(() => _copied = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('クリップボードにコピーしました'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final isWatson = widget.message.role == MessageRole.watson;

    return MouseRegion(
      onEnter: (_) => setState(() => _showActions = true),
      onExit: (_) => setState(() => _showActions = false),
      child: GestureDetector(
        onLongPress: () => setState(() => _showActions = !_showActions),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _buildAvatar(isUser, isWatson),
              if (!isUser) const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Thinkingブロック
                    if (widget.message.thinkingContent != null && 
                        widget.message.thinkingContent!.isNotEmpty)
                      _buildThinkingBlock(),
                    // メッセージコンテンツ
                    _buildMessageContent(context, isUser, isWatson),
                    // Artifact表示
                    if (_artifacts.isNotEmpty && !widget.message.isStreaming)
                      ..._artifacts.map((artifact) => ArtifactRenderer(
                        artifact: artifact,
                        showCode: _showCode,
                        onToggleView: () => setState(() => _showCode = !_showCode),
                      )),
                    // アクションバー
                    if (_showActions && !widget.message.isStreaming)
                      _buildActionBar(isUser),
                  ],
                ),
              ),
              if (isUser) const SizedBox(width: 12),
              if (isUser) _buildAvatar(isUser, isWatson),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          InkWell(
            onTap: () => setState(() => _showThinking = !_showThinking),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: _showThinking ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '思考過程',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showThinking ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ],
              ),
            ),
          ),
          // 内容
          if (_showThinking)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.message.thinkingContent!,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
            label: _copied ? 'コピー済み' : 'コピー',
            onTap: _copyToClipboard,
            isActive: _copied,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive 
                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isUser, bool isWatson) {
    final gradient = isUser 
        ? AppTheme.userMessageGradient 
        : isWatson 
            ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)])
            : AppTheme.accentGradient;
    final shadowColor = isUser 
        ? AppTheme.primaryColor 
        : isWatson 
            ? const Color(0xFFEC4899)
            : AppTheme.accentColor;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUser 
            ? Icons.person_rounded 
            : isWatson 
                ? Icons.science_rounded
                : Icons.auto_awesome,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isUser, bool isWatson) {
    final bgColor = isUser 
        ? null 
        : isWatson 
            ? const Color(0xFF2D1B3D)
            : AppTheme.assistantMessageBg;
    final gradient = isUser ? AppTheme.userMessageGradient : null;
    final borderColor = isWatson 
        ? const Color(0xFFEC4899).withValues(alpha: 0.3)
        : AppTheme.darkBorder;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isUser
            ? null
            : Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Watsonラベル
            if (isWatson) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.science_rounded,
                    size: 14,
                    color: const Color(0xFFF472B6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Watson',
                    style: TextStyle(
                      color: const Color(0xFFF472B6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.message.isHallucinationWarning) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⚠️ 確認推奨',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
            // メッセージ本文
            if (isUser)
              Text(
                widget.message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              )
            else
              _buildMarkdownContent(),
            if (widget.message.isStreaming) ...[
              const SizedBox(height: 8),
              _buildTypingIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownContent() {
    // Artifactのコードブロックは除去して表示
    String displayContent = widget.message.content;
    if (_artifacts.isNotEmpty) {
      displayContent = displayContent
          .replaceAll(RegExp(r'```html\n[\s\S]*?```'), '[HTMLプレビュー ↓]')
          .replaceAll(RegExp(r'```css\n[\s\S]*?```'), '')
          .replaceAll(RegExp(r'```(?:javascript|js)\n[\s\S]*?```'), '');
    }

    return MarkdownBody(
      data: displayContent.isEmpty ? '...' : displayContent,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        code: TextStyle(
          backgroundColor: AppTheme.darkCard.withValues(alpha: 0.5),
          color: AppTheme.accentColor,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        blockquoteDecoration: const BoxDecoration(
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
            color: AppTheme.accentColor.withValues(alpha: 0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
