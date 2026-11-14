# AUTHOR-BLOCK-UNIFICATION-01 — 拉黑只保留账号级作者拉黑

- 模式：常规；负责人：当前 Session；无委派。
- 分支／Worktree：`codex/feat/author-block-unification`；临时检出 `%TEMP%/sf-develop-inspect`，未使用独立 Worktree。
- 基线：`2fdf8f6a2b62d708d229e3fc372081df39f85bd0`（`origin/main`）。
- 授权依据：2026-11-14 用户确认设计后要求“将拉黑只保留作者拉黑，将单独私信拉黑删除，从私信，会话管理找到的拉黑按钮点击之后直接就是作者拉黑”，并明确“好的将改动提交pr到 https://github.com/zewbby/SpeechFUL-Develop/pulls”；覆盖本提交、推送与 PR，不含合并、发布或装机。
- 需求确认：只有一种拉黑模式，即账号级作者拉黑；私信会话管理的“拉黑”直接执行该模式。按钮和行内文字只保留“拉黑／解除拉黑／解除／取消”，删除灰色补充说明。黑名单页不设分区标题、不显示返回箭头，记录行为头像、名称与描边“解除”，空态为“暂无记录”。确认面板保留但简化：无标题，只有对方头像、名称、“拉黑”（或“解除拉黑”）与“取消”；举报不再出现在拉黑面板。无未决取舍。
- 更新日期：2026-11-14。
- 状态：实现已完成；验证 BLOCKED（本地缺 Go/Flutter 工具链，等待产品 CI）；未合并；未发布。

## 目标与范围

把私信模块原有的“仅私信拉黑”合并为账号级作者拉黑：一次拉黑对双方所有身份的帖子、评论和私信生效，黑名单只有一份。私信会话管理的拉黑按钮、设置黑名单页、服务端写入路径、目录 `ownBlockId`、迁移与文档同步调整。

不包含：新增独立拉黑 API、修改举报流程入口位置、真机安装、合并或发布。旧版 `PUT/GET /api/v1/dm/governance/blocks/{operationId}` 线路保留以兼容旧客户端；其写入改落账号级表，旧列表按设计返回空。

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
| 实现 | 分支 `codex/feat/author-block-unification`，基线 `2fdf8f6` | 后端写入／目录、迁移 0040、OpenAPI、设计文档、Flutter 黑名单页与私信面板、Go／Flutter 测试已改 |
| 验证 | 本地 Windows 无 `go`、`gofmt`、`flutter`、`dart`；WSL Ubuntu 的 ext4 VHDX 报 `ERROR_PATH_NOT_FOUND` | BLOCKED：无法本地编译、格式化或跑 Go／Flutter 测试；静态核对完成，待推送后产品 CI 结果 |
| 验证 | 临时 venv 安装 `packages/openapi/requirements-check.txt`；工作树差异 | PASS：`check-direct-message-contract.py` 输出 DM P1／P2／P3 PASS；`check-specs.py` 校验 `direct-message-governance.yaml`、`direct-message-chat.yaml`、`direct-message-text.yaml` 全部通过 |

## 阻碍与下一步

本地工具链不可用，不能把静态核对当作通过。下一步：提交并推送 `codex/feat/author-block-unification`，向 `zewbby/SpeechFUL-Develop` 的 `main` 开 PR，等待 Direct message chat、Feed、Identity avatars 等适用产品 CI；按 CI 结果修复后在任务记录追加证据。合并与发布需另行授权。
