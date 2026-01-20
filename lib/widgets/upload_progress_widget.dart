import 'package:flutter/material.dart';
import 'package:eduverse/services/background_upload_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Widget to display background upload progress
class UploadProgressIndicator extends StatelessWidget {
  final bool showLabel;
  final double iconSize;

  const UploadProgressIndicator({
    super.key,
    this.showLabel = false,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundUploadService(),
      builder: (context, _) {
        final service = BackgroundUploadService();
        if (!service.hasActiveUploads) {
          return const SizedBox.shrink();
        }

        final isDark = AppTheme.isDarkMode(context);
        final activeTasks = service.uploadTasks
            .where(
              (t) =>
                  t.status == UploadStatus.uploading ||
                  t.status == UploadStatus.processing,
            )
            .toList();

        if (activeTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        final avgProgress =
            activeTasks.map((t) => t.progress).reduce((a, b) => a + b) /
            activeTasks.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: avgProgress,
                      strokeWidth: 2,
                      backgroundColor: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.cloud_upload,
                        size: iconSize * 0.6,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  '${(avgProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Full upload status card for course screen - shows all uploads
class UploadStatusCard extends StatelessWidget {
  final String courseUid;
  final VoidCallback? onTap;

  const UploadStatusCard({super.key, required this.courseUid, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundUploadService(),
      builder: (context, _) {
        final service = BackgroundUploadService();
        // Get all active uploads for this course
        final allTasks = service.uploadTasks
            .where(
              (t) =>
                  t.courseUid == courseUid &&
                  (t.status == UploadStatus.uploading ||
                      t.status == UploadStatus.processing ||
                      t.status == UploadStatus.pending),
            )
            .toList();

        if (allTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = AppTheme.isDarkMode(context);
        final currentTask = allTasks.first;
        final hasMoreTasks = allTasks.length > 1;

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const UploadTasksBottomSheet(),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uploading: ${currentTask.videoTitle}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentTask.status == UploadStatus.processing
                                ? 'Processing...'
                                : 'Uploading video...',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(currentTask.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: currentTask.progress,
                    backgroundColor: isDark
                        ? AppTheme.darkBorder
                        : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'You can navigate away. Upload continues in background.',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (hasMoreTasks)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+${allTasks.length - 1} more',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              size: 14,
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet to show all upload tasks
class UploadTasksBottomSheet extends StatelessWidget {
  const UploadTasksBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return ListenableBuilder(
      listenable: BackgroundUploadService(),
      builder: (context, _) {
        final service = BackgroundUploadService();
        final tasks = service.uploadTasks;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload Tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Tasks list
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_done,
                        size: 48,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active uploads',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskTile(context, task, isDark);
                  },
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskTile(BuildContext context, UploadTask task, bool isDark) {
    final service = BackgroundUploadService();

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (task.status) {
      case UploadStatus.pending:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case UploadStatus.uploading:
        statusIcon = Icons.cloud_upload;
        statusColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
        statusText = 'Uploading ${(task.progress * 100).toInt()}%';
        break;
      case UploadStatus.processing:
        statusIcon = Icons.settings;
        statusColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
        statusText = 'Processing...';
        break;
      case UploadStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = AppTheme.success;
        statusText = 'Completed';
        break;
      case UploadStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        statusText = 'Failed';
        break;
      case UploadStatus.cancelled:
        statusIcon = Icons.cancel;
        statusColor = Colors.grey;
        statusText = 'Cancelled';
        break;
    }

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.processing)
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: task.progress,
                strokeWidth: 3,
                backgroundColor: isDark
                    ? AppTheme.darkBorder
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          Icon(statusIcon, color: statusColor),
        ],
      ),
      title: Text(
        task.videoTitle,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppTheme.getTextPrimary(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.courseTitle,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing:
          task.status == UploadStatus.uploading ||
              task.status == UploadStatus.processing
          ? IconButton(
              onPressed: () => service.cancelUpload(task.id),
              icon: Icon(Icons.close, color: Colors.red.shade400),
              tooltip: 'Cancel',
            )
          : task.status == UploadStatus.failed
          ? IconButton(
              onPressed: () => service.retryUpload(task.id),
              icon: Icon(
                Icons.refresh,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              tooltip: 'Retry',
            )
          : null,
    );
  }
}
