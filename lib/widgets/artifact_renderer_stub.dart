import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/artifact.dart';
import '../../theme/app_theme.dart';

/// Android/iOS用のArtifactレンダラー（WebView使用）
class ArtifactRenderer extends StatefulWidget {
  final Artifact artifact;
  final bool showCode;
  final VoidCallback? onToggleView;

  const ArtifactRenderer({
    super.key,
    required this.artifact,
    this.showCode = false,
    this.onToggleView,
  });

  @override
  State<ArtifactRenderer> createState() => _ArtifactRendererState();
}

class _ArtifactRendererState extends State<ArtifactRenderer> {
  bool _isExpanded = false;
  late WebViewController _controller;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => _isWebViewReady = true);
          },
        ),
      );
    _loadContent();
  }

  void _loadContent() {
    final htmlContent = widget.artifact.toPreviewHtml();
    _controller.loadHtmlString(htmlContent);
  }

  @override
  void didUpdateWidget(ArtifactRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artifact.content != widget.artifact.content) {
      _loadContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (widget.showCode) _buildCodeView() else _buildPreview(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorder),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTypeIcon(),
              color: AppTheme.accentColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.artifact.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getTypeLabel(),
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // コード/プレビュー切替
          _buildToggleButton(
            icon: widget.showCode ? Icons.visibility : Icons.code,
            label: widget.showCode ? 'プレビュー' : 'コード',
            onTap: widget.onToggleView,
          ),
          const SizedBox(width: 8),
          // 展開/縮小
          _buildToggleButton(
            icon: _isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
            label: _isExpanded ? '縮小' : '展開',
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final height = _isExpanded ? 500.0 : 300.0;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (!_isWebViewReady)
              Container(
                color: AppTheme.darkCard,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeView() {
    final files = widget.artifact.files;
    final height = _isExpanded ? 400.0 : 200.0;

    if (files != null && files.isNotEmpty) {
      return DefaultTabController(
        length: files.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: AppTheme.accentColor,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.accentColor,
              tabs: files.keys.map((name) => Tab(text: name)).toList(),
            ),
            SizedBox(
              height: height - 48,
              child: TabBarView(
                children: files.entries.map((entry) {
                  return _buildCodeBlock(entry.value);
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: _buildCodeBlock(widget.artifact.content),
    );
  }

  Widget _buildCodeBlock(String code) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (widget.artifact.type) {
      case ArtifactType.html:
        return Icons.html;
      case ArtifactType.javascript:
        return Icons.javascript;
      case ArtifactType.css:
        return Icons.css;
      case ArtifactType.combined:
        return Icons.web;
      case ArtifactType.markdown:
        return Icons.description;
      case ArtifactType.mermaid:
        return Icons.account_tree;
      case ArtifactType.code:
        return Icons.code;
    }
  }

  String _getTypeLabel() {
    switch (widget.artifact.type) {
      case ArtifactType.html:
        return 'HTML';
      case ArtifactType.javascript:
        return 'JavaScript';
      case ArtifactType.css:
        return 'CSS';
      case ArtifactType.combined:
        return 'HTML + CSS + JavaScript';
      case ArtifactType.markdown:
        return 'Markdown';
      case ArtifactType.mermaid:
        return 'Mermaid Diagram';
      case ArtifactType.code:
        return 'Code';
    }
  }
}
