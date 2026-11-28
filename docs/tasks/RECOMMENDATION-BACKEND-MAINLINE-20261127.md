# RECOMMENDATION-BACKEND-MAINLINE-20261127 — 推荐后端接入当前主线

- 模式：常规
- 负责人／状态维护人：当前 Session
- 执行 Session（指挥模式）：无
- 分支／Worktree／PR：`codex/feat/recommendation-backend-mainline`；`E:/speechful-recommendation-backend`；基线 `develop/main@0ff400bf1676cc2d716224abdd282661f5ca9d5f`（任务开始时为 `f6b2419e666ccf73035bb2e4cf769a77cfeeb49c`，推送前 rebase 到最新 main）；代码 head `a257f69`（PR 审查修复；随后的任务记录提交另计）；草稿 PR [#45](https://github.com/zewbby/SpeechFUL-Develop/pull/45)
- 本轮规则版本（指挥模式）：不适用
- 授权依据与边界：用户 2026-11-27 指令：使用交接包 `speechful-recommendation-backend-handoff-20261127.zip`，拉取最新远端 main 并从它创建独立功能分支；按包内 README 检查并应用 `recommendation-backend-mainline.patch`，处理冲突时以当前主线为准并重核 Goose 迁移编号；复用 #43 已合入的排序、去重、轮次模型和编解码，接通 PostgreSQL、候选召回、推荐上下文、建轮／翻页／反馈 API 和运行时；推荐默认关闭并保留 C Gate、会话绑定、共享限流、到限拒绝和未知写处理；保留首页续页预览／补读与时间序 Feed 行为；在一次性 PostgreSQL 环境做功能回归；正式验收留项目服务器并在 PR 标为待验。用户 2026-11-28 指示“推送pr”，据此推送独立分支并创建草稿 PR；同日指示“可以修复一下这个 PR”，据此修复本轮只读审查在 PR #45 发现的问题并更新该草稿分支。未授权合并 main、部署或修改正式数据库；`legacy-reference/` 仅供查阅。
- 需求确认：无未决取舍。频道上限按主线频道目录改为 10；候选召回与普通 Feed 一致地过滤账号隐藏、审核隐藏、屏蔽、拉黑和已擦除内容；推荐默认关闭，只有显式配置、容量画像、传输密钥和 C-only 服务同时满足才可启用。
- 更新日期：2026-11-28
- 状态：实现 已完成；验证 PASS（本地一次性环境与适用 CI；正式服务器验收 NOT_RUN）；合并 未合并；发布 未发布

## 目标与范围

- 在 `develop/main@0ff400b`（任务开始时为 `f6b2419`）上接入交接包的推荐后端：PostgreSQL 状态与清理、候选召回、推荐上下文、建轮／翻页／反馈 HTTP API、运行时装配，以及 Goose 迁移 0056–0058。
- 复用 #43 已合入的 `Select`、`roundmodel`、AES-GCM `transport` 与合成输入，不重新实现排序、去重、轮次模型或编解码。
- 迁移链编号对齐当前主线（原链止于 55），支持空库安装与从 55 升级到 58；0056–0058 只允许前向修复，失败的部分降级不得改变账本或配额。
- 修复交接补丁的 7 频道上限，使推荐轮次与主线 10 频道目录一致；单频道、部分屏蔽、全部屏蔽、作者拉黑、账号隐藏和审核隐藏均按当前 Feed 语义生效。
- 推荐默认关闭；启用仍要求显式配置、已测量的容量画像、传输密钥和 C-only 服务。保留 C Gate 最终业务授权、会话代次／绑定、共享限流、到限拒绝和未知写处理。
- 普通 Feed 与预备 Feed 在最终授权通过后返回推荐上下文；Feed 响应体、游标、刷新行为保持兼容。首页续页继续返回 `X-Feed-Continuation-Extras: previews-v1` 的同页互动与图片预览，缺少缩略图时走原有纯读补读。
- 不包含：正式服务器验收、生产容量结论、合并、部署、正式数据库操作；`legacy-reference/` 不纳入构建或运行。

## 接口与依赖

- Feed：`GET /api/v1/feed`（普通与预备计划）在最终授权后增加不透明推荐 Header；响应体与游标不变。
- 推荐：`POST /api/v1/feed/recommendation/start`、`/page`、`/feedback`，使用 `Recommendation-Context`、分页游标和反馈回执；限制请求体 16 KiB，错误码覆盖 token 无效、过期和作用域变化。
- 迁移：`0056_recommendation_state.sql`、`0057_recommendation_logical_bytes.sql`、`0058_recommendation_capacity_ceiling.sql`，Goose 最大版本 58；依赖当前主线的社区、会话代次与 C Gate 结构。
- 运行时：默认关闭的推荐配置、共享限流和清理 worker；启用需要显式配置、容量画像、传输密钥和 C-only 服务。
- 现有首页续页：`X-Feed-Continuation-Extras: previews-v1`、`FeedWindowPreviews` 与无缩略图时的纯读回退；不改变时间序 Feed 的响应、游标和刷新语义。

## 验收标准

- 空库安装得到 Goose 58，推荐控制面默认关闭；从 55 升级到 58 保留既有账号与数据，受限运行角色不能写控制面或绕过 schema 契约。
- 普通与预备 Feed 在最终授权通过后返回有界推荐上下文（10 分钟窗口），旧响应体结构、游标和刷新行为不变。
- 建轮返回 10 频道范围内的帖子；单频道请求只返回该频道；部分屏蔽为剩余频道，全部屏蔽为空轮；作者拉黑、账号隐藏和审核隐藏的帖子不会出现在推荐轮次。
- 同一意图重试复用原轮；翻页与反馈使用同一轮次状态；反馈只记录已交付曝光并真实落库；跨账号使用上下文、游标或回执被拒绝。
- C Gate 冻结或取消时不提交推荐状态；会话撤销、替换、关闭、作用域变化和到期后，旧凭证被拒绝。
- 共享限流和容量到限返回拒绝；到期清理按预算回收轮次、回执、曝光和墓碑，且不破坏后续准入。
- 首页续页在 `previews-v1` 下同页返回互动与图片预览；无缩略图时回退到原有纯读，不伪造预览、不改变分页。
- 不把本地一次性环境或协作 CI 结果当作项目服务器验收；正式容量、72 小时曝光保留和 Gate 状态在服务器上单独验收。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | 基线 `0ff400bf1676cc2d716224abdd282661f5ca9d5f`（任务开始时 `f6b2419e666ccf73035bb2e4cf769a77cfeeb49c`）；实现提交 `13684fc7b5bc1c1a99d29a26aec4e9185be5ed79`（55 个文件，6212 行新增、58 行删除） | 交接补丁 46 个路径纳入后，补齐 10 频道、账号隐藏过滤、续页回退测试、OpenAPI、迁移 0058 前向降级和迁移版本断言。`legacy-reference/` 未纳入。推送前 rebase 到最新 `main`；上游两个提交仅改管理台界面与审核任务文档，Go 后端无差异。 |
| 修复：清理预算 | 提交 `24f71bb`（2 个文件，+38/−3） | CI `feed-postgres` 清理测试偶发超时：`CleanRecommendation` 的 2 秒协作预算从 Gate 预检之前开始计时，慢预检会耗尽整轮预算；改为预检后才开始计时，并保证至少尝试一组，父上下文取消仍立即停止。新增 `slowCleanupSnapshotGate` 与 `TestRecommendationCleanupPreflightDoesNotConsumeBudgetPostgres`。 |
| 修复：还原后 schema 契约 | 提交 `0bac1c1`（2 个文件，+44） | 预备演练在备份→还原后的 C 实例上稳定失败（readiness 非 200）：`pg_dump` 输出的 `pages_check` 去掉冗余内层括号，`pg_restore` 按该文本解析成扁平 AND 列表，schema 契约的精确集合比较因此拒绝了语义完全相同的还原库。契约仅额外接受这一确切拼写（上限被改仍拒绝），并加 `TestRecommendationPagesCheckAcceptsDumpRestoreSpellingPostgres` 覆盖接受与拒绝两侧。 |
| 修复：PR 审查（投影与公开边界） | 提交 `a257f69`（8 个文件：4 生产、3 测试、1 OpenAPI；+223/−52） | P2：最终业务投影用与 Feed 同源探测的 `hidden_posts` 扩展按当前私密切换过滤账号隐藏帖；账号隐藏同时推进 `feed_preferences.revision`，旧上下文／游标／回执按既有 `RECOMMENDATION_SCOPE_CHANGED` 失败关闭，投影过滤是最终授权事务内的纵深防御。P3：未装配推荐运行时不发任何 `Recommendation-*` 头（已装配但关闭仍报 `Available=false`）；`RevokeRecommendation` 移出生产构建、只留在 test-only 桥接；OpenAPI 对齐同意图重放与 create-before 后新意图 409、空 `postIds` 无曝光 ACK、隐藏帖与 Header 语义。 |
| 审查修复回归 | 提交 `a257f69`；一次性 PostgreSQL／真实 HTTPS；受限运行时角色 | PASS：`TestRecommendationProjectionAccountHiddenPostgres`、`TestRecommendationHTTPSAccountHiddenInvalidatesRoundPostgres`、`TestRecommendationHTTPSUninstalledEmitsNoHeadersPostgres`。直接投影在隐藏后返回 9 items 且 `Unavailable=[2]`（恢复可见后回到 10）；旧 start／page／feedback 引用均 409，重新取上下文后新轮次不含隐藏帖；未装配部署 Feed 五个 `Recommendation-*` 头全空且 start 返回 503。 |
| Feed CI（审查修复后完整套件） | 提交 `a257f69`；`authlab/run-feed-isolated.sh`；`FEED_TEST_RACE=1`、`-p 1`、30m 超时；一次性 PostgreSQL 16.15／TLS／隔离角色 | PASS：`EXIT=0`，四个包均 `ok`（authprivacy 370.1s、authprivacyhttp 25.6s、authprivacyruntime 6.8s、rankings 1.0s）；158 个顶层 PASS、0 FAIL、12 SKIP（媒体／Dart／Redis／性能夹具未请求，及一项可选计时诊断）。含全部 `TestRecommendation` 与新增三项回归。 |
| 补丁检查与迁移编号 | 基于 `768e8ef` 的补丁对 `f6b2419` 检查 | `git apply --check --index` 未直接通过，报 `community_feed_prepared.go: patch does not apply`；按 README 的冲突路径以当前主线为准解决后应用，Goose 编号重核为 0056–0058，链最大版本 58。 |
| 正式 Goose 安装／升级 | PostgreSQL 16.15；一次性 Unix socket；受限运行角色 `hnuhole_c_runtime`；Goose v3.22.1 | PASS：`TestRecommendationFormalGooseEmptyInstallAndMainlineUpgradePostgres` 的 `empty_install` 与 `mainline_55_to_58` 均通过；默认关闭、0058 上限、运行角色 schema 契约与既有账号保留均核对。 |
| 推荐功能回归 | 同一一次性 PostgreSQL；真实 HTTPS；`AUTHLAB_ALLOW_SCHEMA_RESET=1`、`FEED_RECOMMENDATION_OWNED=1` | PASS：`go test -count=1 -v -timeout 30m -run 'TestRecommendation' ./internal/authprivacy`，40 个顶层测试全部 PASS、0 FAIL、0 SKIP，151.652s。覆盖上下文→建轮→同意图重试复用→翻页→反馈、曝光 SQL 落库、10 频道、单频道、部分／全部屏蔽、作者拉黑、账号与审核隐藏、跨账号凭证 409、Gate 冻结不提交、会话撤销／替换／关闭、到限拒绝、TTL 与清理积压。 |
| 推荐 race 复跑 | 最终代码 `0bac1c1`；`authlab/run-feed-isolated.sh`（`FEED_TEST_RACE=1`、`FEED_TEST_PATTERN='^TestRecommendation'`、`-p 1`、30m 超时） | PASS：`EXIT=0`，44 个顶层测试 PASS、0 FAIL、0 SKIP（含新增的还原拼写回归与清理预检测试）。 |
| 预发布演练 | `tools/prerelease/environment.py`；候选 `0bac1c1`，回滚基线 `0ff400b`；五个一次性 PostgreSQL 16.15 实例、mailpit v1.21.8、Pillow 12.3.0、Goose v3.22.1、Go 1.22.2 | PASS：`evidence.json` 中 `result: PASS`，17 项检查全部通过，含空库迁移与 schema13 快照升级、受限角色拒绝不可变列写入、实际启动拒绝缺少图片权限、真实 HTTPS 注册／登录／发帖／图片与拒绝、Gate 冻结、备份还原到两个新实例后数据与权限一致、旧会话被拒而新登录读到原文与图片、旧主程序可在还原库运行、应用回滚后候选可重新部署；结束时五个实例与自有进程已停止。 |
| 首页续页 | 同一 lab；`POST_MEDIA_FIXTURES`／校验器 | PASS：`TestFeedContinuationPreviewsPostgres` 验证 `previews-v1` 同页互动与图片预览，以及移除缩略图能力后回退原有纯读、不伪造预览。 |
| 静态检查 | 最终代码 `0bac1c1`；WSL2 Ubuntu-2404；Go 工具链；`services/api` | PASS：`go test -mod=readonly ./...` 23 个包全部 `ok`、0 FAIL；`go build -mod=readonly ./...`、`go vet -mod=readonly ./...` PASS；48 个改动 Go 文件按忽略 CRLF 方式核对 gofmt；`git diff --check` PASS。 |
| Race | 最终代码 `0bac1c1`；WSL2 Ubuntu-2404 | PASS：推荐 race 套件 44 个顶层测试全过（见上）；此前 `go test -race ./internal/recommendation/... ./internal/authprivacy ./internal/authprivacyruntime` 亦 PASS。`authprivacyhttp` 在跳过既有 `TestDMGovernanceHTTPSPostgres` 后 PASS；该测试直接改写进程级 `time.Local`，完整包运行时的 data race 已在未改动的基线 `f6b2419` 临时 Worktree 复现，非本次改动引入。 |
| OpenAPI | Windows；仓库固定 Python 校验环境 | PASS：`packages/openapi/check-specs.py` 校验 13 个规格全部通过；`feed-api.yaml` 已记录默认关闭、推荐 Header、三个 POST 路径、请求／响应 schema 和错误码。 |
| Feed CI（Feed 范围） | `authlab/run-feed-isolated.sh`；隔离 PostgreSQL／Redis／TLS | PASS：160 个顶层 PASS、0 FAIL、5 SKIP（批量计时诊断、搜索性能夹具、三个缺少 Dart 探针的 HTTPS 测试）。 |
| Feed CI（授权／Gate／Verifier） | 同一隔离 runner；`FEED_TEST_PATTERN='^(TestAuthorization|TestGate|TestVerifier)'` | PASS：67 个顶层 PASS、0 FAIL、1 个按设计跳过的子进程 crash helper。 |
| GitHub CI（PR #45） | 代码 head `0bac1c1`；GitHub Actions 全部 29 项检查 | PASS：28 success、1 skipped（`actual-process-acceptance`，按仓库配置跳过）、0 failure；含此前稳定失败的 `rehearsal`、以及 `gate-postgres`、`feed-postgres`、`go-postgres`、`search-postgres-100k`、`moderation-postgres`、`registration-postgres` 与各 Flutter 检查。 |
| 正式服务器验收 | 项目服务器；原生 J 隔离副本 | NOT_RUN（待验）：保留原 J，准备至少 2,000 条独立混合帖；整请求 SQL 上限建轮 64、翻页／重试／反馈各 40；P95 建轮 ≤350 ms、其余各 ≤180 ms；共享出口 IP 下 300 个活跃账号连续 60 分钟，每人每 30 秒加载 10 帖并反馈全部 10 次曝光，每 5 分钟新建一轮、每轮最多 100 帖；核对 72 小时曝光保留、到限拒绝、清理积压和 Gate 状态。 |

## 阻碍与下一步

本地实现、一次性 PostgreSQL／HTTPS 回归、续页回退、静态检查、推荐 race 套件、完整预备演练、OpenAPI 与 Feed CI 已完成；PR 审查发现的问题已由 `a257f69` 修复，并在同一隔离环境复跑完整 Feed CI（含 race）。修复提交随分支推到 PR [#45](https://github.com/zewbby/SpeechFUL-Develop/pull/45)。正式服务器容量与 72 小时保留验收仍待项目服务器执行，不能由本地结果替代；合并 main、部署和正式数据库操作均未授权。
