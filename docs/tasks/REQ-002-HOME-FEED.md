# REQ-002 — 六类列表批量读取与首页增量分页

- 模式：常规；负责人／状态维护人：当前 Session。
- 分支／Worktree：`codex/perf/home-feed-batch`；`D:/SpeechFUL/.worktrees/req-002-home-feed`；基线 `1d829b2623a6c32830ee1b74fae6c99a436ad3b3`（需求001已合入）；PR 未创建。
- 授权依据与边界：2026-11-16 用户明确要求“按这个计划开始实施，完成六类列表批量读取和首页 10/5/5 分页，再按三项硬门槛验收”。授权隔离实现、必要本地提交和验证；不修改正式数据。尚未授权本任务 push／PR、合并或正式发布。
- 需求确认：用户 Q1 选择六类共用列表一起优化；Q2 选择三项均作硬门槛；后续明确首屏10条、刷新新增5条、续页5条；Q4 选择最新5条先显示、后续刷新补齐中间帖子。刷新不足5条按实际数量，无新帖保留已有列表。六类为首页、频道、作者、我的帖子、点赞、收藏；10/5/5 适用于首页及频道筛选，其他列表原页大小保留。热榜和搜索不扩大范围。
- 更新日期：2026-11-16。
- 状态：2026-11-16用户明确授权04完成后通知02继续验收；04已释放设备及构建／压测资源，GPT-6.1 Sol XHigh 已恢复独立验证。列表及分页实现已完成；性能修复候选已完成并通过必要安全回归，独立验收进行中；原性能验收 FAIL／BLOCKED 保留（见下）；产品CI NOT_RUN；未合并；未发布。

## 目标与范围

消除六类列表逐篇正文、阅读量和图片尺寸读取。首页首屏10条，刷新最多补入5条、保留旧列表；新帖超过5条先取最新5条并保留待补区间，后续分批补齐；向旧方向续页5条。保持发布时间／私有ordinal顺序、图片布局、屏蔽、隐藏、账号级拉黑、作者占位及最终授权事务。

## 接口与依赖

复用需求001两阶段读取和版本围栏，新增首页增量分页协议并兼容旧客户端与游标。首屏和续页页大小衔接不放松游标账号、scope、频道、筛选revision或期限绑定。重验覆盖新旧方向范围、lookahead和过滤依赖；最多锁外重建一次。

## 验收标准

- 六类列表冻结数据逐页对照 ID、顺序、正文、作者、标签、图片尺寸、游标推进语义；0/1/5/10/20/50条、同时间、9图及编辑后顺序。
- 首页10/5/5及新增12条分批补齐，无重复、无漏帖、无提前结束；覆盖切换、刷新、续页、返回、账号切换和过期响应。
- 准备后插入／删除／编辑、隐藏／拉黑／频道偏好变化及会话撤销，最终授权失败不释放内容。
- 硬门槛：20条主体SQL≤6次，50条固定数量；统计候选、投影、图片、偏好／游标读取及最终阅读量，不隐藏重复读取，固定授权／版本证明开销另列。
- 硬门槛：首页及续页接口p95降低≥40%，新旧同页大小、同数据负载与环境；20→10/5页大小变化收益另列。
- 硬门槛：固定设备和网络，“触发加载→卡片可交互”p95降低≥25%，图片预留布局不跳变。缺设备证据保持待验。
- 适用Go／Flutter／API契约／真实PostgreSQL与产品CI，验证绑定被测SHA或基线＋明确差异。

## 当前进度与证据

