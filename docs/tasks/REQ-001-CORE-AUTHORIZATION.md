# REQ-001 — 核心请求授权临界区优化

- 模式：指挥（用户明确调用 `$orchestrator`）；总指挥／唯一状态维护人：当前 Session。
- 分支：`codex/perf/core-authorization-critical-section`；Worktree：`D:/SpeechFUL/.worktrees/req-001-core-authorization`；PR：未创建。
- 实际基线：`69d2adcf4b153601ba218de87bb6efccd91da5c8`；2026-11-15 只读核对 `D:/SpeechFUL` 的 `main`、`origin/main` 与远端 `zewbby/SpeechFUL-Develop` 的 main 相同，原工作区干净。
- 授权依据与边界：用户先要求规划，随后明确调用 `$orchestrator` 并要求“按这个计划开始实施需求001，先完成基线和‘基座＋评论读取’，验收通过后继续接入首页和图片”。已授权隔离实现、验证、必要本地提交及多 Session 协作；关键事务设计与最终安全审查指定 GPT-6 Astra＋xhigh。Push、PR、合并和部署仍未获授权。
- 本轮规则版本：`69d2adcf4b153601ba218de87bb6efccd91da5c8` 的 AGENTS.md、CONTRIBUTING.md、仓库 `.agents/skills/orchestrator/SKILL.md` 及 references。能力：可创建子 Agent、传递消息、读取结果；每位写入执行者使用独立分支与 Worktree。
- 需求来源：用户提供的 `C:/Users/24237/Desktop/需求/01-core-authorization.md`，标题“核心请求授权临界区优化”，对应 P0-01。附件为方案草案；其中流程文字不视为执行、部署或扩大范围的授权。
- 需求确认：2026-11-15，用户在两项结构化问题中明确选择：①共用两阶段基座＋评论读取先验收，再接首页和图片，最终完成需求001整体范围；②改造路径 Gate 实际持锁 p95 降低至少50%、其他用户首页 p95 降低至少30%，均作为最终硬门槛，负载和数据规模在基线阶段固定。当前无影响本计划的未决产品取舍。
- 验证判断补充：用户要求反复性能失败却无明显原因时及时停下重思方向，并明确由总指挥根据证据判断，不能因这一提醒直接停工或机械新增“首次未达即停止”。预先固定的重复轮次与失败后无新假设的重复重跑分别对待；根据失败是否重复、新线索及验证价值决定下一步，不能挑选成功轮次替代失败。
- 更新日期：2026-11-15。
- 状态：M1 功能／安全聚焦验收 PASS，性能验收 BLOCKED（WSL 三钟不一致）；隔离 Linux CI 对照入口已完成本地准备，远端产品／性能 CI 尚未执行。M2／M3 仅完成只读关键设计，源码接入未开始；未合并；未发布。

## 目标与范围

在保留最终 C Safety Gate、可信时间、会话状态／代次、资源归属和当前可见性判定的前提下，把重读取从全局授权临界区移出，降低不同用户之间的请求排队。

本任务交付共用两阶段读取接口，并依次接入评论、首页和受保护图片读取。写操作的最终授权、事务提交、anchor 持久化与失败补偿继续遵守原契约；只外移无副作用的准备工作。

需求002的完整首页批量查询优化、需求003的独立索引／评论查询优化、需求004的衍生图缓存及各自性能指标属于后续任务。本任务包含满足001所必需的批量最终重验和范围版本维护，避免把锁外全量扫描搬回最终事务。

## 已核实现状

