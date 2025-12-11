import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../providers/search_provider.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;
  final VoidCallback? onStop;
  final VoidCallback? onSkillTap;
  final SearchMode searchMode;
  final Function(SearchMode)? onSearchModeChanged;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.onStop,
    this.onSkillTap,
    this.searchMode = SearchMode.simple,
    this.onSearchModeChanged,
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

  void _showSearchModeMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(16, button.size.height - 120), ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<SearchMode?>(
      context: context,
      position: position,
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.darkBorder),
      ),
      items: [
        _buildSearchMenuItem(null, 'オフ', Icons.search_off_rounded),
        _buildSearchMenuItem(SearchMode.simple, '簡易検索', Icons.search_rounded),
        _buildSearchMenuItem(SearchMode.deep, '詳細検索', Icons.manage_search_rounded),
        _buildSearchMenuItem(SearchMode.research, 'リサーチ', Icons.science_rounded),
      ],
    ).then((mode) {
      if (mode != null || mode == null) {
        widget.onSearchModeChanged?.call(mode ?? SearchMode.simple);
      }
    });
  }

  PopupMenuItem<SearchMode?> _buildSearchMenuItem(SearchMode? mode, String label, IconData icon) {
    final isSelected = (mode == null && widget.searchMode == SearchMode.simple && widget.onSearchModeChanged == null) 
        || widget.searchMode == mode;
    
    Color color;
    switch (mode) {
      case SearchMode.simple:
        color = Colors.blue;
        break;
      case SearchMode.deep:
        color = Colors.green;
        break;
      case SearchMode.research:
        color = Colors.purple;
        break;
      case null:
      default:
        color = AppTheme.textMuted;
    }

    return PopupMenuItem<SearchMode?>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? color : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: color),
          ],
        ],
      ),
    );
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
                  _buildSearchModeChip(),
                  const SizedBox(width: 8),
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

  Widget _buildSearchModeChip() {
    String label;
    IconData icon;
    Color color;
    bool isActive = true;

    switch (widget.searchMode) {
      case SearchMode.simple:
        label = '簡易検索';
        icon = Icons.search_rounded;
        color = Colors.blue;
        break;
      case SearchMode.deep:
        label = '詳細検索';
        icon = Icons.manage_search_rounded;
        color = Colors.green;
        break;
      case SearchMode.research:
        label = 'リサーチ';
        icon = Icons.science_rounded;
        color = Colors.purple;
        break;
      default:
        label = 'Web検索';
        icon = Icons.search_off_rounded;
        color = AppTheme.textMuted;
        isActive = false;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showSearchModeMenu,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive 
                ? color.withValues(alpha: 0.2)
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? color : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: isActive ? color : AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    bool isActive = false,
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
            color: isActive 
                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                size: 16, 
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
