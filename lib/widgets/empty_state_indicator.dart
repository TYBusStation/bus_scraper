import 'package:flutter/material.dart';

/// 一個通用的空狀態指示器 Widget。
///
/// 用於在列表為空或搜尋無結果時，提供一個視覺上統一的提示。
/// 內部使用 SingleChildScrollView 來避免內容溢出 (Overflow)。
class EmptyStateIndicator extends StatelessWidget {
  const EmptyStateIndicator({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  /// 要顯示的圖示。
  final IconData icon;

  /// 主要標題文字。
  final String title;

  /// 可選的次要標題文字。
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      // 解決方案：將內容包裹在 SingleChildScrollView 中。
      // 這能確保當內容（特別是文字換行後）高度超過可用空間時，
      // 畫面不會出現 Overflow 錯誤，而是可以滾動。
      child: SingleChildScrollView(
        child: Padding(
          // 在周圍增加一些間距，避免內容太靠近螢幕邊緣
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80, // 稍微調整大小以適應更多場景
                color: colorScheme.secondary.withOpacity(0.7), // 使用次要顏色，視覺上更柔和
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 如果有提供副標題，則顯示它
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant, // 使用更柔和的文字顏色
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