- [CommitAuthorized](../../services/api/internal/authprivacy/authorization_gate.go) 先取得全局单行 Gate 锁，在 anchor 文件锁内执行最终业务回调，再持久化检查点并提交 SQL；业务回调耗时会影响其他用户。
- [withPostSessionAtPrepared](../../services/api/internal/authprivacy/community_posts.go) 已固定调用者账号、限制与会话锁顺序，并保证受保护结果在最终提交成功后释放。既有 `postSessionPrepare` 在账号锁之后、Gate 之前运行，不等同于本次所需的独立只读准备事务，不能直接把重读取塞进此钩子。
- [候选授权预检](../../services/api/internal/authprivacy/community_post_candidate_gate.go) 已实现原生 Gate 的短预检；自定义 Gate 保留 Snapshot 契约。[既有回归](../../services/api/internal/authprivacy/community_post_session_commit_test.go) 已覆盖单次成功请求的一次检查点及提交清理。
- [评论快照读取](../../services/api/internal/authprivacy/community_comment_snapshots.go) 的候选检索、排序、快照准备及本页投影仍在最终业务回调内；同时存在 PG／Redis 路由与旧游标路径，必须保持协议一致。
- [首页读取](../../services/api/internal/authprivacy/community_posts_read.go) 的列表及公开投影仍在业务回调中。同一 ReadPosts 入口还承载浏览计数和任务物化等写行为，需按实际语义分流，不能按函数名整体移入只读阶段。
- [图片读取](../../services/api/internal/authprivacy/community_post_images.go) 的源字节读取在最终业务回调内；缩略图转码已经在 SQL 外，并在转换后再次授权，本次应复用这条安全约束。
- [readtiming](../../services/api/internal/readtiming/readtiming.go) 已有 Gate、anchor 与提交分段，但 `gate_commit_authorized` 含锁等待，不能代替实际持锁指标。
- 附件引用的“统一验收口径 README.md”未出现在用户提供的目录中。本次已明确确认的指标以用户上述回答为准，不推断缺失文件中的其他条款。

## 接口与依赖

建议采用内部 `PrepareRead → FinalizeRead` 契约，不改变外部 API 的响应语义。

1. **预检**：复用原有限流及短授权预检，读取当前会话／归属候选；不续期、不发布受保护数据。原生与自定义 Gate 的既有行为分别保留。
2. **PrepareRead**：独立、限时的只读一致性事务；建议采用 pgx RepeatableRead＋ReadOnly，并保留现有超时约束。不持账号写锁或 Gate 行锁，完成候选、批量投影和排序，保留内部准备结果及业务错误候选，不对外释放正文、字节、资源存在性或游标。
3. **准备结果**：绑定调用者、查询／分页条件、候选资源 ID、内容版本、排序／过滤依赖与候选范围版本；列表范围须包含 lookahead 和成员变化，不能只验证选中行仍存在。评论快照与图片内容版本分别使用适用的绑定。
4. **FinalizeRead**：沿用原锁顺序取得账号／会话锁，再进入最终 C Gate；以最终可信时间核验权限、期限、代次、资源与全部版本。版本读取与相关写入口采用一致锁序或同事务围栏，封闭“检查通过后、提交前变化”的窗口。锁内只做有界批量重验及必要写入；不再全量检索／排序。
5. **冲突与失败**：首次版本冲突回滚后在锁外重建一次；第二次冲突沿既有失败类别终止，不返回旧候选，不续期，不因正常冲突触发安全冻结。撤销、冻结、业务不存在和完整性错误分别沿原授权与错误规则裁决。
6. **发布**：只有 CommitAuthorized 明确成功后才释放响应。PG／Redis 快照沿用既有 Prepare／Publish／Abort、nonce、配额、TTL、MAC 与失败补偿；准备结果不得提前变为可读快照。外部存储操作沿原未发布／补偿协议。

版本方案先形成“依赖 → 版本作用域 → 全部写入口 → 锁序／围栏 → 验证用例”清单，再实施迁移。优先按帖子／楼层、频道候选范围及观看者过滤作用域维护，防止引入跨帖全局版本写热点；覆盖客户端、worker、审核、删除、编辑和拉黑等相关变更，并与业务变更同事务推进。计数行热点和冲突率纳入性能验证。

## 实施计划

| 阶段 | 工作与产物 | 完成条件 |
| --- | --- | --- |
| M0 基线与依赖清单 | 核实实施时 main 是否前进；补充锁等待、真实持锁、anchor I/O、连接池等待、准备／最终阶段和冲突次数指标；固定数据种子、请求比例、并发、预热、测量时长、连接池和重复轮次 | 同一测量代码与环境下可重复运行旧路径；形成版本依赖及锁序清单 |
| M1 共用两阶段基座＋评论 | 完成内部接口、版本与迁移／权限检查；先接评论首屏，再接续页、回复预览／展开与定位，兼容 PG／Redis 及旧游标 | 至少一条真实评论端到端链路通过；基座不得仅靠 mock 宣告完成；首个里程碑按已确认范围验收 |
| M2 首页接入 | 将首页相关候选和投影移至只读阶段，最终核验过滤、排序、成员范围与 lookahead；逐一核对关联列表模式，副作用留在最终事务 | 原顺序、过滤和游标推进保持一致；不因移除失效候选而错误结束分页；其他用户首页收益单列 |
| M3 图片接入 | 外移受保护源字节读取及必要准备，绑定帖子／评论、内容版本和可见性；缩略图复用锁外转码并在其后最终重验 | 生成／读取期间撤销或资源变化均不释放旧字节；访问期限和原图字节保持原契约 |
| M4 完整验收与回退 | 执行故障交错、真实 SQL、模块产品 CI 和同负载性能对比；按模块提供开关并验证旧路径回退及既有版本／游标兼容 | 安全与业务回归通过，两项硬性能门槛同时达成，证据绑定最终代码；缺项保持待验 |

