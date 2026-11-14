# AUTHOR-BLOCK-UNIFICATION-01 — 拉黑只保留账号级作者拉黑

- 模式：常规；负责人：当前 Session；无委派。
- 分支／Worktree／PR：`codex/feat/author-block-unification`；临时检出 `%TEMP%/sf-develop-inspect`，复审修复在 `%TEMP%/sf-pr150-fix`（本地分支 `fix/pr150-review`，基线 `86c1d3e`），未推送；[PR #150](https://github.com/zewbby/SpeechFUL-Develop/pull/150)。
- 基线：`2fdf8f6a2b62d708d229e3fc372081df39f85bd0`（`origin/main`）。
- 授权依据：2026-11-14 用户确认设计后要求“将拉黑只保留作者拉黑，将单独私信拉黑删除，从私信，会话管理找到的拉黑按钮点击之后直接就是作者拉黑”，并明确“好的将改动提交pr到 https://github.com/zewbby/SpeechFUL-Develop/pulls”；覆盖本提交、推送与 PR，不含合并、发布或装机。
- 需求确认：只有一种拉黑模式，即账号级作者拉黑；私信会话管理的“拉黑”直接执行该模式。按钮和行内文字只保留“拉黑／解除拉黑／解除／取消”，删除灰色补充说明。黑名单页不设分区标题、不显示返回箭头，记录行为头像、名称与描边“解除”，空态为“暂无记录”。确认面板保留但简化：无标题，只有对方头像、名称、“拉黑”（或“解除拉黑”）与“取消”；举报不再出现在拉黑面板。无未决取舍。
- 更新日期：2026-11-14。
- 状态：实现已完成；产品 CI 于 `f127504` 全部适用检查通过（含 Android prerelease）；复审修复已本地提交（`5c59199`、`6ce1a71`），Go 交叉类型检查 PASS，Flutter 与迁移执行 NOT_RUN，未推送，无对应 CI；未合并；未发布。

## 目标与范围

把私信模块原有的“仅私信拉黑”合并为账号级作者拉黑：一次拉黑对双方所有身份的帖子、评论和私信生效，黑名单只有一份。私信会话管理的拉黑按钮、设置黑名单页、服务端写入路径、目录 `ownBlockId`、迁移与文档同步调整。

不包含：新增独立拉黑 API、修改举报流程入口位置、真机安装、合并或发布。旧版 `PUT/GET /api/v1/dm/governance/blocks/{operationId}` 线路保留以兼容旧客户端；其写入改落账号级表，旧列表按设计返回空。附带修复 `tools/prerelease/environment.py` 的回滚归档范围（仅 `services/api`，与开放 PR #149 相同），避免归档移动端 LFS 字体时缺少凭据导致 Android prerelease `rehearsal` 失败。

## 接口与依赖

- `PUT /api/v1/dm/governance/blocks/{operationId}`：保持请求体 `{identityId, conversationId, blocked}` 与幂等回执；`blockId` 改为账号级记录 ID，解除无记录时为空。
- `GET /api/v1/me/blocked-authors`、`DELETE /api/v1/me/blocked-authors/{blockId}`：唯一黑名单数据源；解除任一记录恢复双方全部可见性。
- `GET` 私信目录与聊天目录的 `ownBlockId`：改为账号级记录 ID，所有身份会话一致。
- 迁移 `0040_author_block_unification.sql`：复制 `c_dm.blocks` 到 `c_posts.blocked_authors`（保留 `block_id`，同一账号对取最早记录），随后清空旧表；Down 拒绝破坏性回滚。
- 依赖既有扫描/发送谓词 `c_posts.accounts_blocked`，不新增旁路。

## 验收标准

- 从任一会话管理点“拉黑”只出现简化确认面板；确认后只产生一条账号级记录，帖子和评论互相不可见，私信暂停；切换本人其他身份仍受同一拉黑约束。
- 私信目录任一身份会话显示同一 `ownBlockId`；从任一会话解除后，双方帖子、评论和私信恢复。
- 黑名单页仅显示账号级记录，无分区标题和无返回箭头；行内只有头像、名称与“解除”，无灰色说明；松开后确认面板同样简化。
- 空名单显示“暂无记录”；读取失败可就地重试且不伪造空态。
- 旧 `c_dm.blocks` 数据在升级后成为可管理的账号级记录，旧私信拉黑列表为空；重复操作 ID 返回同一回执。
- 迁移链版本推进到 40 后，既有 fixture 与产品 CI 通过。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | 提交 `a0eae1f`（分支 `codex/feat/author-block-unification`，基线 `2fdf8f6`） | 后端写入／目录、迁移 0040、OpenAPI、设计文档、Flutter 黑名单页与私信面板、Go／Flutter 测试已改；PR #150 |
| 验证 | 本地 Windows 无 `go`、`gofmt`、`flutter`、`dart`；WSL Ubuntu 的 ext4 VHDX 报 `ERROR_PATH_NOT_FOUND` | BLOCKED：无法本地编译、格式化或跑 Go／Flutter 测试；静态核对完成，产品 CI 结果见后两行 |
| 验证 | 临时 venv 安装 `packages/openapi/requirements-check.txt`；工作树差异 | PASS：`check-direct-message-contract.py` 输出 DM P1／P2／P3 PASS；`check-specs.py` 校验 `direct-message-governance.yaml`、`direct-message-chat.yaml`、`direct-message-text.yaml` 全部通过 |
| 实现 | 提交 `f127504` | `tools/prerelease/environment.py` 回滚归档仅包含 `services/api`，修复 `rehearsal` 对基线归档时触发 LFS 字体 smudge 的失败 |
| 验证 | PR #150 产品 CI，提交 `44c9c73`，2026-11-14 | PASS：Direct message chat、Feed backend、Feed UI、Identity avatars、Community text contract、Comments core、Post images、Auth feedback、Report moderation、Shared rate limit、Collaboration、iOS build、go-postgres、feed-postgres、reliable-chat-sql 等适用检查；`Comment snapshot Redis` 首次 `TestRealRedisPublishPatchAOFReplay` 报 Redis 夹具不可用，原 job 重跑通过 |
| 验证 | PR #150 `Android prerelease`，提交 `44c9c73` | FAIL（已修复）：`candidate` 通过，`rehearsal` 的“Actual new-instance restore and application rollback”对基线 `2fdf8f6` 执行 `git archive` 时触发 `apps/mobile/assets/fonts/NotoSansSC-Variable.ttf` 的 LFS smudge，checkout 无 LFS 凭据；`f127504` 将归档范围限制为 `services/api` |
| 验证 | PR #150 产品 CI，提交 `f127504`，2026-11-14 | PASS：13 个 workflow 全部通过，含 Android prerelease 的 `scope`、`candidate`、`rehearsal`；`mergeable_state=clean` |
| 复审修复 | 本地提交 `5c59199`（基线 `86c1d3e`） | 升级 fixture 在 v39 写入两条同一账号对的旧 `c_dm.blocks`（不同身份、不同时间），断言 0040 只保留最早 `block_id`／`created_at` 且清空旧表 |
| 复审修复 | 本地提交 `6ce1a71`（基线 `5c59199`） | 黑名单解除成功后先移除本地行；刷新失败且列表为空时就地重试、不显示“暂无记录”；列表非空时显示可点重试的错误行；新增 widget 测试 |
| 验证 | 本地 go1.22.12（临时下载，GOOS=linux 交叉类型检查）；无 Flutter／PostgreSQL | PASS：`GOWORK=off GOOS=linux go vet ./internal/authprivacy`（`-mod=readonly`）退出 0；Dart 两文件 tree-sitter 解析无错误；两份契约检查 PASS（DM P1／P2／P3、14 份 spec）。NOT_RUN：需 Postgres／goose 的迁移测试与 Flutter widget 测试 |

## 阻碍与下一步

本地无 Flutter SDK 与 PostgreSQL／goose 夹具，Go 只完成交叉类型检查，不能把静态核对当作通过。PR #150 head `86c1d3e` 的适用 CI 已全部通过；复审修复 `5c59199`、`6ce1a71` 尚未推送，无对应 CI。合并顺序：本分支保持 `0040`，须先合 #150；开放 PR #151（head `9ba2f6b`，29 项检查全绿，`mergeable_state=clean`）同时新增 `0040_campus_categories.sql`，并 UPDATE／INSERT `public.channels`。两 PR 不能同时按 40 合入：若 #151 先落地，#150 需改为 `0041`，把测试的 `up-to` 目标改为 #150 迁移的前一版本，并同步 41 的链断言；若 #150 先落地，#151 改号 41 时也必须把本测试的 `count/max` 改为 41 并处理 `public.channels` 快照。当前分支不做推测性改号。合并与发布需另行授权。

## 复审结论

- P1 迁移版本冲突：不在本分支推测性改号；按上述合并顺序处理。
- P2 迁移无数据覆盖：`5c59199` 已覆盖复制、最早记录去重与旧表清空；`DELETED` 投影与 CLOSED 账号跳过分支仍无专项测试，列为已知缺口。
- P3 黑名单刷新失败：`6ce1a71` 已修复并加测试；无调用的 `blocks()`、3 个孤儿翻译键按最小改动原则保留；`messaging.md:91` 与 `moderation.md:64` 一致，不改。
- 本轮仅本地提交；第二次审查以 `fix/pr150-review` head 为对象，待授权推送后由 CI 复验。
