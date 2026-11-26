# MOBILE-FEEDBACK-PENDING-TOGGLE-01 — 统一轻量反馈与未完成集合按钮

- 模式：常规
- 负责人／状态维护人：当前 Session
- 分支／Worktree／PR：`feat/Home-Profile-update`；未创建 PR
- 授权依据与边界：用户要求统一应用内提示交互并统一「我的」页未完成发布集合的展开/收起按钮；仅修改 `apps/mobile` 展示与交互，不改业务数据、权限或服务端；不 push、不合并、不部署。
- 需求确认：轻量反馈显示后 2 秒自动关闭，提供明显叉号，支持左右滑动移除；其他同类 SnackBar 统一接入；展开/收起按钮同一样式并有按压动画。无未决取舍。
- 更新日期：2026-11-26
- 状态：实现 已完成；验证 PASS（Widget／静态检查），真机手势 NOT_RUN；合并 未合并；发布 未发布

## 目标与范围

新增 `showHhFeedback` 作为应用内 SnackBar 的唯一展示入口，将首页「不感兴趣」失败提示及帖子、评论、私信、举报、通知、设置、分享、头像流程中的同类提示全部接入。新提示替换当前提示，不排队叠加；使用浮动样式、2 秒自动关闭、叉号关闭和双向水平滑动移除。

「我的」页未完成发布集合的展开和收起按钮复用 `_PendingToggleButton`，统一填充配色、尺寸、圆角和图标，并通过局部 `ScaleTransition` 与既有 `HhMotion` 时长提供按压缩放；保留原展开/收起状态及内容高度动画。

不包含「不感兴趣」成功后的原位隐藏/撤销占位，也不改变各提示的既有业务文案与触发条件。

## 接口与依赖

- `lib/src/design_system/feedback.dart`：`showHhFeedback(BuildContext, String, {bool replaceCurrent = true})`。
- 复用根 `ScaffoldMessenger`、`hhText`、`HhTelegramPalette` 和 `HhMotion`。
- 显式禁用 SDK 默认单向 SnackBar 滑动手势，由内容区统一处理双向手势，避免手势竞争。

## 验收标准

- 「不感兴趣」失败及其他原 SnackBar 均呈现统一轻量反馈；业务源码不再直接调用 `showSnackBar`。
- 2 秒自动关闭、叉号立即关闭、左滑和右滑均可关闭。
- 连续触发不排队显示多条；快速关闭及提示期间页面切换均可正常关闭。
- 展开和收起按钮样式一致，使用共享按压动画；点击后集合状态与原有一致。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | `c791f94` ＋ 本轮工作区差异 | 统一反馈入口及全部 25 个调用点收敛；`_PendingToggleButton` 统一按钮外观与按压动画。 |
| Widget 验证 | Windows 本机 Flutter；上述最终差异 | PASS：`flutter test --no-pub test/feedback_test.dart test/post_screens_test.dart test/feed_ui_test.dart test/identity_avatar_photo_test.dart test/identity_avatar_recovery_test.dart test/identity_avatar_scope_test.dart test/motion_test.dart test/personal_profile_test.dart`，118 项通过、1 项原配置跳过。覆盖自动关闭、叉号、连续触发、左右滑动、切页关闭、展开/收起及既有主页/头像/动效回归。 |
| 静态检查 | 同上 | PASS（无 error／warning）：对所有本轮涉及 Dart 文件运行 `flutter analyze --no-pub`，仅 18 条既有 Material 弃用 info；`git diff --check` 通过。 |
| 真机／模拟器 | 无 | NOT_RUN：实际触屏手感仍需设备验收。 |

## 阻碍与下一步

无代码阻碍。未执行 push、PR、合并或部署；如进入发布验收，在目标设备复验滑动手感与页面切换时的提示表现。