### 执行契约 v3

- D1 关键事务设计：GPT-6 Astra＋xhigh，只读核实全部评论读取、写入口、版本作用域与锁序，给出可直接实施的 M1 契约和风险结论；不修改源码和任务记录。
- B0 基线：独立执行分支负责测量口径、最小可重复混合负载基线及任务专用验证环境；在 D1 确认前可调查和构建非侵入式 harness，不修改授权／事务语义。仪表实现范围为 readtiming 及所必需的授权测量钩子，须与 D1 协调文件所有权。
- 总指挥：维护本记录，准备集成与 Linux 验证环境，审清代码及现有回归，D1 交付后固定新接口契约，再安排 M1 实施；不让 M2／M3 绕过 M1 的阶段验收。
- 写入执行者不得修改本任务状态文档；交付提交、聚焦验证、证据位置和缺口，由总指挥及时集成。每次契约变化固定提交并通知受影响执行者。
- D1 的 Astra＋xhigh 初步设计已固定以下 M1 接口：新共用 helper 完成可信预检、token／账号／会话代次绑定、独立 RepeatableRead＋ReadOnly 准备、最终 withPostSessionAt 授权和一次冲突重建；准备错误保存在私有 plan 中，在最终授权后裁决。最终资源版本使用普通 SELECT，复用同一原生 C Gate 对业务写的事务围栏，禁止在 Gate 后新增其他作者账号／身份锁。未知自定义 Gate 保留旧读取路径。
- 版本表契约：`c_comments.read_scope_versions(post_id,root_id,membership_revision,order_revision)`（零 UUID 表示主评论范围）；`c_comments.read_post_versions(post_id,visibility_revision,count_revision)`；`c_comments.read_comment_versions(comment_id,projection_revision,like_count)`；`c_posts.read_identity_versions(identity_id,projection_revision)`；`c_posts.read_account_versions(account_id,projection_revision,visibility_revision)`。均无跨账号 FK；缺行=0仅适用于确实不存在的资源／范围，现存资源缺必需版本行须失败关闭，不能把损坏标记当稳定0；迁移回填已有数据，触发器同事务维护，runtime 仅 SELECT。初建验证范围 membership 与适用 order，续页／已复用 nonce 不因历史 order 变化重建；点赞计数和本人点赞状态在最终事务按扫描页 ID 有界刷新。
- Redis Prepare 与 PG INSERT 在 M1 保留最终授权回调内，以保留最终可信时间、nonce 并发与跨 PG／Redis 配额协议；重候选、排序、Load／Lookup 与投影外移。快照 Publish 只在确认 SQL 提交成功之后；失败／panic 的新建准备由 defer 补偿，已复用／已发布条目不得删除。
- M1 执行者 owns 新基座文件、评论快照／legacy／定位适配、CommentConfig 与 commentServices 的 `PreparedReads` 开关和新聚焦回归。总指挥 owns 0040 迁移、源表触发器、schema／grants／runtime 配置接线；B0 保留仪表文件所有权。`comments.preparedReads` 默认 false，显式启用并在缺失必需版本结构时启动拒绝；关停走原读取路径但继续维护版本。
- 围栏假设：Astra 核查到 M1 依赖的生产公开数据变更均在同一 C Gate 最终业务事务内；迁移／seed／owner SQL 不能作为并发生产写。版本触发器本身不是任意直接 SQL 的并发围栏。Redis Collect／Drain 是独立存储变化，最终阶段须重验快照存活、epoch 和 TTL。M2 的 ranking worker 直接提交 derived hot_*，待 M1 验收后单独设计其围栏。

### 后续接口预案（仅设计，实施仍依赖 M1 验收）

