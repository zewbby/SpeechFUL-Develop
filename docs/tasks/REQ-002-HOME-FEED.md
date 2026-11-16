# REQ-002 — 六类列表批量读取与首页增量分页

- 模式：常规；负责人／状态维护人：当前 Session。
- 分支／Worktree：`codex/perf/home-feed-batch`；`D:/SpeechFUL/.worktrees/req-002-home-feed`；冻结性能基线 `1d829b2623a6c32830ee1b74fae6c99a436ad3b3`（需求001已合入）；[草稿PR #11](https://github.com/zewbby/SpeechFUL-Develop/pull/11)。
- 授权依据与边界：2026-11-16 用户明确要求“按这个计划开始实施，完成六类列表批量读取和首页 10/5/5 分页，再按三项硬门槛验收”，授权隔离实现、必要本地提交和验证；随后明确回复“授权本任务推送、草稿 PR 和 CI（推荐）”，覆盖本任务分支后续必要push、草稿PR及产品／性能CI。不修改正式数据；远端合并和正式发布仍未授权。
- 需求确认：用户 Q1 选择六类共用列表一起优化；Q2 选择三项均作硬门槛；后续明确首屏10条、刷新新增5条、续页5条；Q4 选择最新5条先显示、后续刷新补齐中间帖子。刷新不足5条按实际数量，无新帖保留已有列表。六类为首页、频道、作者、我的帖子、点赞、收藏；10/5/5 适用于首页及频道筛选，其他列表原页大小保留。热榜和搜索不扩大范围。
- 更新日期：2026-11-16。
- 状态：实现完成；SQL及接口p95≥40%两项硬门槛PASS。被测合成提交 `56531e79a6b51154296f2b0545b5181dd7792822` 与本地集成 `a01ae5e4a413b59b2ce998f964403659151c92b6` 的tree均为 `908d73fbfad52be350c08d78ca37055cdc8b956b`；42组／3780计时全有效、21/21比较PASS，该轮17类产品／协作workflow全部PASS（适用SKIP保留）。最新a3同产品CI为16PASS／Feed前置FAIL，正式性能被SKIP；确定性测试夹具修复已本地PASS、待Sol独立复核与新head CI。手机25%与布局NOT_RUN，设备离线且旧租约过期；不能据软件结果关闭第三门槛。全部历史FAIL／invalid保留，旧5bf Tail原因未定。PR保持draft；未合并；未发布。

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

冻结对照始终为完整 `1d829b2623a6c32830ee1b74fae6c99a436ad3b3`，没有把当前legacy开关当旧source。当前产品版本为 `f6cc4c3` 加正常主线合并 `a01ae5e`；后者与实际PASS的CI synthetic `56531e7` 完全同tree；a3只更新文档，本轮只改受控注册测试夹具和回归，生产文件零差异。下表分别保留已验产品结果与最新CI阻断；后续各历史段落的FAIL／NOT_RUN仅对应其当时版本，不覆盖当前结论。证据均保留在 [E验证目录](E:/Hnuhole-env/req002-home-feed-validation-20261116/) 及 [手机工具目录](E:/Hnuhole-env/req002-device-20261116/)。未连接正式数据库或操作用户原App。

| 当前项目 | 被测版本／范围 | 当前结果与证据 |
| --- | --- | --- |
| 来源与主线兼容 | CI `56531e7`＝本地 `a01ae5e`，tree `908d73f`；parents为f6与main `bf5c0ae` | PASS：正常merge对齐；新main仅评论同post回复计数约束、0048评论likes索引与迁移／CI／文档共8文件，无apps/packages变化。CI实际包含该主线，不能把结果写为纯f6 |
| 最终安全与读链路 | Sol独立f6完整837项raw／Git执行位／symlink、实际644/755与media无go-w预检；真实独立PG `-race` | PASS：`sol-f6-fresh-source-01.json`、`sol-f6-focused-01.log`（authprivacy47.047s、HTTPS29.961s）。新buffer普通／8192上界所有权、后续解码及GC、精确V2签名／坏槽，六类／增量、fresh proof、角色及清理、Dart原／prepared路径通过；runtime/rankings未选中项不计覆盖 |
| SQL硬门槛 | 实际native无图20／50、有图／编辑／清空及六类对照 | PASS：无图3条主体＋1最终counts＝4；有图4＋1＝5，均≤6，50条固定。准备／最终各1条fresh proof和固定authority另列；每请求1个最终checkpoint。阅读量计入主体总数，不按网络batch隐藏SQL |
| 接口p95≥40%硬门槛 | 完整旧／新source，同61帖、同页大小／负载／环境，3轮、7路由、各10预热＋80正式 | PASS：42组／3780区间全有效、0 invalid、无错误，21/21≥40%；最低普通home10第3轮46.5097%。Sol从原zip逐条复算guard／raw p95／全部比较，`sol-f6-ci-independent-audit-02.json`；不删异常值、不选轮次 |
| 实际10/5/5接口 | 三轮真实incremental协议；与上行同条数比较 | PASS：首页10提升60.7078／60.0833／58.4034%；旧续页5为49.5681／49.7526／50.0657%；刷新5为49.3357／52.2661／47.8146%。没有用20→10/5缩页收益代替同页40% |
| 当前CI | [a3 Feed43880785956](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43880785956)，source `6362b06`／tree `3349bc7`精确等于a3 | 16PASS／1FAIL：Feed真实SQL前置在注册夹具跨半小时失败，后续C/V、stage、正式40%均SKIP；always诊断PASS不作验收。此前[完整17PASS轮43876403002](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43876403002)及21/21性能PASS保留；本轮test-only修复本地PASS，独立复核／新head CI待验 |
| 手机软件与隔离工具 | 完整1d App；debc主线控制App；5bf r6候选App；同r5注入与工具链／defines | 离线PASS：profile/AOT、真实FeedScreen widget与decode探针、11个统计／布局反例。全部输入等价证据支持App复用，appSource与serverSource分列；不是单客户端切backend flag。1d／3746／ef及f6的fresh HOST TLS／publish12／protected WEBP smoke保留，均已停止；bf5／a01新server fixture开测前再准备 |
| 手机p95≥25%与布局 | Xiaomi15 `63005867`，固定设备／网络、完整版本矩阵 | NOT_RUN：ADB／PnP为空，旧lease20:19过期，未装机／清用户App／采样。正式home／older／refresh各10预热＋80原始样本；真实native PostStore、vault／网络／layout／hit-test／callback；每次刷新实际新增12帖。独立受控decode场景逐帧检查card与image全局Rect、scroll offset和idle，无主动滚动／导航 |
| 合并与发布 | 草稿PR#11 | 未合并、未部署；既有授权仅覆盖任务分支push／draft PR／CI。三硬门槛仍缺手机，不标ready或发布 |

### 历史首轮实施与验证（以下保留当时9eb等版本结果）

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
| 正式接口40% | 首次NOT_RUN：`independent-clock-pre.json`的30／30区间无效，runner在进入三轮前停止。后续正式三轮已完整执行，但计时Gate FAIL（环境无效，40%仍待验）：见下段；旧FAIL／invalid全部保留，没有改系统钟、授时服务、clocksource或门槛 |
| 手机25%及布局 | NOT_RUN：此前ADB为空的BLOCKED证据保留；用户明确“换vivo了，继续吧”后已确认V2323A在线，取得REQ-002独占租约，04旧租约已释放并保存其快照。仅使用独立`.req002`测试包及自有合成fixture，尚未安装；未操作用户App或他任务隔离包。正式手机验收用完整冻结App＋服务端对当前完整App＋服务端，同机／网络／合成数据，分别记录实际条数和UI行为；不以同客户端切flag代替 |
| 产品CI／合并／发布 | NOT_RUN／未合并／未发布：用户已明确授权本任务push／草稿PR／产品与性能CI，准备送审当前本任务分支并由入口Session创建草稿PR、跟进独立LinuxCI。远端合并／正式部署仍未授权 |

### 最新main集成与完整三轮（2026-11-16）

本地测试提交`45eb4d974d741cfe3247b340729fe15604020c51`保存上述独立结果；随后在干净工作区本地集成已合入004的`origin/main@d1a795d2c848e0d572eb71ac9fd0219df5f66ca0`，形成`e6b5ea4dcdf669652b7ca5674a8db86379d7c481`，未push。004的缩略图、vault及连接改进不能归因002；原完整冻结基线`1d829b2`和纯002 `64c019e`证据继续保留。`independent-integrated-source.json`核对591个API／契约／迁移文件；`integrated-host-compatibility.log`的runtime／posts／readtiming测试及全包build／vet PASS，`integrated-sql-http-compatibility.log`真实PG聚焦安全／六类SQL／分页／九图／prepared PASS（61.470s），真实HTTPS及两路既有Dart probe PASS（29.246s）；最终集成App的原生vault／连接与整机证据仍须另验。

按“空闲后暂时slew可能消退”的新假设，仅复核同一预设时钟守卫，`independent-clock-recheck-after-idle.json`30／30 PASS（1–1000ms，Go／RAW偏差约0.002%–0.18%）；正式前`independent-clock-pre-integrated.json`亦30／30 PASS。因此在无本任务并行测试／构建窗口执行完整旧源码对照，source为`e6b5ea4`，测量test保持上述`7a0f3be9…`，未在测量期间修改被测文件。

- **完整执行但环境无效：**`performance-journal-independent-01/`六份原始JSON共42个cohort、每个80测量样本（3360个）全部生成，另含全部预热和计时证据；HTTP、正文、标题、条数及新协议游标形状均通过。3780条时钟区间有705条不满足预设守卫，集中于legacy第2轮前三组和batch第3轮前六组；另有两条个别区间不合格。`comparison.json`如实拒绝并记录`invalid or failed cohort`，`independent-clock-post-integrated.json`29／30无效。整轮不能作为≥40%的有效验收，不剔除、校正或重跑这些样本。
- **仅作缺口诊断：**有效单组中第1轮真实增量首屏10为50.953→34.047ms（约33.18%），刷新5为47.631→36.424ms（约23.53%），均低于40%；这不使无效的三轮整体变有效。`independent-performance-summary-diagnostic.json`保留逐组p95和无效计时数量；原始JSON及每轮环境文件同时保存在Linux owned目录与E证据目录。
- **后续路径：**可信Windows原生外部HTTPS计时或已获用户授权的独立Linux产品CI可补接口证据；草稿PR／CI由入口Session跟进。手机由独立物理设备计时，可继续准备，不能以guest RAW问题替代手机结果。25%正式归因采用完整`1d829b2` App＋服务端对完整纯002 `64c019e` App＋服务端；`e6b5ea4`作最终集成功能／布局和附加证据，不把004收益计入002独立门槛。

### Astra Ultra 定位与主线兼容（2026-11-16）

用户明确要求由 Astra Ultra 继续定位及修复，完成后交回 GPT-6.1 Sol XHigh 独立测跑。接手基线为干净的 `d3c44ea95c8b274f9f3844d6aa7421c6dd722026`，沿用同一任务分支及已有 push／草稿PR／CI授权。[草稿PR #11](https://github.com/zewbby/SpeechFUL-Develop/pull/11) 已创建，尚未合并或发布。

新的 `origin/main@debc13a86b6dfb19cdb259317f3f6c1031703ac9` 包含已确认的服务续行契约：只对能够证明唯一前序的只读 Snapshot 检查点补完，业务提交不带可重放回执，真实回滚／损坏／显式冻结仍拒绝。先集成该主线，再开展本轮存储修复；同名测试冲突通过将本任务原有存储测试保留为 `authorization_journal_test.go` 解决，两组测试都保留。完整冻结性能基线仍为 `1d829b2`，不把主线改善归因于002。

同请求诊断 `ultra-https-merged-before.json` 显示60次真实HTTPS请求连接均复用，客户端与服务端耗时差约0.22～0.32ms，排除额外HTTP固定延迟的假设；主体准备约2ms，检查点写入和SQL提交占主要耗时。该次计时守卫无效，数值仅用于定位，不用于关闭40%验收。交错I/O探针 `ultra-io-01.json` 保留全部样本：缩小记录、改变对齐及固定位置 `fsync` 无明显帮助；复用已分配固定块的 `fdatasync` 显示进一步优化方向。此时尚未修改产品持久化实现。

主线兼容聚焦验证 PASS：`ultra-main-compatibility-01.log`，真实独立PG、`-race`，C/V只读检查点在UPDATE／COMMIT／连续中断后续行、业务快照回滚拒绝、错误前序及显式冻结拒绝、临时证据中断、旧检查点升级，以及本任务全部journal格式／故障／多实例／多进程／截断检查（authprivacy 87.709s）。预发布降级预检另补物理容器格式匹配，防止支持新签名字段但仍只读JSON的旧二进制接触当前anchor；聚焦工具回归4项PASS。当前性能和手机验收仍待完成。

### 固定槽候选与独立CI缺口

`2ea7327` 已推送并解决PR与最新main的冲突。[独立Linux Feed CI](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43810234588) 的被测合成提交为 `149bee23df7612fcaf65bf4ab50fcef2050aa475`，其tree与 `2ea7327` 完全一致（`1a3750c56b556eacda31bbd2b0bf7e9b4fa4f14f`）。16类workflow中15类PASS，唯一Feed backend在host、完整SQL及独立C/V全部PASS后，性能Gate FAIL。原始artifact `14199853798` 保存为 `ci-2ea-feed-performance.zip`，SHA256 `CE64C3350BD58358341B44A4E39E59E094567BDA08B32052456966653FF6C4CC`。

- 42组均完整，3780个计时区间中3779个有效；唯一无效为batch第3轮next20的index85，RAW处在Go夹读内，但夹读不确定性0.142567ms超出原预算，和WSL持续钟速差不同。完整比较仍拒绝该轮，不移除无效样本。
- 其余有效组仍明确不达标：实际旧续页5提升28.14%／30.05%／26.66%，刷新5提升24.67%／31.27%／29.82%；真实首屏10为45.99%／39.47%／43.14%。因此缺口不归咎于时钟，原FAIL继续保留。CI首页20改善56.14%／59.21%／59.01%不替代小页验收。
- 本轮修复采用V2固定双槽，只有最终业务 `CommitAuthorized` 复用旧槽并执行 `fdatasync`；`Snapshot`／冻结／恢复明确保留完整文件原子替换。两槽元数据和完整内容均签名，任意坏槽拒绝，不回退授予旧权限；旧JSON/V1原子升级，部署预检识别V1/V2差异。协议及恢复限制见[Gate设计第18节](../design/auth-authorization-safety-gate.md#18-有界签名检查点存储)。已否决并撤销单槽原位覆盖草稿，避免毁掉唯一完整签名材料。
- 同请求阶段观测新增候选授权、会话预检、资源证明和协议密钥检查；只在显式trace时记录固定标签，不记录业务内容。下一CI单独上传60请求的 `feed-request-timing` artifact，原正式三轮、所有页大小、原始样本、40%与计时守卫不变；job上限由20改30分钟，仅保证安全检查与性能检查均能完整执行。
- `ultra-https-slots-01.json` 的60请求计时守卫均PASS；该次WSL阶段诊断的检查点写入约4.5～6.9ms、SQL提交4.6～7.4ms、准备约2.5ms。不能与不同时间段的旧诊断计算验收提升，也不能推断独立CI会达40%。

初步存储及真实中断验证PASS：`ultra-slots-unit-01.log`（12.199s）及 `ultra-slots-crash-01.log`（真实PG、`-race`，25.267s）。覆盖固定分配复用、保留旧完整槽、签名序号／长度／填充／序列耗尽拒绝、旧格式升级；真实子进程写64字节后退出，C/V的Snapshot临时文件半写仍同代继续，业务半写保留旧材料但拒绝授权、回滚SQL并持久冻结，代次不自动推进。既有Recover不绕过坏槽，未新增损坏文件修复能力。上述为进程退出和故障注入，不能替代真实断电或生产存储验收。

最终验证绑定 `2ea7327`＋本轮明确差异，`ultra-slots-source-final.json` 核对577个API／infra文件的LF SHA256与最终工作区一致；承载本段记录的提交包含同一产品实现。

| 最终项目 | 结果与证据 |
| --- | --- |
| C/V、安全、列表完整聚焦 | PASS：`ultra-slots-security-01.log`，真实独立PG、`-race`；authprivacy 650.953s、真实HTTPS增量12新帖路径12.30s（HTTP包13.333s）。包含只读续行、取消、SQL失败、恢复／代次、旧快照、证据与break-glass、两槽／多进程／截断、六类SQL／九图／分页。Redis相关选择项按配置SKIP，不冒充覆盖 |
| 最终追加测试与可关闭trace | PASS：`ultra-slots-final-focused.log`，真实PG、`-race`，38.440s。加强V1坏尾升级拒绝及完整记录截断；已有C token在Snapshot半写中断后继续可用，业务坏槽时session记录未撤销且代次不变；prepared时间线及单次最终检查点仍通过。完整安全回归后仅追加这些断言和可关闭观测，没有再改存储或授权逻辑 |
| Host构建与静态检查 | PASS：`ultra-slots-final-host.log`，最终 `go test -mod=readonly ./...`、build、vet；无DSN项仅SKIP。首个 `ultra-slots-host-01.log` 保留FAIL：host wrapper残留仅供isolated runner使用的FEED_GOOSE，但没有迁移DSN，触发owned-fixture保护；清除该host环境残留后完整复验关闭，真实PG阶段未削减 |
| 降级预检 | PASS：4项聚焦工具回归，覆盖有checkpoint_id但仅支持JSON、仅支持V1及支持V2的binary边界，读取live材料前拒绝不兼容降级 |
| 正式接口与手机 | 新候选NOT_RUN，等待对应head独立CI／GPT-6.1 Sol XHigh；旧候选有效小页FAIL、所有raw／invalid保留，未改40%／25%硬门槛 |

## 2026-11-16 971复测与固定数据库往返定位

- [CI 43813735442](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43813735442)正式42组计时全部有效，`Complete=true/PASS=false/Error=null`。被测synthetic merge `6afb9645723b2b7b43820cff636df90eba772b0b`与971d14e的tree均为`335c3dcbb69b8de69e7845b21003601d85fe7b52`，已通过Git检查引用核实。
- 实际增量路径同页大小p95降幅：home10为35.26/37.20/31.89%，next5为23.25/25.82/15.95%，refresh5为22.08/35.41/21.51%，均未满足三轮40%。home20首轮连续慢样本导致新27.079ms、旧10.376ms，全部保留，不剔除或归因给未证实的环境因素。
- 原始证据：`ci-971-performance.zip` SHA256 `CD6268C6F6505BD74A3F404CF07E9375EC42F4AD882B61DD65D38F284E4BAEE6`；`ci-971-timing.zip` SHA256 `F3F0D422243AF079BAF9E5C1384EE61FBFCE0A4A3F05DCF45DC608A123CAD70C`。同请求阶段显示固定槽anchor写入约0.45ms；Limit5服务端约4.86ms，prepare约1.71ms、candidate authority约0.64ms、final Gate约1.93ms。阶段有嵌套，不能直接相加。
- 本地仅做轻量SQL结构诊断，未重跑971正式三轮。`ultra-query-plans-971.json`、`ultra-query-plans-bounded-02.json`保留每条查询6次完整EXPLAIN及实际pgx预热执行。缓存事实为26次后约21 generic/5 custom：单看EXPLAIN的规划成本不能代表真实请求。MATERIALIZED投影草稿虽然降低规划时间，却增加真实执行成本，已撤回；共享proof版本连接没有稳定收益，也已撤回。`bounded-01.log`的SQL列歧义失败原样保留，后续诊断关闭该草稿错误。
- `ultra-query-plans-any-03.json`比较直接`post_id=ANY(pageIDs)`＋`array_position`恢复候选顺序；5条投影改善有限，10/20条尚无稳定收益，最终也撤回该草稿；最终主体查询与971相同。所有诊断原始记录保留，不作为接口性能通过证据。
- 当前修复候选减少正常prepared请求的6次数据库往返：三次BEGIN与SET LOCAL一起发送；候选预检复用已锁Gate行，仍验证独立证据与anchor；首次RR只读快照校验并绑定session，后续有界重试不换账号或代次；最终同一restriction锁行一起读取ban/mute。最终account→restriction→session→Gate锁序、原始Gate代次比较、完整资源proof、续期及持久化提交顺序均保留；未使用依赖未定义CTE顺序的锁合并，未改变V2存储格式。
- 新增真实事务模式／超时、BEGIN设置失败后的连接清理、冲突后账号与session同时换代拒绝重绑、缺失identity/owner/viewer版本行拒绝的回归。被测内容为971＋本节固定往返修改，最终承载提交包含相同产品代码；799个跟踪API／infra／packages文件按LF与Windows源码核对一致，`ultra-roundtrips-source-final-canonical.json`列出7个实际API差异文件。归档原生symlink与Windows链接文本按Git链接内容核对；checkpoint／anchor持久化文件与971完全相同。
- 真实PG `-race`：`ultra-roundtrips-focused-01.log`的authprivacy运行966.458s，原aggregate FAIL保留。除下列5项外，C/V中断续行／回滚拒绝、临时证据、代次、六类SQL、图片编辑、增量、媒体权限／CPU错误／ACK丢失、prepared原绑定／最多一次重建、真实事务模式与timeout均PASS；Redis未配置的排名项仍SKIP。真实HTTPS增量独立PASS（包19.792s），runtime配置与关闭可选功能兼容PASS（7.894s）。
- 5项失败已逐一关闭：4个CommentPrepared用例首次遗漏`COMMENT_SNAPSHOT_REDIS_SERVER`，02日志仍因不存在的`/usr/bin/redis-server`失败；03使用已核实的只读Redis7.0.15缓存binary及库，各用例独立创建／清理实例，PASS45.310s。第5项是新增测试要求失败后池计数立即归零，但pgx/Puddle源码明确异步销毁失败连接；改成只有1个permit的真实池，5秒内必须取得不同PID、状态I、read committed/off且两timeout恢复0的新连接，`ultra-roundtrips-begin-cleanup-04.log` PASS4.878s。未修改产品错误处理来规避该断言。
- 两套同请求HTTPS诊断各60样本、全部clockvalid与内容校验PASS，`ultra-roundtrips-stage-{diagnostic-971,source}.json`保留完整结果；新草稿总均值反而更高：5/10/20条旧14.76/12.97/13.60ms，新22.75/42.84/24.39ms。未改动的anchor写入阶段从约4.2ms变为8.6/16.4/6.6ms，原因未证实；不能据此宣称环境波动或产品收益已确认。这是含随后撤回ANY投影的草稿诊断，不是最终候选的40%验收。减少6次往返是结构事实，实际p95由新head独立LinuxCI判断。
- 撤回投影草稿后，`ultra-roundtrips-final-feed-05.log`再次对最终代码运行六类逐页对照PASS（authprivacy11.525s）、真实HTTPS12新帖增量PASS（HTTP12.653s）；主体SQL仍20/50固定。`ultra-roundtrips-host-01.log`完整go test/build/vet PASS；最终测试修订后`ultra-roundtrips-final-host-05.log`再验authprivacy host test/vet PASS。未重跑971正式三轮，未调40%／25%门槛或计时守卫。

## 2026-11-16 2d有效FAIL与重复计算修复

- [CI 43839635746](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43839635746)的42组全部有效、`Complete=true/PASS=false`。实际home10降幅39.10/37.19/39.15%，next5为23.84/21.13/23.23%，refresh5为24.23/11.47/11.37%；仍未满足40%。17类workflow中16类PASS，Feed的host／完整SQL／独立C/V前置均PASS。原始artifact `ci-2d-feed-batch-performance.zip` SHA256 `19E4F9C93505246920B59E51ABFAC51A3CA51F17C4A68DFF936DF8C87672BABD`；`ci-2d-feed-request-timing.zip` SHA256 `942C186FE70833B09BB72E6C7932AA03E1E87830C36A3146CE1746966B5EA6F7`。
- 来源纠正：被测synthetic merge `fe6b72aab7c98256587bab8acbf2985e926ad345`包含main `47bf7e9c3231e3e45e078280086d7fc45025f4d9`与2d76784，并非2d纯tree。已干净合入该main为`344628cc6a63d9708232aebfa4f2fd3412153605`，tree精确同为`cfebdd27fe4bcc689755afa594f4efb627ac6d25`。保留标签投影及0045/0046迁移；冻结1d基线不变，不能把合成候选的全部变化归给2d。
- 重复验签：正常prepared请求对相同字节执行约10次Ed25519计算。每个Gate／anchor store新增最多4条成功项LRU，精确比较公钥、完整签名消息和签名，miss先复制再验证，只复用数学结果。它不保存anchor解析结果、证据对象、期限或授权决定；每次仍读完整文件、检查头部／两槽／序号／填充、解析新JSON、取得当前证据及时间、比较SQL／anchor／资源proof并完成最终业务事务。换公钥／篡改／过期／回滚不借缓存放行，磁盘格式与提交顺序未改。Gate设计未要求每次重新执行签名数学计算，无需改变既有权威状态契约。
- `ultra-memo-cpu-02.log`的隔离CPU/count诊断：10.00→2.001次验签／请求，三次约0.500–0.508ms→0.100–0.105ms；这不包含HTTP、SQL或持久化，不能作为40%证据。暖缓存坏槽／截断、完整输入／公钥绑定、复制所有权、容量淘汰、并发、期限和域检查均PASS。初次真实回滚测试被生产单调性trigger拒绝注入，`ultra-memo-gates-01.log`原aggregate FAIL保留；按既有恢复旧库测试模式，仅在自有fixture中禁用trigger还原旧SQL再立即启用，02及最终聚焦均证明暖缓存拒绝并持久冻结。01中其他C/V回滚／错前序／临时证据／break-glass／截断检查PASS。
- `ultra-generic-plans-03.json`保留全部实际连接26次执行及每变体6次`EXPLAIN EXECUTE`，覆盖5/10/20条、offset0/10/40。真实pgx已转generic，不能用每次重新规划的EXPLAIN替代。在offset40取5条时投影扫描45个posts，原函数逐行检查屏蔽；直接展开相同双向`NOT EXISTS`使数据库使用反连接。Limit5投影执行均值0.233/0.297/0.496ms→0.095/0.107/0.149ms，候选0.192/0.169/0.188ms→0.069/0.064/0.059ms，仅为局部查询诊断。最终只保留该等价谓词，候选与投影两处完整检查均保留，未新增RR资格豁免；ANY／proof对象聚合没有稳定额外收益，不引入产品。早期诊断compile及无效昵称fixture失败日志保留，03关闭。
- 真实SQL新回归覆盖原函数与内联谓词的NULL／自身／不存在账号／双向／解除后真值，使用既有受限`hnuhole_c_runtime`实查SELECT且无UPDATE/TRUNCATE，不扩大grant；函数正文契约检查强制未来策略变更重新审查内联处。READ COMMITTED候选后新屏蔽仍由投影拒绝；RR候选与投影之间双向屏蔽、隐藏、删除、作者改名仍被最终proof重建后交付。
- 最终组合候选绑定344628c＋本节明确差异：`ultra-memo-blocks-focused-01.log`真实PG `-race` PASS198.337s，含六类逐页／20与50固定SQL／九图编辑／增量／prepared冲突、原会话、代次及ACK丢失；其HTTP包为no tests to run，不冒充HTTP覆盖。`ultra-memo-final-focused-02.log`追加受限角色／策略防漂移／暖memo／正常C/V Snapshot中断继续保留登录等PASS55.891s；`ultra-memo-host-final-02.log`完整go test/build/vet及改动文件gofmt PASS。真实HTTPS12新帖增量另在`ultra-memo-stage-source.log` PASS14.88s（HTTP包28.422s）。`ultra-memo-source-final.json`核对806个API／infra／packages跟踪及新增文件LF／链接内容与Windows最终源码一致。
- 最后一次同请求诊断`ultra-memo-stage-{diagnostic-344628c,source}.json`各60条：旧端0/60、新端60/60计时有效，故不能作新旧速度对照；所有raw及原守卫保留，不再刷样本。测量时没有并行构建／测试请求，但其他本任务手机fixture每分钟刷新合成证据产生少量fsync；不据此解释时钟异常。新候选40%仍NOT_RUN，交对应head独立Linux CI验收；手机仍NOT_RUN。

## 2026-11-16 e0有效小页缺口与证明／往返修复

- [CI 43849621008](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43849621008)被测synthetic `8e8a1668081fdc0503a28f0f72a28a11c5242e31`为e0与main 47的合成，GitHub compare确认与e0无文件差异。17类workflow中16类PASS；Feed的host／完整真实SQL／独立C/V／stage全部PASS，性能Gate FAIL。原始artifact：`ci-e0-feed-batch-performance.zip` SHA256 `471AD0A22BE8F877DDCB6856E01DA2291EA38C84823BFE023C87DFA4D03AAE1B`；`ci-e0-feed-request-timing.zip` SHA256 `819387A166A26F2D88B439F9F8DAF5FEB4DE829236289BFB5999185A0EC89ACD`。
- 42组执行完整，3780个计时区间仅batch第3轮incrementalRefresh5的index55无效：RAW 2.600868ms落在Go区间[2.521628,2.601657]内，但80.029µs宽度超过原50µs预算；完整comparison拒绝，不删除该样本。有效对照已证明缺口：实际home10提升46.84/50.19/47.44%；next5为35.57/35.56/40.60%；refresh5前两轮37.45/34.11%，第三轮无效。不能把有效失败归因于这一个计时区间，也不能以首屏通过替代小页40%。
- CI阶段诊断60次均有效。Limit5前6次含custom plan及冷启动，不能把其投影均值0.740ms当稳态成本；indices6–19仅用于定位，server均值2.384ms、投影0.147ms、两次proof合计0.419ms。正式三轮的预热、80样本、守卫及40%完全未改。
- 本地三份诊断`ultra-e0-proof-{plans-01,rows-02,binary-03}.json`保留5/10/20条、offset0/10/40/空页的全部26预热＋60交错查询及每变体6次真实`EXPLAIN EXECUTE`，确认generic计划并核对原证明全部材料。仅合并JOIN为JSON聚合收益约0.015ms/次，不采用；逐行typed记录收益约0.04ms/次，但增加传输／Go组装。最终选择单行binary聚合，同样约0.04–0.05ms/次真实查询收益，沿用原read接口，不把局部收益当端点Gate。
- 新proof按kind＋UUID排序，每项固定36字节（4字节种类、16字节UUID、两条8字节整数版本），精确保留channel范围／发布版本、含lookahead的post、identity、owner、viewer可见性及filter版本；独立intact保留LEFT JOIN缺版本行拒绝与空集合为真的语义。Go bytea扫描拥有独立复制的字节，不引用后续batch可复用的wire缓冲。表示只存在单次prepared plan内，未改持久化、游标或跨请求协议；准备和最终阶段仍各自fresh读取。热榜复用此证明，因此做兼容回归，未扩展其产品范围。
- `ultra-e0-lock-batch-04.json`用每次独立事务、26预热＋60交错样本验证原account→restriction→session三个FOR UPDATE，串行median0.2193ms、batch0.0975ms。产品仅对已绑定subject的native prepared路径一起发送这三条SELECT，执行次序与Gate锁位置不变，普通／未知Gate路径仍串行；所有行检查、原账号／session／Gate代次和最终事务均保留。proof与本页view-count另以两条fresh SQL一起发送，最多减少3次网络往返，SQL数量没有减少。
- 批次必须关闭／排空，任意扫描、Close、取消或SQL错误不释放内容。冲突后计数被丢弃，新attempt新建plan；最终游标失效也不交付已排队的计数或续期。测试注入改用真实BatchStart的首条account锁前窗口，不伪造中间QueryStart；baseline错误观察接入真实BatchQuery／End并避免重复，SQL计数按每条QueuedQuery计算。既有Gate取消挂点仍是未批量化的Gate UPDATE／普通session查询，原窗口不变。
- 首轮新增反证`ultra-e0-batch-focused-05.log`真实PG `-race` PASS33.348s：对原JSON oracle逐项核对，包括空页／频道／缺scope、post、identity、owner、viewer行、超过2^53的精确版本、ID排列；逐一阻塞三处锁证明原顺序，取消／timeout后单permit池有界复用且无锁／事务／LOCAL泄漏；Close失败拒绝authority／counts。非零阅读量3/4→9在prepare后可见，冲突重建返回17，每attempt恰1条计数SQL；最终游标过期时计数不交付且不续期。
- 组合候选绑定e0＋本节差异：`ultra-e0-batch-regression-06.log`真实独立PG／Redis `-race` PASS（authprivacy671.958s、真实HTTPS原路径／prepared／12新帖增量30.858s），覆盖六类逐页及固定SQL、图像编辑、prepared session绑定／最多一次重建／撤销／取消／ACK丢失、评论、媒体CPU与最终权限、热榜缓存／SQL组合。新增受限C runtime完整feed（非零计数11、两次proof、一次checkpoint）与实际SQL解析／执行错误观察在`ultra-e0-batch-final-07.log` PASS11.328s，未扩权限；最终`ultra-e0-batch-host-final-07.log`完整go test/build/vet及改动文件gofmt PASS。只新增这两项测试及错误事件去重后才再次同步Linux，未在运行中修改其包文件列表。`ultra-e0-batch-source-final.json`核对808个API／infra／packages跟踪及新增文件与最终Windows源码的LF／链接内容一致。
- 唯一一次新候选同请求诊断`ultra-e0-batch-stage-08.json`：60/60内容、连接复用及clock guard PASS，每请求proof2次、anchor_write1次。WSL的5/10/20条raw均值13.638/11.595/12.642ms只作阶段观测，未跑同环境旧端，不计算40%收益，也不与CI绝对时间相比。新候选正式40%仍NOT_RUN，交对应head独立CI；手机25%及布局仍NOT_RUN，交Sol独立验收。

## 2026-11-16 f3全有效对照与准备阶段修复

- [Feed CI 43858540950](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43858540950)被测synthetic `0279063838cb268ec7707c032c352b694502474d`与f3 tree内容等价（compare ahead1／behind0／files0、merge-base f3）。42组齐，3780个计时全部有效，comparison Complete=true／PASS=false；21项中17项达到40%。4项FAIL分别为第1轮incrementalRefresh5 38.88%、第2轮incrementalNext5 39.84%、第3轮next5 38.43%、第3轮incrementalNext5 39.54%；实际首屏10三轮52.20/51.40/50.19%。原始`ci-f3-feed-batch-performance.zip` SHA256 `7C98F84A06B2FC518DE32A145AB6AAD4B8733FB18EE19BBF318BF54C26C8717E`，`ci-f3-feed-request-timing.zip` SHA256 `65B8499828DC64B30CDA2427F6B9E9AFCA3D74E8EBC0CC7DC021CCBCE3451903`，均完整保留，不重跑旧候选求绿。
- 同请求热段index6–19仅用于定位：5条server均值2.172ms，两次proof合计0.393ms；不改正式预热／80样本／守卫。`ultra-f3-projection-proof-01.json/.log`用真实同RR、相同5条投影及含lookahead的完整proof，26次预热＋每变体60次交错，串行均值345.3µs／median316.7µs、一起发送254.5／232.5µs；全部材料相同。该Go耗时只证明局部方向，不作为端点40%验收。
- native prepared准备阶段在原subject校验之后，以原两条SELECT一起发送投影和完整proof，共享原DTO扫描器、资格过滤及同一RR快照；空页、早期错误及legacy仍单独读取完整证明。只有扫描、完整proof和batch.Close全成功才标记本plan证明已准备，最终阶段仍重新读取。geometry等后续SQL必须等待整个batch排空，所有原账号／会话／代次／资源检查及有界重建保持；没有跨请求材料或授权缓存。准备侧`list_projection`现在包含组合发送，`list_proof`是剩余结果读取，两者嵌套不可与旧串行span直接解释为独立CPU收益。
- V2头部／两槽零填充用标准库`bytes.Count`逐字节等价检查，格式、完整读取、两层签名、序号、锁、持久化和恢复均未改。纯CPU诊断15000字节由Go循环约3.70µs变为0.18µs；0/1字节没有收益，实际受检padding为长区域。新增逐位置非零值反证及既有损坏槽检查，不将该局部结果宣称为Gate性能。
- [Authorization Gate CI 43858540959](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43858540959)原FAIL为`TestAuthorizationCheckpointRejectsDamagedTail/padding`。旧V1式注入`raw[len(raw)-1]=1`在V2命中外签名，原值为1时没有修改；固定seed42／sequence7已在`ultra-f3-padding-02.log`复现“字节完全相同，合法材料正常接受”，不是损坏padding放行。现改为真实头部／两槽zero-padding，并断言确实发生字节变化；重签外层后仍必须拒绝非零padding，坏内签使用有效base64及有效、相同的两槽外签以隔离内签检查，另测坏外签及实际长度字段。`-race` PASS3.138s。原CI脱敏窗口及其SHA保留于`ci-f3-gate-padding-failure-excerpt.log`，未声称知道该次CI随机签名的具体值。
- [Comment Redis CI 43858541138](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43858541138)原AOF Replay在Prepare返回分类后的ErrUnavailable，缺底层原因；原commentsnapshot产品及该测试相对main47无差异。新增仅该自有测试失败时输出的128项有界命令名／耗时／错误类型／timeout标志及白名单persistence字段，绝不记录参数、键、值、原始错误文本或凭据，不重试产品调用或改变100ms／500ms期限。`ultra-f3-redis-aof-02.log`本地恰一次真实AOF replay及脱敏检查`-race` PASS1.179s，只能记未复现，不能将原失败认定为fsync timeout或宣称根因已关闭；原窗口保留`ci-f3-redis-aof-failure-excerpt.log`。
- 组合候选绑定f3＋本节差异。`ultra-f3-projection-focused-03.log`真实PG `-race` PASS26.083s：六类原字段／顺序对照；实际native20/50均3条主体SQL＋准备/最终各1proof＋1最终counts，非按网络批次计SQL；图片／九图编辑为4条主体、清空图片3条，geometry在BatchEnd后，同一RR，均一checkpoint。受限runtime无新增权限。真实proof表锁等待后取消及Close失败均不标记prepared proof，单permit池及时复用且事务Idle。
- `ultra-f3-projection-regression-04.log`并发双向block、hide/delete/profile、lookahead/filter/缺版本行、session/generation/cancel/ACK丢失、最多一次重建、非零fresh counts及增量10/5/5 `-race` PASS178.232s；真实HTTPS原路径／prepared／12新帖PASS29.007s。该pattern命中的ranking项因未启动其专用Redis明确SKIP，不冒充本轮热榜验收，本轮未修改其proof SQL／执行路径。`ultra-f3-host-04.log`完整go test/build/vet/gofmt PASS。`ultra-f3-source-final.json`核对809个services/api、infra/postgres、packages文件LF／链接内容与最终Windows源码一致，无临时诊断Go文件。
- 唯一一次新候选60条HTTPS阶段诊断`ultra-f3-stage-05.json/.log`：0/60 clock有效，内容／传输／连接复用检查PASS，每请求proof2次、anchor_write1次。所有raw保留；没有同环境旧端，不计算或宣称40%收益。f3的17类CI最终14PASS、Feed性能／上述Gate测试／Redis AOF共3FAIL保留；新候选完整40%及对应产品CI待独立复验，手机25%与布局仍NOT_RUN。

## 2026-11-16 源核对更正、5bf尾延迟与独立诊断

- **更正旧源一致性证明范围：**早期`ultra-sync-run.sh`及后续806/808/809文件manifest把所有文件统一CRLF→LF，没有区分binary；symlink也未按Git mode严格核对。因此上述“最终源码一致”只能证明规范化后的内容一致，不能作为原binary一致证据。Sol发现34个`packages/image_viewer/example`的Android／iOS图标和示例图被该操作改变，已备份、按5bf archive原bytes恢复并逐项raw／textLF／mode检查；原失败和修复记录见`sol-5bf-binary-source-diagnostic-01.json`、`sol-5bf-linux-binary-restored-01.json`、`sol-5bf-source-raw-manifest-04.json`。
- 影响边界经Sol独立核实：API/Go没有引用或embed这34个示例图；API媒体测试使用另行生成且SHA一致的3×2 fixtures，手机fixture图也独立生成。旧Go／SQL执行证据不依赖这些受损assets，不冒充曾验收示例图binary。E的完整App档案每版227个binary仍与各自Git archive原bytes一致；CI原生checkout不经过该脚本。`sol-5bf-binary-impact-and-phone-ci-inputs-01.json`保存路径／摘要。恢复后才运行的Sol独立真实PG PASS86.843s、HTTPS PASS32.727s、完整5bf r6 profile构建PASS44.3s，均不是手机验收。
- [Feed CI 43863543390](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43863543390)实际source `1ecea4ac7bcd365fb29fb67d47a46d1901a4e57c`是5bf合入main `3746d5a54b643767b99b929ca6e0e6b072c7627e`，不是纯5bf。Git Data API确认tree `5ae266a119a349a4230c3bc3363320635330b12e`，parents为main3746及5bf。正常本地merge `4b5106ad5feffa66a9ec625cd0fa8b1976206ba7`与其tree完全一致；18个集成文件来自REQ006 DM目录和迁移／运行配置，无app/packages差异。此合并只对齐来源，原FAIL仍适用，冻结1d不变。
- 42组、3780计时全部有效，Complete=true／PASS=false，21项20PASS。实际incrementalHome10提升61.26/61.44/53.19%，incrementalNext5 46.93/55.78/68.21%，incrementalRefresh5 48.41/49.19/48.44%；唯一FAIL是普通home10第3轮old5.723557ms／new12.741183ms。新端80个正式样本有24个超过5ms，主要在前44个样本呈2.4–3ms与10–16ms交替，随后同路径回到2.1–2.8ms附近，预热也有慢请求。不能删除这些样本、只重跑此组或继续假定缺几十微秒稳态开销。
- 原始`ci-5bf-feed-batch-performance.zip` SHA256 `9ED74450D2C2699788F0652D5BCE80BA15EDFE74C21C9C94C1CAC6AAB80B1C55`，`ci-5bf-feed-request-timing.zip` SHA256 `73FDA4B98A4356205A0EFAEFAAC4CA0D0508797DA4F551C70305716A33F569DA`均完整保留。17类workflow最终16PASS，仅Feed formal FAIL；[AuthGate 43863543374](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43863543374)完整PASS，[CommentRedis 43863543452](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43863543452)AOF实际PASS0.13s、SQL/session/contract PASS，actual-process-acceptance按配置SKIP。Redis底层原因仍未复现，不宣称已修复。
- 本轮只新增诊断：正式函数传nil observer，原49＋12帖子fixture、七路由顺序、每组10预热＋80样本、RAW/Go夹读、全部21比较及40%不变。独立diagnostic复用同一测量实现，标记Diagnostic=true，记录全部630请求的同请求readtiming、连接等待／复用／首字节、runtime/metrics GC和调度分布、进程CPU／上下文切换／IO与系统pressure累计数。计数在原区间外采集，差值也包含采集开销，不能脱离execution trace直接断定某次GC发生于请求内部。每请求不落盘；可选Go trace最多32MiB内存缓冲，结束后写，截断显式标记。固定路由／序号trace标记不含token、头、参数、SQL参数、cmdline或environ。
- CI因果诊断在原正式三轮之后以always执行并独立保存`feed-tail-diagnostic`，避免诊断先影响formal负载。比较器仅收紧为拒绝Diagnostic标记，补反例，其他公式／原样本／门槛不变。即使后续正式新轮全绿而Tail未再现，也只能分别报告新轮结果和原因未确定，不能把诊断提交称为产品修复。
- 一次本地`ultra-tail-01`完整诊断PASS20.411s：630/630内容、连接复用与clock guard有效，均proof2／anchor1；trace3068459字节、未截断，前＋后计数采集median223.28µs在区间外。最大181.84ms请求同请求server181.53ms，其中anchor_write66.61ms、sql_commit111.05ms，GC完成周期差0（不能排除请求前已开始的并发mark、assist或scavenger，仍须结合trace／CPU类别计数）；这是本机阶段归因闭环，不解释另一环境原CI的0.4秒Tail。全部raw、指标和trace保留，没有再采630。该本地trace尚无后加的固定route/index标记；标记和明确diagnostic-only日志随后经host编译检查，CI将按最终head生成。
- 新隔离副本从4b Git archive建立，binary一律原bytes，只有明确UTF-8 shell转换LF，symlink目标及Git类型／执行位逐项验证；最终`ultra-tail-source-final-04.json`核对836文件，两个Go诊断文件及两份比较器文本覆盖单列，未再统一normalize。原fresh副本首轮host `ultra-tail-host-02.log`因漏入infra/commentsnapshot、infra/ratelimit已提交模板而FAIL；补齐完整infra原bytes后`ultra-tail-host-03.log`完整go test/build/vet/gofmt及只读计数器PASS，旧失败保留。后续可选trace→pprof工具未产出profile、启动了查看器，已停止自有helper并确认端口关闭；raw trace未改。
- `ultra-tail-baseline-compile-04.log`在新建的冻结1d API／infra原bytes副本，仅覆盖与正式CI相同的共享测量文件及两份clock helper，`go test -run '^$'`编译PASS，不是运行性能；`ultra-tail-compare-04.log`4项比较器测试PASS，含诊断数据拒绝反例。该提交仍是来源集成与诊断能力，原CI Tail原因未定，手机25%／布局仍NOT_RUN。

## 2026-11-16 ef同请求GC证据与检查点缓冲修复

- [Feed CI 43870703913](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43870703913) source `5f34ef49e37062030f1a86bfeddebf3c6414f8cf`、tree `a6ab0004ec9f54983c8efe89b68d26ba55200471`与ef精确一致，parents为main3746和ef，没有额外产品差异。正式42组／3780计时全有效，Complete=true／PASS=false，19/21PASS：incrementalRefresh5第1轮old4.479252ms／new2.760631ms（38.37%）、incrementalNext5第3轮old4.536784ms／new2.747987ms（39.43%）FAIL；其余19项PASS。17类workflow最终16PASS，仅Feed正式性能FAIL，前置host／SQL／C/V及630诊断PASS。上一轮普通home10交替Tail没有重现，不等于已修。
- 原始`ci-ef-feed-batch-performance.zip` SHA256 `4e18598524380ac5df6b79622fa6d22265991a34160083519e3b3bfc77ea6752`、`ci-ef-feed-request-timing.zip` `cda8dde0f0da92093983a0f653204ce98638f36ea2ce6a8ee470e0bd9c81a394`、`ci-ef-feed-tail-diagnostic.zip` `203fe6ed29d2a60ea6dc66d6f00b26a218c6ee98ea4930b3bef9a13c3c99b280`完整保留。离线解包／分析在`ultra-ef-diagnostic-analysis-01`，无新正式采样、删样或改guard。
- 630同请求诊断全部连接复用；仅home20最初两条预热为6.24／6.00ms，其余最高3.96ms，未见旧10–16ms慢段。Go1.22.2 execution trace未截断，共534521事件、630组首尾标记；`trace-correlations.json`／`trace-compact-evidence.json`保留关联。incrementalRefresh5/15为3.919ms：`checkpointSlotRecord`的append分配直接触发GC sweep termination；该请求与1.593ms并发mark重叠，服务goroutine另有0.901ms Runnable。home10/21的`decodeCheckpointSlots`有137µs mark assist。这里证明具体分配与GC活动发生，不能把并发GC全时长当作阻塞，更不能据此解释旧5bf不同轮次的0.4秒Tail。Go1.22 trace v2未处理-pprof参数而会启动查看器，本次按实际工具源确认使用纯离线`-d=1`，没有监听服务。
- 已确认的一处分配开销是每次双槽解码返回实际JSON的切片，却使整个36KiB容器逃逸；每个正常V2业务请求在候选读取、最终读取、writer重核对中出现三次。修复仅将该容器变成函数局部固定数组、用`bytes.Clone`返回两个已验证JSON；签名消息同样改局部固定数组，完整V2前缀／记录字节不变。没有池、解析结果缓存、授权缓存或新格式，仍每次fresh读文件、检查普通文件／精确长度／头和两槽padding／两槽完整签名／序列及内部anchor签名；写入、fdatasync、关闭、SQL提交和原子控制路径不变。
- Go1.22.2逃逸分析确认两个scratch不逃逸。原／新各六次`benchmem`完整记录`ultra-ef-allocation-before-01.log`／`after-01.log`：decode 41168→848 B/op，read_anchor约42251→1882 B/op，record32768→16384 B/op；按该fixture三次decode＋一次record约减少137KB/request。此为可复现分配量，不是接口p95验收；早期诊断解码存在并行CPU活动，微基准耗时不作受控速度结论。没有为此重复旧正式三轮或刷到通过。
- 新所有权反证覆盖普通／8192字节最大payload、完整V2签名、调用方输入变动、连续原子改写／后续解码／GC后已返回JSON仍独立，两个返回payload互不别名。`ultra-ef-buffers-unit-02.log`原坏槽／签名组加新反证-race PASS15.975s；`ultra-ef-buffers-host-02.log`完整go test/build/vet与改动文件gofmt PASS。`ultra-ef-buffers-pg-02.log`真实一次性PG-race聚焦PASS 274.341s，包含C/V只读中断续行、回滚／错误前驱／冻结、临时证据中断、JSON/V1升级、部分写和损坏拒绝、memo新鲜读取及prepared六列表／九图／增量并发，未将无DSN的unit当PG证据。
- 最终隔离副本`ef-buffers-final-01`从ef完整Git archive建立，`ultra-ef-buffers-source-final-02.json`核对837项：binary原bytes、明确UTF-8 shell LF、Git执行位和symlink；两个产品／测试覆盖单列，普通文件权限明确644／755，不带archive775／664的group写位。源码与最终D文件对应。该提交只修复已证明的大块分配，最终完整21项40%与手机25%／布局仍须独立验收。

## 2026-11-16 f6独立验收通过与最终主线对齐

- [Feed CI43876403002](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43876403002) 的actual source为 `56531e79a6b51154296f2b0545b5181dd7792822`，parents为main `bf5c0aecd6ef4f8c8ee0aa584c5ec9aaaf0bcabd` 和f6。正常merge `a01ae5e4a413b59b2ce998f964403659151c92b6` 与其tree精确同为 `908d73fbfad52be350c08d78ca37055cdc8b956b`。main新增8文件为评论同post回复计数条件、0048 likes索引与相关迁移断言／CI／文档，不改移动构建输入；本次只更新任务记录，不改被测产品文件，不重采正式轮。
- Sol独立校验三zip SHA256并直接重算全部42组的90条guard及80条raw最近秩p95、21个降幅，无剔样／校正，`Complete/PASS=true`。原始 `ci-f6-feed-batch-performance.zip` SHA256 `9f66628f2a9cc3807ecda5da62dc68911166580080c1d6ef54b2868d29dcd34f`；timing为 `dbc8f9c2c191c9c07050eb9b1509693029ac40d27704ef97678bdd7166a51fd0`；tail为 `5d042266c255b5770d185cdc4126ccff652271b7419df6196bb430694ab5bd84`。审计产物 `sol-f6-ci-independent-audit-02.json`；首个只读工具要求Errors字面值[]而遇Go合法空slice的null，断言FAIL保留为01-fail，后续只兼容两种空集合，未改原data／guard／门槛。
- 630诊断仍以 `Diagnostic=true/DiagnosticOnly=true` 独立保存，不能混入formal。该轮成功不证明旧5bf约0.4秒Tail已修；只确认已定位的大块分配被移除以及这一完整新轮达标。此前所有有效FAIL、invalid、原始zip、trace和未复现原因均保留。
- Sol对13行buffer差异独立审查未见确定缺陷。新完整f6 archive的API＋全部infra＋packages共837项raw／链接目标匹配，模式明确644/755，媒体go-w要求在预检实际断言；没有全文件normalize。`sol-f6-focused-01.log`的ownership／最大长度／V2签名及native／真实PG／TLS聚焦PASS；未重复未变全C/V大套。此前ef聚焦原aggregate FAIL仅为archive775/664导致validator拒绝；mode-only修复记录在 `sol-ef-source-mode-repair-02.json`，只复验九图／geometry的02.log PASS6.079s，原aggregate未改称PASS。更早34个binary恢复与687项文本LF差异的历史证据也保留。
- 完整移动输入复核支持App5bf r6／server f6（728项）及Appdebc／server3746（727项）的精确复用，Git树／raw／r5注入／SDK与CLI flags证据在手机目录；新main bf5不改apps/packages，后续控制server须使用完整bf5、最终server使用完整a01，不把旧3746／f6 runtime说成新server。旧软件HOST smoke分别在全新私有PG真实发布12帖、验证CA／hostname／受保护169686-byte WEBP后正常停止；本轮f6为15.385s，不是手机数据。新手机测量矩阵保留完整1d→最终25%总收益硬门槛，最新main→最终净收益独立报告，不新增第二25%门槛，也不把004收益说成002净收益。
- 当前全部17类workflow成功；AuthGate完整步骤PASS，适用SKIP不扩大为验收。手机仍无设备且旧lease失效，安装／native storage device／触发→交互25%／真实decode布局均NOT_RUN。所有本任务测试／HOST fixture／构建进程已停止，未触用户原App、正式数据或生产环境。

## 2026-11-16 a3注册夹具跨窗口失败与确定性修复

- [Feed CI43880785956](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43880785956)／job133345782327的source `6362b06c71cc830b91f9091b8d29e212b179b49b`、tree `3349bc7903962f29c33534dc81b8ac6f9fd92f9f`与a3精确一致；a3相对a01只有任务记录31+/6-，生产差异为零。`TestFeedViewsAccountDailyConcurrencyPostgres`在13:59:59.0027671Z开始，14:00:00.2199708Z于注册owner处返回`registration ticket not yet valid`，authprivacy aggregate FAIL182.678s；后续独立C/V、stage及正式性能SKIP，不是40%新FAIL。该轮最终16类PASS、仅Feed前置FAIL；always 630诊断PASS不能代替formal。
- 原始脱敏窗口`ci-a3-registration-not-before-failure-excerpt.log` SHA256 `29586417D66688E8211886545D7CD68B668E4891CED52E962CEBF181356D8BCF`及source.json `63CA84FB47398310E39595180A7BAC59F0CD304F91FFCE9F4E16A20A45EAFC97`保留；唯一`ci-a3-feed-tail-diagnostic.zip`为`0A6DA57A92B0C58218BBB3C40D48F644CB47A1080D56D9ADE8C93CB0374248E5`，仅诊断。此前56531／908d的全套PASS及所有历史FAIL不改写。
- 根因在测试夹具混用时钟：`newGateControl`冻结C决策时间，而`lab.ticket`仍查询真实PG `clock_timestamp()`，初始化跨半小时后签出的新window相对冻结C尚未开始。修复只让受控lab的出票绑定同一个`clock.now`；普通`newLab`保持真实PG时间。生产`ValidateAdmissionWindow`、未来／过期拒绝、安全Gate和时钟来源均未改；没有等待边界、改系统时钟、重试票据或放宽时间窗口。
- `ultra-a3-registration-red-01.log`用原a3夹具＋新增回归得到预期aggregate FAIL8.966s：把受控C推进至与SQL相隔至少两个窗口，边界前1µs／准确边界／后1µs三例均因旧出票时间而expired。这证明旧混钟缺陷，**不是逐字复现CI的not-yet-valid**；另一真实C反例以有效签名的下一window票据在边界前1µs获得`ErrTicketNotYetValid`，与CI方向一致，过期票据仍为`ErrTicketExpired`，且无账号／intent创建、Gate代次不变。
- 同一回归在修复后的完整C出票→CreateSignupIntent→CommitSignup→session授权路径通过三个边界点。`ultra-a3-registration-green-01.log`真实自有PG `-race`聚焦PASS43.236s，含原FeedViews并发用例PASS6.05s、过滤绑定、普通newLab登录／撤销、Gate恢复／最终冻结与续期／pending代次，以及未来和过期票据反证。未选择的HTTP等包为no tests to run，不扩写覆盖；未重采正式性能。
- 初次host收尾脚本遗留`FEED_GOOSE`但无DSN，迁移测试正确拒绝“owned migration fixture required”，原`ultra-a3-registration-host-01.log` FAIL保留。清除夹具变量后`host-02.log`完整go test/build/vet/gofmt PASS；只重跑host，没有重跑已通过PG。fresh a3 archive的`ultra-a3-registration-source-green-01.json`逐项核对839项raw／明确UTF-8 shell LF／Git执行位与symlink，三个_test.go覆盖单列，生产文件不变；`source-red-tested-01.json`绑定实际gofmt后的RED输入。所有自有测试／PG进程已退出。
- 本轮基线`a3f104dd136c3fdba8a7e7113a9f4d79695cf528`＋上述三份test-only差异的本地证据完整，交Sol独立复核后再推送并由入口Session跟进新head适用CI。手机25%／真实布局仍NOT_RUN，既有任务push／PR／CI授权持续，不沿用过期设备租约安装。

## 阻碍与下一步

SQL与接口40%两项硬门槛已在56531／908d完整产品上PASS，三项整体尚未完成；最新a3前置失败的test-only修复尚待独立复核及新head CI。当前缺Xiaomi15（`63005867`）真实连接及本任务有效独占租约；旧租约20:19已过期，不能沿用过期租约安装。设备恢复时先由入口Session核对连接和归属／刷新租约，再启动独立`.req002`的smoke，用户原App不操作。规则版本AGENTS `a4d7228a0dd4b91e851746ab7f9fb37d1ec806b5`／CONTRIBUTING `9937638c077bf2da7d51daa5de13a83645dc4320`未变。

1. 在完整bf5控制server／完整a01最终server来源与App输入等价证据更新后，使用新owned smoke fixture验证安装、native存储及真实UI／decode链路；不得沿用已消费publish/0或已停止的旧runtime／凭据。正式每版本再建固定61帖的新fixture，与smoke分离。
2. 同一设备／网络／合成发布序列，完整1d、最新主线控制、最终候选三版本，home／older／refresh各10预热＋80正式原始样本；每次刷新真实发布12帖。保持原25%及既定手机时钟保守界，不剔样；单独受控图片decode全局Rect／滚动idle证据完整后才能关闭布局门槛。
3. 先完成本轮注册夹具修复的Sol独立复核及新head CI，保留a3原前置FAIL／后续formal SKIP。保留所有历史FAIL／invalid和Tail原因未定的结论；不为文档提交重采接口性能，不把17类CI／HOST smoke／APK构建代替手机结果。任务仍不标ready或发布。
4. 按已有授权推送本任务分支、由入口Session更新draft PR并跟进后续适用CI。远端合并和正式部署仍未授权。
