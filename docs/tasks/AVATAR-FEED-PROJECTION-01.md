# AVATAR-FEED-PROJECTION-01 — 更换头像后首页帖子头像及时更新

- 模式：常规
- 负责人／状态维护人：当前 Session
- 执行 Session（指挥模式）：无
- 分支／Worktree／PR：`fix/avatar-feed-projection`；基线 `main@213b8b0`；本地提交 `ed90104`；PR 未创建
- 本轮规则版本（指挥模式）：不适用
- 授权依据与边界：用户报告“修改头像后主页我发过帖子的头像不会改变，点进帖子页又更新，别人改头像我能看到更新”。本次只修复该展示同步问题；不改服务端、OpenAPI、迁移、发布流程，不 push、不建 PR、不合并、不发布，除非用户另行授权。
- 需求确认：用户期望换头像后自己已发帖子的头像无需进入详情即可更新；同时保留详情页读取最新投影的现状。未涉及产品取舍；无未决取舍。
- 更新日期：2026-11-19
- 状态：实现 已完成；验证 PASS（自动化，真机手工 NOT_RUN）；合并 未合并；发布 未发布

## 目标与范围

修复更换头像后已显示帖子仍使用旧 `author.avatar` 的展示问题。覆盖首页时间线（`FeedController.timelineItems`）以及“我的”页本人帖子投影；帖子详情继续以服务端最新读取结果为准。不包含服务端投影改动、历史帖子数据迁移、头像字节缓存策略调整或发布操作。

根因：身份变更返回后，`PostController.refreshKnownPosts()` 只刷新旧 `feedItems`，而首页 `FeedScreen` 实际展示 `PostController.homeFeed.timelineItems`，后者没有刷新，因此保留旧头像；进入详情时重新读取服务端最新作者投影，所以显示新头像。他人修改头像可见，是本机列表重新加载服务端最新投影的结果。

## 接口与依赖

无新增接口。沿用现有帖子列表、详情与身份目录读取；只调整客户端在身份资料变化后的已显示投影刷新路径。

## 验收标准

- 更换当前身份头像并返回首页后，首页已显示的本账号帖子头像更新为新头像，无需打开帖子详情或重启应用。
- 换个身份或重新进入首页后，列表顺序、分页游标与滚动数据不被重置。
- “我的”页已加载的本人帖子头像与身份目录中的当前头像一致。
- 帖子详情仍读取服务端最新作者投影；身份目录读取失败时保持现有失败提示与重试语义。
- 现有首页增量刷新、删除/隐藏过滤和互动状态不受影响。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | 基线 `main@213b8b0`，分支 `fix/avatar-feed-projection`，本地提交 `ed90104` | `FeedController.refreshDisplayedProjections()` 按当前已显示帖子 ID 重新读取公共时间线页，原位替换标题、正文、作者、标签与图片投影，保留列表顺序、分页游标、频道条件、删除过滤和本地较大的浏览量；`PostController.refreshKnownPosts()` 在身份变更后先调用该刷新，再保留原有旧列表刷新。新增首页与个人页头像刷新回归测试，并补充跨页、默认不插入新帖和浏览量保留断言。 |
| 验证 | `ed90104`；Windows 11 25H2 x64 / Flutter 3.47.5 / Dart 3.13.4 | `flutter test test/feed_incremental_test.dart test/avatar_feed_projection_test.dart --no-pub -r expanded` → 7 项 PASS（新增首页用例修复前失败、修复后通过；个人页用例修复前后均通过）；`flutter test test/post_controller_test.dart test/feed_ui_test.dart test/personal_profile_test.dart test/login_home_navigation_test.dart test/active_identity_test.dart --no-pub -r compact` → 118 项 PASS；`flutter analyze --no-pub` → PASS（No issues found）；完整 `flutter test --no-pub --concurrency=2 -r compact` → 1362 项通过、4 项跳过 PASS；受影响 4 个 Dart 文件 `dart format --output=none --set-exit-if-changed` → 0 项变化；`git diff --check` → PASS。完整套件运行时的代码与测试内容与该提交一致，之后仅追加文档。真机手工复验 `NOT_RUN`：未安装运行，待验证换头像返回首页后无需重启即更新、列表顺序/滚动保持、“我的”页一致、详情不变及读取失败重试。产品 CI／PR 检查 `NOT_RUN`（未推送，无 PR）。 |

## 阻碍与下一步

自动化实现与验证已完成。真机手工复验 `NOT_RUN`（未装机）；等待用户试用确认。推送、创建 PR、合并与发布均未授权，未执行。
