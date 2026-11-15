# SpeechFUL 变更日志

记录本仓库的写入型改动，最新条目在最上面；格式与门禁见 `.agents/skills/minimal-change/SKILL.md`。

## 2026-11-16 04:24 · 加速通知列表与未读统计读取

- 状态：已完成
- 改动：
  - 新增迁移 0045，为 `c_inbox.records` 增加 `latest_like_version`（当前仍存活的最新点赞事件版本），由 `c_inbox.like_changed()` 在同一记录行锁内维护；`c_inbox.account_closed()` 直接删除点赞事件后同步重算，并先按 `notification_id` 排序锁住受影响记录，避免关闭账号留下幽灵未读。历史数据按 `like_events` 最大值回填（本任务合成库 40,000 行）。
  - 新增部分索引 `c_inbox.inbox_unread`，同时服务未读统计聚合与“只看未读”列表排序；行在 `read_version` 追上最新事件后自动离开索引。
  - `ReadInbox` 按是否只看未读选择专用 SQL，去掉逐行 `unread` 表达式与逐条 `EXISTS c_inbox.like_events` 探测。
  - `ReadInboxCounts` 合并为一次账号级分组查询（同时得到各身份 all/reply/like）加一次系统通知计数；选中身份时取对应分组，不再重复扫描账号全部记录。
  - `readInboxNotice` 仅在 `latest_like_version > read_version` 时统计新增点赞数。
- 文件：`services/api/migrations/0045_notification_read_indexes.sql`（新增）、`services/api/internal/authprivacy/community_inbox.go`、`services/api/internal/authprivacy/community_inbox_test.go`、`services/api/internal/authprivacy/community_inbox_migration_test.go`、`services/api/internal/authprivacy/community_direct_messages_migration_test.go`、`services/api/internal/authprivacy/community_feed_migration_test.go`、`services/api/internal/authprivacy/identity_avatar_migration_test.go`（迁移账本与回填断言）、`.github/workflows/comments-backend-text.yml`（路径过滤）、`docs/tasks/REQ-007-NOTIFICATION-READ-ACCEL.md`（新增）
- 验证：
  - 环境：WSL2 Ubuntu-24.04 / PostgreSQL 16；基线 `main@1d829b2`，分支 `perf/notification-read-accel`，Worktree `E:\speechful-notif-accel`；Go 1.22.2。
  - 构建：`gofmt -l` 无输出；`go build -mod=readonly ./cmd/authdev`、`go vet -mod=readonly ./internal/authprivacy ./internal/authprivacyhttp` PASS。
  - 真实 PostgreSQL：`TestNotificationInboxPostgres`、`TestNotificationInboxIdentityPaginationPostgres`、`TestNotificationInboxHTTPSPostgres`、`TestInboxRoutesAndDisabledMentionsBoundary`、`TestNotificationInboxGooseMigrationPostgres`（fresh/upgrade，含回填=2、列默认值、索引存在、Down 拒绝、账本 max=45）、`TestDMGooseFreshAndUpgradePostgres`（fresh/upgrade）、`TestFeedGooseFreshAndUpgradePostgres`（7 模式）PASS；`TestIdentityAvatarGooseFreshAndUpgradePostgres` 在独立空 fixture 中 PASS（与其它迁移测试共用 fixture 时会因库非空而按设计失败，非回归）。
  - 行为断言：点赞→取消→全部取消时 `latest_like_version` 依次为 1/2→1→0，`version` 保持单调；关闭点赞者账号后其事件删除、`latest_like_version` 归零且未读统计不再计数；运行角色仍不能更新新列（`CheckCommentSchema` 的列级 UPDATE 断言 PASS）。
  - 查询计划 A/B（同一隔离数据集副本：50,000 条互动记录、120,000 条点赞事件、5,000 条系统通知、账号 5 个身份；VACUUM ANALYZE 后热缓存）：未读统计 160.5 ms（选中身份 91.6 ms + 账号级逐身份 68.9 ms）→ 7.4 ms（分组 6.9 ms + 系统 0.5 ms）；全部列表 50.7 ms → 16.9 ms；未读列表 75.1 ms → 6.7 ms。基线每条 LIKE 通知一次 `like_events` 探测（选中 24,000 次、账号级 40,000 次，约 74k/122k shared buffers）；最终统计为 `Index Only Scan using inbox_unread`（324 buffers）。
  - 等价性：各身份未读数、选中身份 all/reply/like、系统计数与基线逐项一致；全部列表与未读列表前 21 条 ID/时间逐行 `diff` 一致。
  - 产品级 P95 与真机链路 `NOT_RUN`（需真实规模数据与客户端联调）。
- 回滚：`git revert <任务提交 SHA>`。0045 的 Down 与 0028/0041/0042 一样拒绝回退；线上如需撤销读取路径，应按前向修复发布新的迁移恢复 0028 函数与查询，不要直接 `DROP COLUMN`。仅一次性开发库可在确认无依赖后执行 `DROP INDEX IF EXISTS c_inbox.inbox_unread; ALTER TABLE c_inbox.records DROP COLUMN IF EXISTS latest_like_version;` 并恢复 0028 定义。
- 任务：`docs/tasks/REQ-007-NOTIFICATION-READ-ACCEL.md`
- 授权：用户 2026-11-16 指令“继续完成07优化”（需求行“通知列表与未读统计优化”）；仅本地提交，未 push、未建 PR、未合并、未部署。
