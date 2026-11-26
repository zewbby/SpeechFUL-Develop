import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'telegram_theme.dart';

/// 应用内轻量反馈的唯一视觉实现。
///
/// 所有同类提示（「不感兴趣」归属提示、分享失败、拉黑结果、头像失败、
/// 评论图片失败、私信操作失败等）都必须经过这里，避免旧样式残留。
///
/// 交互：显示后 2 秒自动关闭；右侧明显的叉号可立即关闭；左右滑动可移除。
/// 新提示到来时先关闭上一条，不排队叠加。关闭按钮不会取消自动关闭
/// （显式 `persist: false`），切页时仍跟随根 ScaffoldMessenger，行为一致。
void showHhFeedback(
  BuildContext context,
  String message, {
  bool replaceCurrent = true,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      key: const ValueKey('hh-feedback'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      // 水平拖动完全由内容区接管，避免 SDK 默认单向滑动手势竞争。
      dismissDirection: DismissDirection.none,
      // 带关闭按钮时 SDK 默认 persist=true，定时器不会生效，必须显式关掉。
      persist: false,
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      content: _HhFeedbackContent(message: hhText(context, message)),
    ),
  );
}

class _HhFeedbackContent extends StatefulWidget {
  const _HhFeedbackContent({required this.message});
  final String message;

  @override
  State<_HhFeedbackContent> createState() => _HhFeedbackContentState();
}

class _HhFeedbackContentState extends State<_HhFeedbackContent> {
  double _dragX = 0;

  void _close() {
    // 同一个根 messenger 让跨页时也能关闭当前提示，而不是只关当前子路由。
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    if (mounted) setState(() => _dragX = 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = HhTelegramPalette.of(context);
    return GestureDetector(
      key: const ValueKey('hh-feedback-swipe'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() => _dragX += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        final width = context.size?.width ?? 300;
        final fast = (details.primaryVelocity ?? 0).abs() > 500;
        if (fast || _dragX.abs() > width * .25) {
          _close();
        } else {
          setState(() => _dragX = 0);
        }
      },
      onHorizontalDragCancel: () => setState(() => _dragX = 0),
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const ValueKey('hh-feedback-close'),
              tooltip: hhText(context, '关闭'),
              icon: Icon(Icons.close_rounded, size: 22, color: p.secondary),
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }
}