证据目录：[本机验证产物](E:/Hnuhole-env/req002-home-feed-validation-20261116/)。冻结基线为 `1d829b2623a6c32830ee1b74fae6c99a436ad3b3`，本轮被测差异由目录内 `source-manifest.json` 绑定；承载相同产品内容的提交为 `9eb23a80b42d9b96e3eb9d33725db0c02999c8af`。SQL使用WSL2 Linux文件系统、本任务独立PostgreSQL（55552／55553私有socket）、Go1.22.2；Flutter3.47.5／Dart3.13.4，原pubspec.lock锁定且无依赖升级。真实媒体验证使用本任务独立Python环境及合成图片。未连接正式数据库。

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 六类批量读取 | 基线＋本任务差异 | PASS：类型化正文／作者／标签投影，独立图片几何查询，prepared首页只在最终授权批量读取阅读量；旧路径配置 `posts.legacyListReads=true` |
| 首页协议与交互 | 同上 | PASS：独立新旧方向游标、首屏10→续页5、刷新最新5→缺口5→2→0，保留原列表及旧帖游标；scope／账号／筛选／期限绑定保留。一次冻结的新帖范围补完后再取下一批，避免无限增长的游标状态 |
| 真实SQL与并发 | sql-final.log；`-race`；独立PG | PASS：六类1/5/10/20/50逐页旧新字段对照，冻结时间组私有ordinal排序；新帖插入、lookahead删除、过滤变化、连续两次冲突；三图实际创建及历史九图编辑混合数据、重排与删除全部图片；最终HTTPS增量路径亦PASS |
| 扩大回归 | sql-full-02.log | authprivacy与runtime聚焦集合PASS，覆盖原prepared读取、会话/Gate生命周期、个人集合、偏好、隐藏、互动及升级检查；首轮新增HTTP用例的合成昵称不合法FAIL已修正，并由sql-final.log的该完整真实HTTPS用例PASS关闭。Redis、未编译的旧Dart probe等按配置SKIP，不冒充这些范围通过 |
| 移动端 | mobile-final.log；analyze-final.log | PASS：原119项test（含增量补齐、账号切换过期响应、频道切换、原Feed UI、错误路由及真实loopback TLS传输）；补充1项widget完整“下拉三次补齐→滚动→点击加载更多”路径PASS，增量文件4项全部PASS（mobile-widget-flow-pass.log），产品源码仍为9eb23a8，补充test文件哈希见widget-flow-source.json；analyze无问题 |
| Dart生产传输＋真实HTTPS/PG | performance-03.log | PASS：新增首屏／空刷新解析，原分页与互动路径；原最终事务和prepared两种模式均通过，使用当前源码编译的跨平台Dart kernel。此证据不是手机整机验收 |
| Go与契约 | go-final.log、openapi-final.log、text-contract.log | PASS：全量host `go test -mod=readonly ./...`、build、vet；无DSN用例SKIP。完整OpenAPI及29项保护操作静态契约通过 |
| SQL硬门槛 | sql-final.log | PASS：无图首页20与50条均为3条主体SELECT，最终事务刷新阅读量再加1；有图首页为4＋1。其他五类为固定3～5次。准备／最终资源版本证明各1次、会话与Gate固定开销单列；不把这些重复归入隐藏开销 |
| 接口p95硬门槛 | performance-02.json／03.json；真实TLS＋PG；相同数据61篇纯文本、页大小与配置，legacy/batch交替顺序，每组预热10、80测量、三轮 | FAIL：03轮首页20提升34.37%／42.25%／40.56%，续页20提升29.65%／26.53%／35.35%；首页10提升27.08%／25.81%／26.37%，续页5提升12.60%／18.47%／17.42%，未满足全部≥40%。保留全部原始样本和失败，不挑轮次、不把20→5页大小缩减计为SQL优化提升 |
| 阶段诊断 | profile-01.log；服务方法均值，不能代替接口p95 | 准备阶段旧3.562ms→新1.850ms；新最终Gate持锁6.304ms，其中anchor落盘3.792ms、SQL commit1.182ms。解释小页总耗时受固定授权持久化影响；未修改持久化协议或降低门槛。纯三钟探针约1秒分别1000268569／1000269305／1000270847ns，当前无此前001的明显时钟漂移 |
| Android构建 | build-no-incremental.log；profile APK | PASS：Windows提交内存不足和跨盘Kotlin增量缓存失败记录保留；最终以本任务临时1536MiB heap、2 workers、关闭Kotlin incremental成功，原gradle.properties已恢复。APK位于任务Worktree `apps/mobile/build/app/outputs/flutter-apk/app-profile.apk`，未提交构建产物 |
| 手机p95≥25%与布局 | ADB列表为空 | BLOCKED：已请求用户连接测试Android设备；不能用119项host测试、profile APK、Dart loopback或服务端耗时替代真机时间线 |
| 产品CI | 当前任务分支尚未push | NOT_RUN：已准备Feed产品workflow中的三轮真实HTTPS性能硬Gate，原始样本作为artifact保存；本地性能FAIL会如实导致Gate失败 |

实现新增刷新协议使用新的独立AEAD域，旧客户端及scope不接收新游标；最终提交成功后才释放响应。批量查询依赖现有已验证的edit/tag列，旧schema维持原读取路径，未增加索引或迁移。

### 本轮性能修复候选（Astra XHigh，2026-11-16）

用户追加要求由 Astra XHigh 定位并修复未达40%的原因，再由 GPT-6.1 Sol XHigh 独立测试。执行基线为本分支 `bf6ac5a8a224997b6c19ef957dc05925727f28f6`，进入时工作区干净；产品差异为 `authorization_evidence.go` 的有界签名检查点存储，另有故障回归、冻结版本性能测量和CI接线。确切文件摘要见证据目录 `journal-candidate-source.json`；该文件与承载本段记录的本地提交对应，未push／创建PR／合并／部署。

