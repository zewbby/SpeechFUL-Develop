# REQ-007-NOTIFICATION-READ-ACCEL — 通知列表与未读统计读取加速

- 模式：常规
- 负责人／状态维护人：当前 Session
- 执行 Session（指挥模式）：无
- 分支／Worktree／PR：`perf/notification-read-accel` @ `E:\speechful-notif-accel`；实现提交 `44243ca`；集成提交 `743cc4c`（按 #4 `a25aa8b` → #6 `44f07a4` → #5 合入，并同步 #6 文档 `af8eda3`）；集成 head `38f93f4`；PR [#5](https://github.com/zewbby/SpeechFUL-Develop/pull/5)（open，base `perf/comment-load-accel`，未合并）
- 本轮规则版本（指挥模式）：不适用
- 授权依据与边界：用户 2026-11-16 指令“继续完成07优化”（需求行“通知列表与未读统计优化”）及“完成后向仓库提交pr”。授权范围为定位、实现、隔离库验证、本地提交、推送本任务分支并创建 PR；未授权合并、部署、发布或改动正式数据。
- 需求确认：用户已确认优化对象为通知列表与未读统计读取。读取口径沿用现有产品语义：互动通知按当前身份过滤，系统通知按账号共享；COMMENT 未读为 `read_version=0`，LIKE 未读为存在版本大于 `read_version` 的点赞事件；取消点赞不回退 `version`，已读历史由 `seen_like_count` 保留。无未决取舍。
- 更新日期：2026-11-16
- 状态：实现 已完成；验证 PASS（含 #4 → #6 → #5 组合回归；产品级 P95 NOT_RUN）；合并 未合并；发布 未发布

## 目标与范围

加快通知列表首屏与未读角标统计的数据库读取，不改变接口字段、排序、分页游标或未读语义。

包含：
- 为 `c_inbox.records` 增加冗余列 `latest_like_version`，由点赞事件触发器在记录行锁内维护，把逐条通知的 `EXISTS c_inbox.like_events` 未读探测改为行内比较。
- 新增未读部分索引，同时服务未读统计聚合与“只看未读”列表排序。
- 未读统计由“选中身份一次列表聚合 + 账号级逐行探测 + 账号级逐身份计数”合并为一次账号级分组查询加一次系统通知计数。
- 列表 SQL 按“全部/只看未读”拆分，避免在 SQL 内对每行计算 `unread` 再过滤。

不包含：
- 移动端 UI、接口契约或响应结构变化。
- 系统通知表结构或已读逻辑调整。
- 正式库数据迁移执行、发布与线上指标采集。

## 接口与依赖

- 无 OpenAPI 变更；`ReadInbox`、`ReadInboxCounts` 的输入输出保持不变。
- 依赖迁移 `0045_notification_read_indexes.sql`。按审查建议以 #4 → #6 → #5 顺序集成：合入 0043（私信目录）与 0044（评论读取）后，本分支账本为 45/45；迁移账本断言已随集成依次调整（43/43 → 44/44 → 45/45）。
- 迁移为前向修复：`Down` 与 0028/0041/0042 一样显式拒绝，因为回退函数会恢复逐行事件探测，而读取代码已依赖新列。

## 验收标准

- 通知列表“全部 / 回复 / 点赞 / 系统”的顺序、游标分页和未读标记与改动前一致。
- 未读统计在选中身份与未选身份时均与改动前一致；系统通知只计一次且按账号共享。
- 点赞、取消点赞、标记已读、关闭点赞者账号后，未读数与未读列表立即正确；全部取消后已读历史仍保留，不出现幽灵未读。
- 读取路径不再为每条 LIKE 通知探测 `like_events`；未读统计不再逐身份重复扫描。
- 运行角色仍不能写 `latest_like_version`，只能更新 `read_version`、`seen_like_count`。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | `perf/notification-read-accel`，基线 `1d829b2`，实现提交 `44243ca` | 迁移 0045、读取 SQL、统计合并、迁移账本与行为断言 |
| 验证 | WSL2 Ubuntu-24.04 / PostgreSQL 16，隔离 socket fixture；Go 1.22.2 | PASS：`go build -mod=readonly ./cmd/authdev`、`go vet -mod=readonly ./internal/authprivacy ./internal/authprivacyhttp`；`TestNotificationInboxPostgres`、`TestNotificationInboxIdentityPaginationPostgres`、`TestNotificationInboxHTTPSPostgres`、`TestInboxRoutesAndDisabledMentionsBoundary`、`TestNotificationInboxGooseMigrationPostgres`（fresh/upgrade，含 40,000 行回填与索引断言）、`TestDMGooseFreshAndUpgradePostgres`（fresh/upgrade）、`TestFeedGooseFreshAndUpgradePostgres`（7 模式）、`TestIdentityAvatarGooseFreshAndUpgradePostgres`（独立 fixture）均 PASS |
| 查询计划 A/B | 同一隔离数据集副本：50,000 条互动记录、120,000 条点赞事件、5,000 条系统通知；账号 5 个身份；VACUUM ANALYZE 后热缓存 | 未读统计（选中身份 + 账号级逐身份）：160.5 ms → 7.4 ms（分组 6.9 ms + 系统 0.5 ms）；全部列表：50.7 ms → 16.9 ms；未读列表：75.1 ms → 6.7 ms。基线每条 LIKE 通知一次 `like_events` 探测（选中 24,000 次、账号级 40,000 次），最终统计走 `inbox_unread` Index Only Scan（324 buffers），未读列表同样命中该索引 |
| 等价性 | 同上 A/B 库 | 各身份未读数与系统计数逐项一致；全部列表与未读列表前 21 条 ID/时间逐行 `diff` 一致 |
| 集成验证 | 集成提交 `743cc4c`（#4 `a25aa8b` → #6 `44f07a4` → #5），WSL2 Ubuntu-24.04 / PostgreSQL 16，隔离 fixture；Go 1.22.2 | PASS：迁移账本 45/45（DM fresh/upgrade、feed 7 模式、avatar、通知 fresh/upgrade）；DM 目录重建 7 子测试、索引回滚/重放、迁移版本唯一性；评论/通知 CI 聚焦集（`TestCommentText*`、`TestCommentBusiness*`、`TestNotificationInbox*`、`TestInboxRoutesAndDisabledMentionsBoundary`、moderation 迁移集）全部 PASS；`go build ./...`、`go vet`、LF 副本 `gofmt -l` 无输出 |
| 产品 CI | PR #5 head `3b25645`（集成前） | PASS：21 项检查 20 success、1 skip（`actual-process-acceptance` 按设计跳过）；`go-postgres`、`feed-postgres`、`flutter`、`policy` 等均 success |
| 产品 CI | PR #5 集成 head `38f93f4` | PASS：21 项检查 20 success、1 skip（`actual-process-acceptance` 按设计跳过），无 failure；`go-postgres`、`feed-postgres`、`flutter`、`policy` 等均 success。另有 1 个重复 `policy` 运行被 concurrency 取消，不影响结果；PR 状态 clean |
| 产品级 P95 | 真实规模数据与客户端链路 | NOT_RUN |

## 阻碍与下一步

无实现阻碍。#4 的两项审查修复与 #4 → #6 → #5 集成已完成，组合代码在本地隔离库验证 PASS；PR #5 base 调整为 `perf/comment-load-accel`，推送后等待 GitHub Actions 与复审。产品级 P95、真机联调与发布验证未执行；本任务未合并、未部署。