- D2／D3 关键事务设计由 GPT-6 Astra＋xhigh 只读完成，绑定 M1 产品内容 bf76d2a（原始调查基线5ba8a47）；以下尚无 M2／M3 实现或通过证据。
- M2 范围为 PostFeed／PostChannelFeed 与独立 ReadRankings；保留当前推荐／最新共用发布时间时间线、热榜独立冻结快照的关系。author／own／liked／favorites、浏览写、私有任务物化、capabilities 和独立 interactions 暂留旧路径，并分别报告性能成本。
- M2 新增 `c_posts.read_feed_scope_versions(channel_id,membership_revision,publication_revision)` 与 `read_feed_post_versions(post_id,projection_revision)`，无跨账号 FK。初建校验相关频道两种范围版本；固定 ceiling 的续页可忽略更新帖的 publication revision，仍核对 membership。覆盖 lookahead／未返回候选；帖子编辑／当前选中媒体变更推进逐帖 projection，互动不推进；作者、账号及双向 block 复用 M1 版本，过滤另绑定 feed_preferences.revision。源触发器与受审函数完整性／只读权限检查按 M1 同等要求实现。
- 热榜 worker 的提交仅插入新不可变版本及清理派生数据；准备将元数据、分片映射和全部候选搜索固定在一致性读取内，最终按 generation／ValidAt／168小时时间边界、相关频道 membership、viewer 过滤与帖子 projection 证明结果。物理缓存淘汰不撤销已加载且逻辑有效的私有名单，沿现有契约不把 worker 搬入 Gate；不把缓存元数据匹配声称为完整 payload 认证。
- 基座保留 M1 wrapper，内部计划支持 `AfterPrepare`（RO彻底结束后、任何写锁之前）、`Revalidate`、`Complete` 与 `Release`。最终授权后先重验资源，再裁决 CPU 准备错误；Release 不清零已交给成功响应的数组。评论原有 Publish／Abort ownership 保留。
- M3 范围为帖子 manifest／original／thumbnail 与评论 original；私有读取后关闭 RO，再锁外转码，只有一次最终业务检查点。最终点查当前媒体选择、digest／长度／MIME／元数据，不能只信可能被编辑暂存重新使用的 content_version_id。Manifest 完整绑定历史最多9图的顺序；继续原租约／no-store及过滤语义。上传／grant／清理等写、ReadPostImageUploads 的 stops 物化及独立头像契约保留旧路；不新增004的缓存或评论thumbnail接口。
- M2／M3 使用既有 SERVICE_UNAVAILABLE／RANKINGS_UNAVAILABLE 类别处理正常冲突，M1保持COMMENT_SNAPSHOT_UNAVAILABLE；不冒充授权Gate故障。现客户端普通feed／帖子媒体读取会把SERVICE_UNAVAILABLE转会话暂停，需要仅在纯loadTimeline catch／纯_readMedia上下文窄修复；鉴权或无可信code的错误继续原会话处理，命令未知结果不改。此项用于落实001“正常冲突不得安全冻结”，需补聚焦移动端回归与适用构建。
- 独立模块开关默认关闭；M2与M3启用分别检查所需版本schema，关闭时继续版本维护并走旧授权路径。接口细节在派工前固定为下一版执行契约。

## 验收标准

