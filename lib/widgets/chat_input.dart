import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;
  final VoidCallback? onStop;
  final VoidCallback? onSkillTap;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.onStop,
    this.onSkillTap,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSend(text);
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  /// 外部からテキストを設定（スキル実行用）
  void setText(String text) {
    _controller.text = text;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(
            color: AppTheme.darkBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // テキスト入力
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _focusNode.hasFocus 
                              ? AppTheme.primaryColor.withValues(alpha: 0.5) 
                              : AppTheme.darkBorder,
                        ),
                        boxShadow: _focusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {});
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'メッセージを入力...',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (!HardwareKeyboard.instance.isShiftPressed) {
                              _handleSubmit();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSendButton(),
                ],
              ),
              // ボタン行
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActionChip(
                    icon: Icons.psychology_alt_rounded,
                    label: 'スキル',
                    onTap: widget.onSkillTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    if (widget.isLoading) {
      return _buildStopButton();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: _hasText ? AppTheme.primaryGradient : null,
        color: _hasText ? null : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: _hasText
            ? null
            : Border.all(color: AppTheme.darkBorder),
        boxShadow: _hasText
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _hasText ? _handleSubmit : null,
          child: Icon(
            Icons.send_rounded,
            color: _hasText ? Colors.white : AppTheme.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onStop,
          child: const Icon(
            Icons.stop_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
