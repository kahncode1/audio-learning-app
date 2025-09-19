/// Download Confirmation Dialog
///
/// Purpose: Prompts user to download course content for offline use
/// Features:
/// - Clear size information
/// - WiFi-only option
/// - Download now or later choice
///
/// Usage:
/// ```dart
/// final result = await showDownloadConfirmationDialog(
///   context: context,
///   courseInfo: downloadInfo,
/// );
/// if (result?.download == true) {
///   // Start download
/// }
/// ```

import 'package:flutter/material.dart';
import '../models/download_models.dart';

/// Result from download confirmation dialog
class DownloadConfirmationResult {
  final bool download;
  final bool wifiOnly;

  DownloadConfirmationResult({
    required this.download,
    required this.wifiOnly,
  });
}

/// Show download confirmation dialog
Future<DownloadConfirmationResult?> showDownloadConfirmationDialog({
  required BuildContext context,
  required CourseDownloadInfo courseInfo,
}) async {
  return showDialog<DownloadConfirmationResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DownloadConfirmationDialog(courseInfo: courseInfo),
  );
}

/// Download confirmation dialog widget
class DownloadConfirmationDialog extends StatefulWidget {
  final CourseDownloadInfo courseInfo;

  const DownloadConfirmationDialog({
    Key? key,
    required this.courseInfo,
  }) : super(key: key);

  @override
  State<DownloadConfirmationDialog> createState() => _DownloadConfirmationDialogState();
}

class _DownloadConfirmationDialogState extends State<DownloadConfirmationDialog> {
  bool _wifiOnly = true; // Default to WiFi only for user safety

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.cloud_download_outlined,
            color: theme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Download Course Content',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download "${widget.courseInfo.courseName}" for offline use?',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),

          // Size information card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Size',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      widget.courseInfo.formattedSize,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      '${widget.courseInfo.fileCount}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // WiFi only option
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CheckboxListTile(
              title: const Text('Download on WiFi only'),
              subtitle: const Text(
                'Recommended to save mobile data',
                style: TextStyle(fontSize: 12),
              ),
              value: _wifiOnly,
              onChanged: (value) {
                setState(() {
                  _wifiOnly = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ),
          const SizedBox(height: 8),

          // Information text
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Once downloaded, you can access all course content offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Later button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              DownloadConfirmationResult(
                download: false,
                wifiOnly: _wifiOnly,
              ),
            );
          },
          child: const Text('Later'),
        ),

        // Download button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              DownloadConfirmationResult(
                download: true,
                wifiOnly: _wifiOnly,
              ),
            );
          },
          icon: const Icon(Icons.download, size: 20),
          label: const Text('Download Now'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reminder dialog for users who chose "Later"
class DownloadReminderDialog extends StatelessWidget {
  final CourseDownloadInfo courseInfo;

  const DownloadReminderDialog({
    Key? key,
    required this.courseInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Content Not Downloaded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need to download course content to access it offline. Would you like to download now?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Size: ${courseInfo.formattedSize}',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Download'),
        ),
      ],
    );
  }
}