- 在准备后、最终重验前，以及最终重验与相关写事务交错的窗口，通过确定性屏障注入注销、会话撤销／过期／换代、账号关闭／处罚、Gate 冻结／换代、删帖删评、根评论隐藏、编辑、拉黑和筛选变化；不得泄漏内容、字节、存在性或续期。
- 覆盖只改变候选范围但未改变已选中资源的场景；证明新增／删除／排序变化不会造成静默漏页、重复或提前结束。评论保持快照冻结顺序及现有重新进入语义。
- 复用并扩展 community_post_session_commit_test.go，覆盖成功、拒绝、panic、取消、提交结果未知和自定义 Gate；保持单次成功业务请求的一次最终检查点约束。两次正常版本冲突不误冻结、不无限重试。
- Gate 等待与实际持锁分别计时；实际持锁以取得 Gate 行锁至事务提交／回滚为区间，anchor I/O 和池等待单列，分模块记录 p50／p95／p99、错误率、冲突／重建率及资源占用。
- 在固定混合负载中设置独立用户执行首页、重评论、图片读取及点赞写入；用相同种子、连接池、请求比例和采样口径比较旧／新路径，多轮重复。Gate 持锁 p95 降低至少50%，其他用户首页 p95 降低至少30%，均为最终硬门槛；不得靠提高失败率或降低负载达标。
- 锁内业务查询与返回页大小有界，不随全站历史增长；以评论50／1,000／10,000条、首页20／50条及历史量增长场景验证，候选全量排序须保持在锁外。锁外阶段也保留时间、数量和并发预算。
- 数据库及迁移使用明确归属的一次性 PostgreSQL，涉及快照路由时使用任务专属 Redis。WSL2 Linux 文件系统运行服务端／POSIX fixture。完成受影响的 gofmt、构建、go test、go vet、并发回归与产品 CI，不能将无 DSN 的跳过测试视为 SQL 验收通过。
- 按模块关停优化后回到原授权路径，既有 PG／Redis 快照、游标和新增版本维护继续兼容；回退及故障补偿同样须实际验证。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 事实调查 | Windows；D:/SpeechFUL；基线 69d2adcf4b153601ba218de87bb6efccd91da5c8 | PASS：核对根目录、工作区、分支、远端 main、Worktree、相关模块与产品 CI 入口 |
| 计划与确认 | 2026-11-15 当前用户消息及两项结构化回复 | PASS：确认阶段顺序与最终硬门槛；本记录为本任务唯一计划和状态入口 |
| 关键事务设计 | GPT-6 Astra＋xhigh；v3 4a145f45 | PASS（设计审查）：确认八类 M1 生产源写共用 C Gate，明确直接 owner SQL 不在并发业务假设内；不替代产品验收 |
| 仪表 | 原执行提交 e8aeadd；集成 9de07c7 | PASS：真实 SQL 锁阻塞＋Abort、单检查点与成功／拒绝／panic／取消聚焦回归；/home/hnuhole/req001-baseline-20261115/artifacts/observation-sql-tests.log。客户端观察边界为锁查询成功响应至事务结束响应，非数据库内部纳秒精度 |
| 旧路径主基线 | 执行源码 5c3e9a8；WSL Linux；真实 PG16／Redis／Pillow；GOMAXPROCS=4、12连接、4用户四路径1:1:1:1、1000评论＋1000条评论点赞、20帖、10预热＋80测量波、三轮 | 历史运行 PASS：三轮均320请求、0失败。评论每请求累计持锁p95为144.60／154.10／137.59ms，另一用户首页p95为250.16／249.52／232.33ms；每次读含两次Gate锁。该主负载复用Redis nonce、并发写为同帖的帖子点赞，不冒充fresh初建或评论排序冲突验收。追溯无大于250ms波间异常，但当时无逐请求三钟结束边界，不作为当前稳定环境硬门槛证明 |
| 基线规模检查 | 同源码；50／10000评论；各8波 | 历史通路0失败；10000条cohort追溯发现约10.980秒异常墙钟缺口，环境 INVALID，不用于性能结论。50条仅通路／规模检查，8波不足以单独证明p95门槛。原文件保留于/home/hnuhole/req001-baseline-20261115/artifacts |
| M1版本／权限基座 | 51dc950＋83fdd7a；/home/hnuhole/req001-integration-20261115；一次性PG55533 | PASS：真实-race SQL发布／点赞依赖分离、回滚、历史回填；runtime只读、角色审计、列级越权、WHEN(false)／空函数体负例。schema-tests.log与schema-audit-tests.log。无HTTP用例时明确显示no tests to run，不计HTTP通过 |
| M1读取切片 | 执行 a942d32b；集成250b9b4；产品最后变更bf76d2a | 已接入ReadComments主评／回复／续页与LocateComment；未接入私有任务／ReadCommentContext。功能与阶段安全聚焦证据如下；联合验收仍受性能及远端CI门槛限制 |
| M1功能／HTTPS／原生生命周期 | 产品bf76d2a；测试f5d46e2＋4e89783；HnuHole-Ubuntu-24.04独占SQL／Redis | PASS：三后端分页／回复／定位／回退、版本交错、过期／换代／封禁／注销申请、原生取消、真实COMMIT成功后丢ACK；后者允许已持久合法续期，但不返回正文／游标、不Publish新快照，补偿只影响新reservation。root HTTPS原／新两路主评／回复／nonce／续页／存储失败PASS；全后端build／vet PASS。日志在/home/hnuhole/req001-comment-reads-20261115/与/home/hnuhole/req001-integration-20261115/comment-https.log |
| M1独立安全审查 | GPT-6 Astra＋xhigh；69d2adc→4e89783 | PASS（AI审查证据）：原定位回复恢复后旧404的P2已由bf76d2a修复且精确回归通过；原始日志／关键Linux文件摘要已核对，无未关闭确定缺陷。不代表GitHub成员批准或未测所有细粒度交错 |
| 全后端单测 | 集成35941b5；WSL Linux；显式无外部DSN | PASS：go test -mod=readonly ./...；SQL用例按配置SKIP，不替代上方真实SQL证据。/home/hnuhole/req001-integration-20261115/unit-and-skipped-sql.log |
| 性能诊断 | old84-fresh-likes与new0d-main-r3 | FAIL：旧wave27 feed／like两503，新wave50 image／like两503，Gate均OPEN；新SQLSTATE=57014。两波恰伴墙钟较Go／RAW多约11.145／11.217秒，真实10s SQL超时可能受环境时间不连续影响，具体原因待Message确认。其他成功cohort保留原证据，不剔除失败样本、不把部分轮次达门槛报整体PASS；B0补请求三钟guard和固定错误分类。汇总/home/hnuhole/req001-baseline-20261115/artifacts/b1-diagnostic-summary.json |
| 三钟环境检查 | harness35941b5；同一WSL进程启动；独立纯计时复核 | BLOCKED：新主负载无请求／预热失败，但cohort墙钟／Go为12.356秒、RAW为13.479秒，环境INVALID。独立约5秒探针复现RAW／Go约1.090908，最大读钟括号不确定性4695ns；只读adjtimex显示tick=9167，不能归因于读钟起止调度。未修改系统时间、clocksource、超时或重试策略。原始b1-clock-environment-summary.json、pure-clock-probe.json与clock-retrospective-audit.json均保留 |
| 隔离CI本地准备 | 4029181＋a9e1e63（原d352c22＋c0f09bad）；Linux与Windows聚焦检查 | PASS：Linux13项全通过，含真实leader退出后的后代清理；Windows10 PASS／3平台SKIP。精确旧69＋6文件白名单overlay、新4029181双archive编译PASS，performanceResult=NOT_RUN。4个仪表文件另固定已审内容SHA，防后续业务语义误入旧树。四项CI审查P2（链接图逃逸、超时丢已有样本、父进程退出后遗留后代、未知kind异常未裁决）均已修复并补负例。/home/hnuhole/req001-ci-prep-20261115/linux-unit-c0f09ba.log与ci-prep-validation-evidence.json绑定最终runner／tests字节；编译证据archive-compile-check-final/public，编译后唯一脚本统计保留修正不涉及Go源码或archive／compile路径 |
| CI入口独立复核 | GPT-6 Astra＋xhigh；a9e1e63 | PASS（AI审查证据）：四项P2关闭，固定仪表SHA、完整配置／工具版本、全部失败样本保留及精确脱敏产物均核对；建议启用入口。仅覆盖CI代码，不代表性能达标、远端运行或GitHub成员批准 |
| 远端CI／合并／发布 | 未推送本任务分支 | NOT_RUN；本地产品检查与远端CI分别记录；未合并、未发布 |

## 阻碍与下一步

当前阻碍为WSL墙钟／Go monotonic与RAW时间不一致，现环境不适合证明性能硬门槛。B0与Astra已只读复核跨旧／新路径的失败及异常时间缺口；PG16绝对墙钟超时可解释短RAW耗时伴57014，但缺失败时服务端Message，具体取消来源未完全证实。停止在此环境重复性能采样，不放宽SQL保护、校正耗时或以重试吞错，也不改共享系统时钟。

专用GitHub Ubuntu隔离CI的本地代码、聚焦回归与新旧archive编译已准备好：固定基线69d2adc与精确PR head，旧树仅白名单覆盖仪表／harness，三组主负载逐对判定50%／30%硬门槛，fresh与规模检查独立报告，错误与三钟异常均拒绝；不机械以单次阈值未达停止预先固定的三组对照。原始日志／数据库／证书留在一次性runner，上传仅固定脱敏JSON。下一步按仓库规则请求本任务Push／草稿PR／CI授权；尚未创建远端分支或PR。M1阶段验收通过后按已有授权继续M2／M3。版本触发器仅在停写／受控迁移事务中安装，未接触正式数据。
