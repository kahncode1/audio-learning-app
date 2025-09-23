/// Highlighted Text Display
///
/// Purpose: Displays scrollable text with dual-level highlighting
/// Manages text rendering and scroll behavior
///
/// Features:
/// - Displays highlighted text content
/// - Manages scroll controller
/// - Adjustable font size
/// - Error state handling
///
import 'package:flutter/material.dart';
import '../../services/progress_service.dart';
import '../../widgets/simplified_dual_level_highlighted_text.dart';
import '../../theme/app_theme.dart';

class HighlightedTextDisplay extends StatelessWidget {
  final String? displayText;
  final String contentId;
  final ScrollController scrollController;
  final ProgressService? progressService;
  final bool isFullscreen;

  const HighlightedTextDisplay({
    super.key,
    required this.displayText,
    required this.contentId,
    required this.scrollController,
    this.progressService,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: isFullscreen ? 24 : 20,
        right: isFullscreen ? 24 : 20,
        top: isFullscreen ? 50 : 12,
        bottom: isFullscreen ? 20 : 0,
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (displayText == null || displayText!.isEmpty) {
      return _buildEmptyState(context);
    }

    return SimplifiedDualLevelHighlightedText(
      text: displayText!,
      contentId: contentId,
      baseStyle: _getTextStyle(context),
      sentenceHighlightColor: Theme.of(context).sentenceHighlight,
      wordHighlightColor: Theme.of(context).wordHighlight,
      scrollController: scrollController,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No content available',
          style: _getTextStyle(context).copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseFontSize = progressService?.currentFontSize ?? 18.0;
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: baseFontSize,
    );
  }
}

/// Error display widget for text loading failures
class TextLoadingError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const TextLoadingError({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load content',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading indicator for text content
class TextLoadingIndicator extends StatelessWidget {
  const TextLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading content...'),
          ],
        ),
      ),
    );
  }
}