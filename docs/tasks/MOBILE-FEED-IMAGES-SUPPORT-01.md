# MOBILE-FEED-IMAGES-SUPPORT-01 — 首页触底加载、卡片图片原比例与支持我们页改版

- 模式：常规（用户要求多智能体并行实施，未调用 `$orchestrator`；未进入指挥模式）
- 负责人／状态维护人：当前 Session
- 执行 Session（指挥模式）：不适用；三个执行智能体分别使用独立 Worktree 与分支
- 分支／Worktree／PR：集成分支 `feat/mobile-feed-images-support`（`E:/speechful-mobile-ui`，基线 `3166ca9`）；执行分支见下表；未创建 PR
- 本轮规则版本（指挥模式）：不适用
- 授权依据与边界：用户 2026-11-23 指令「现在有这样几个需求……」及「同时做，你调用不同智能体」。仅授权本地实现、测试与本地提交；未授权 push、PR、合并到 `develop/main` 或发布。
- 需求确认：用户未逐项回答四个取舍，随后明确要求并行实施。本轮按主 Session 已给出的推荐默认执行：①距底约 320 逻辑像素自动加载并显示底部状态；②单图按原比例、多图保持九宫格；③查看器首帧完整原比例；④支持页卡片化分区。**待用户试用后复核**。另：用户新要求「按原始比例渲染」改变了图片查看器既有已确认行为（设计文档 Q1：长图适宽、从顶部进入），本轮改为完整适屏（contain）居中打开，属需用户确认的覆盖。
- 更新日期：2026-11-23
- 状态：实现 已完成；验证 PASS；合并 未合并；发布 未发布

## 目标与范围

交付三项移动端可观察结果：

1. 首页信息流滚动接近底部时自动加载下一页，底部按「加载中 / 加载失败可重试 / 已经到底」显示状态；首屏内容不足一屏时自动补载；不再保留常驻「加载更多」按钮。
2. 帖子卡片单图在正常比例范围内严格按原始宽高比展示、不裁切；极端长图/宽图才居中裁切并提示「点击查看完整图片」。多图横滑卡片按限幅比例铺满、无信箱留白或拉伸，详情九宫格保持方形裁切。图片查看器首帧以完整原比例（contain）渲染。
3. 「支持我们」设置页改为卡片化分区：致谢引入、收款码卡片、用途卡片、扫码/保存说明、全宽主操作按钮与状态消息；保留原保存、权限、前后台与结果语义。

不包含：真实设备视觉与手感验收、iOS/Android 平台专项验收、push/PR/合并发布。首页与作者主页共用卡片组件，作者主页卡片随本次图片改版一并生效（未改其调用点）。

## 接口与依赖

- 首页分页沿用既有 `FeedController.loadTimeline(more: true)` 与 `nextCursor` 游标，未改服务端接口。
- 图片查看器本地包 `packages/image_viewer`：缩放基准固定为完整适屏（contain），预览 painter 同步，保留双击缩放、拖动阅读、下滑关闭、保存与资源释放。
- 未新增第三方依赖；`packages/image_viewer/pubspec.lock` 等 `pub get` 环境差异未提交。

## 验收标准

- 首页接近底部只触发一次下一页请求；加载中、失败重试与到底状态正确；首屏不足一屏自动补载且服务端 cursor 不前进时不会无限重试；下拉刷新、频道切换、发布后刷新与阅读位置不受影响。
- 单图正常比例卡片渲染尺寸比例≈原图比例且无裁切提示；极端比例显示裁切提示；多图卡片无信箱留白/拉伸；查看器首帧完整、原始比例。
- 支持我们页保留 `settings-support-page`、`settings-support-code`、`settings-support-purpose`、`settings-support-save` 四个 ValueKey 与全部保存语义；窄屏与大字号不溢出；状态消息保持 liveRegion。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 首页触底加载 | `63bb485`（feat/feed-infinite-scroll） | 320px 自动加载、底部状态、首屏补载、重复请求与 cursor 停滞防护；`feed_incremental_test` 11 项、`feed_ui_test` 43 项、`feed_scroll_refresh_test` + `feed_read_error_scope_test` 46 项 PASS |
| 卡片图片与查看器 | `63b4b34`（feat/post-image-original-ratio） | 单图 0.5–3.0 比例/最大高度策略、多图 cover 无留白、查看器 baseline 固定 contain；`feed_media_test` + `post_images_test` 39 项 PASS |
| 支持我们页 | `1bb8b64`（feat/support-settings-redesign） | 卡片化分区、全宽 FilledButton、大小屏/大字号测试；`settings_screen_test` + `profile_settings_flow_test` + `community_localization_test` 19 项 PASS |
| 集成 | `322071d`（feat/mobile-feed-images-support） | 三分支无冲突合并；`flutter analyze` PASS |
| 全量移动端测试 | Flutter 3.47.5 / Dart 3.13.4，Windows 10.0.26200；`apps/mobile` | `flutter test --no-pub` → **1392 passed / 4 skipped**，PASS |
| 查看器包测试 | 同上；`packages/image_viewer` | `flutter test --no-pub` → **149 passed**，PASS |
| 真机/人工视觉验收 | 未执行 | **NOT_RUN**：需用户在实际设备确认触底手感、卡片裁切观感、查看器首帧与支持页视觉 |

## 阻碍与下一步

- 真实设备视觉与手感（首页自动加载触发点、极端比例卡片、查看器长图首帧、支持页明暗主题）尚未验收，需用户试用确认。
- 用户未逐项确认四项产品取舍；若与预期不符，可按项调整：加载提前量/失败按钮、单图比例上限、查看器长图初始位置、支持页视觉方向。
- 查看器长图初始行为覆盖了 2026-10-08 已确认的 Q1（适宽、顶部进入）；若仍需沿用旧行为，需只回退 `viewer_surface.dart`/`viewer_preview.dart` 的基准改动。
- push、PR、合并与发布未获授权，保持未执行。
