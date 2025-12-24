import 'package:flutter/material.dart';

/// 空状態表示ウィジェット
///
/// 使用例:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.inbox_outlined,
///   message: 'データがありません',
///   subtitle: '新しいデータを追加してください',
///   actionLabel: '追加',
///   onActionPressed: () => context.go('/create'),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final iconSize = isTablet ? 80.0 : 64.0;
    final messageFontSize = isTablet ? 18.0 : 16.0;
    final subtitleFontSize = isTablet ? 14.0 : 12.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: messageFontSize,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onActionPressed != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ローディング表示ウィジェット
class LoadingStateWidget extends StatelessWidget {
  final String? message;

  const LoadingStateWidget({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// エラー表示ウィジェット
class ErrorStateWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final iconSize = isTablet ? 64.0 : 48.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: iconSize,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'エラーが発生しました',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel ?? '再試行'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 共通のステートビルダー
/// AsyncValueやStreamBuilderの結果に応じて適切なウィジェットを表示
class StateBuilder<T> extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final T? data;
  final bool Function(T?) isEmpty;
  final Widget Function(T) builder;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  const StateBuilder({
    super.key,
    required this.isLoading,
    this.error,
    this.data,
    required this.isEmpty,
    required this.builder,
    required this.emptyIcon,
    required this.emptyMessage,
    this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LoadingStateWidget(message: loadingMessage);
    }

    if (error != null) {
      return ErrorStateWidget(
        error: error!,
        onRetry: onRetry,
      );
    }

    if (isEmpty(data)) {
      return EmptyStateWidget(
        icon: emptyIcon,
        message: emptyMessage,
        subtitle: emptySubtitle,
        actionLabel: emptyActionLabel,
        onActionPressed: onEmptyAction,
      );
    }

    return builder(data as T);
  }
}