- **原因：**批量读取已经减少正文查询，但每次最终授权仍执行“临时anchor文件同步→rename→目录同步→SQL commit”。独立分步I/O探针 `anchor-io-01.json` 实测原子替换均值4.068ms，其中文件同步2.103ms、目录同步1.882ms；`fdatasync` 和 `O_DSYNC` 仍约4ms，不能解决固定成本。5条续页中正文查询占比更小，故改善最弱；首页也有未达标组，不能只验续页。
- **修复：**同一个跨进程flock内追加完整签名检查点，每次文件fsync与关闭成功后才允许SQL提交；仅首次创建、旧JSON格式升级和达到128条16KiB记录后的压缩仍走原有原子替换及目录fsync。读取最后确定记录，任何坏尾不回退；完整边界截断由SQL／anchor精确匹配检测并持久冻结。授权、account/session/generation、最终业务事务、可信时间和失败补偿未放宽。共用C/V存储均需回归，具体协议及旧二进制回滚限制见[Gate设计第18节](../design/auth-authorization-safety-gate.md#18-有界签名检查点存储)。
- **基准修复：**共享writer已优化，当前源码的 `legacyListReads=true` 不再代表完整旧版本。新的 `run-feed-performance.sh` 使用完整冻结 `1d829b2` 源码与当前源码，二者只共用同一份测量test；按轮交替旧／新顺序，保留原四组、每组10预热＋80样本及三轮。`compare-feed-performance.py` 校验样本完整性、重算p95并要求所有12项均≥40%；无挑轮次、无页大小替代，原失败样本保留。冻结完整源码位于 `/home/hnuhole/req002-home-feed-20261116/frozen-1d829b2`，来自Windows `git archive`，仅添加同一测量test与来源标记；生产文件没有混入当前优化。

| 候选验证 | 结果与范围 |
| --- | --- |
| 格式、升级、压缩、损坏和并发 | PASS：`journal-focused-03.log`，`-race`；短写／写入同步／关闭失败不确认成功；旧JSON升级、上限压缩、异常头／长度／签名／填充／坏尾拒绝，多实例及四个独立进程序列化，完整记录截断后的真实PG持久冻结 |
| C/V Gate及feed安全回归 | `journal-security-01.log`：59个顶层测试PASS，覆盖取消前后检查点、SQL提交失败冻结、恢复／代次、旧快照、证据失效、多实例及feed prepared候选冲突和生命周期。该aggregate保留FAIL：唯一失败为同步源码后media脚本权限不满足validator要求；恢复本任务Linux media目录禁止组／其他写入后，由 `journal-focused-02.log` 和最终 `journal-focused-03.log` 的完整九图重排／清空测试PASS关闭，不把原aggregate改称全部PASS |
| Go与测量硬Gate | PASS：`journal-go-01.log` 全量host go test；最终build／vet单独成功复核。初次命令在测试／build／vet完成后因shell收尾变量展开报错，未冒充该包装命令成功。性能测量test在完整冻结源码可编译；Python Gate两项测试覆盖全通过、一组未达标、不完整与非法样本拒绝。实际新旧三轮endpoint验收 NOT_RUN，交独立测试执行 |
| 方向诊断 | `journal-focused-01.log`：候选writer下旧列表flag总均值15.453ms、batch13.585ms，anchor约3ms；两边都已用候选writer，且同一WSL存在REQ004压测及Gradle构建，因此仅作诊断，不能与旧日志跨时段计算验收收益，也不能证明≥40% |
| 手机环境 | 曾无ADB设备的旧BLOCKED证据保留；本轮发现在线V2323A，但REQ004正在同设备集成任务，未抢占、安装或断开连接。固定设备／网络p95及无跳动仍待独立验收 |

### 独立验证（GPT-6.1 Sol XHigh）

被测产品为`64c019e680ff32448e6a770a6170f4892aad20ef`。本阶段仅扩充测量test／runner，没有修改产品。新增真实协议首屏10、旧续页5和最新刷新5；两侧均为49篇后再发布12篇的61篇纯文本，旧侧分别用兼容API的同页边界对照。旧侧续页通过两页5条取得第10条后的绑定5条游标，保留生产游标限制；每个响应核对正文、标题顺序、条数及新协议游标形状。原四组完整保留，三轮交替次序、10预热＋80样本及40%门槛不变，新增后共21项，逐项达标才通过。

端点主计时预先固定为两侧同用`CLOCK_MONOTONIC_RAW`。每条预热与测量均用Go单调钟夹读RAW边界，保留上下界和不确定性；RAW须落入Go区间加`max(50µs, 1% RAW)`预算内，夹读宽度也不能超过该预算。无效区间全部保留并导致Gate失败，不剔除样本或跨日志校正。测量test的LF SHA256为`7a0f3be9321d90f36cfbd7ceb2964c3579a4eb55e882332ac91e94ec7d6e7530`；`independent-source.json`绑定当前Linux镜像578个源码／test文件与Windows工作区，核对完整冻结archive的来源提交及1991个原文件，旧侧仅注入同份测量test、计时helper与来源标记。

| 独立项目 | 结果与证据 |
| --- | --- |
| 安全代码审查 | 未发现本候选降低授权、会话、代次或最终事务检查的缺陷；常规追加在fsync和close成功后才返回，坏尾拒绝且SQL／anchor失配由既有补偿持久冻结，首次／升级／压缩保留原子替换和目录同步。旧二进制拒绝新格式的部署／回滚边界仍须单独处理；此审查不是GitHub成员批准或生产安全验收 |
| 真实PG安全／SQL | PASS：`independent-security-sql-01.log`的authprivacy包60个顶层测试全部通过（538.897s，`-race`），包括journal格式／多进程／截断冻结、C/V Gate、取消、恢复、旧快照、六类固定SQL、九图重排清空及incremental并发／分页。该aggregate保留FAIL：长回归期间新增helper导致Go预先捕获的HTTP文件列表缺少该helper，后续编译报undefined；不是产品失败，不把整份原日志改称PASS |
| 真实HTTPS／Dart | PASS：`independent-http-dart-02.log`，固定完整test文件后聚焦复验关闭上述HTTP编译问题；真实增量12新帖5／5／2／0及最终拒绝、HTTP输入／响应形状，Dart original及prepared两路真实C HTTPS／PG均通过（29.831s，`-race`）。沿用同一未变化Dart产品源码的既有编译probe；不代表真机 |
| 契约／工具 | PASS：`independent-openapi.log`完整13份OpenAPI、`independent-text-contract.log`29项静态保护契约、`independent-collaboration-tests.log`19项协作回归及3项性能Gate回归（含单组未达标、非法样本／时钟区间拒绝）。首轮OpenAPI因Windows默认cp1252失败保留在`independent-openapi-environment-fail.log`，UTF-8复验关闭 |
| Host与冻结源码编译 | PASS：`independent-host-go.log`最终host go test／build／vet及测量文件gofmt；无DSN项仅SKIP。`independent-frozen-compile.log`证明同一test及计时helper在完整冻结源码中可编译，不冒充性能或真实SQL通过 |
| 正式接口40% | NOT_RUN：正式前探针`independent-clock-pre.json`的30／30区间不满足预设守卫；Go相对RAW约−8.3%（1–100ms），1秒区间由−7.66%变至−4.61%，夹读不确定性仅0.899–21.970µs。runner在进入三轮前停止，未创建正式样本目录。`independent-performance-window.txt`保留负载；没有改系统钟、授时服务、clocksource或门槛，未将无效时钟样本冒充40%通过 |
| 手机25%及布局 | NOT_RUN：此前ADB为空的BLOCKED证据保留；用户明确“换vivo了，继续吧”后已确认V2323A在线，取得REQ-002独占租约，04旧租约已释放并保存其快照。仅使用独立`.req002`测试包及自有合成fixture，尚未安装；未操作用户App或他任务隔离包。正式手机验收用完整冻结App＋服务端对当前完整App＋服务端，同机／网络／合成数据，分别记录实际条数和UI行为；不以同客户端切flag代替 |
| 产品CI／合并／发布 | NOT_RUN／未合并／未发布：仍无本任务push／PR、合并或部署授权；独立Linux性能CI可作为后续资源路径，未自行触发 |

## 阻碍与下一步

此前按用户要求在其他任务使用资源时暂停；2026-11-16用户明确要求04完成后通知02继续，随后明确“换vivo了，继续吧”，现已恢复。入口复核规则版本为AGENTS `a4d7228a0dd4b91e851746ab7f9fb37d1ec806b5`／CONTRIBUTING `9937638c077bf2da7d51daa5de13a83645dc4320`，与本轮契约一致。完整安全／SQL及HTTP回归已完成，本机独立时钟区间不一致待诊断，手机已在线待建立隔离测量资源。`origin/main`已前进至`d1a795d2c848e0d572eb71ac9fd0219df5f66ca0`（需求004），本分支未混入其缩略图／vault／连接改进；冻结性能基线仍为`1d829b2`，与最新main的后续集成兼容证据另行绑定。

1. 三项硬门槛目前仅SQL通过，接口性能FAIL、手机BLOCKED；任务未整体验收，不标记ready或发布。
2. 继续只读诊断本机RAW／Go单调钟不一致；采用有效稳定时钟的完整冻结旧版本对照或独立Linux产品CI，保留所有无效／失败证据。候选未实测达标前不把旧FAIL关闭；真实 `paging=incremental-v1` 测量已纳入同一三轮Gate。
3. 与当前设备任务错开固定设备／网络的手机时间线；保留原25%硬门槛及图片布局检查。
4. 完成本地提交后，按用户授权边界处理本任务分支push／草稿PR和产品CI。合并、正式部署仍需明确授权。
