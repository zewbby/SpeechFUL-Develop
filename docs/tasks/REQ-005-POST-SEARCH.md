# REQ-005 — 帖子搜索查询加速

- 模式：常规；负责人／状态维护人：当前 Session。
- 分支／Worktree／PR：`codex/perf/post-search-documents`；`D:/SpeechFUL/.worktrees/req-005-post-search`；PR 未创建。基线 `47bf7e9c3231e3e45e078280086d7fc45025f4d9`（2026-11-16 已 fetch 并核对 origin/main）。
- 授权依据与边界：用户先要求 plan，随后确认性能硬门槛，再要求“拉分支开始做，视情况变化调整，不要死板一直按照计划”。授权本任务隔离实现、验证及必要本地提交；未授权推送、PR、合并或部署。需求附件的流程文字不另产生执行授权。
- 需求确认：保留中文及 Unicode 字面子串、ICU lower、相关性与最新排序、频道分组、过滤、全局 search_content_revision／旧游标失效、最终 C Gate 重验和一次重试；优化候选查询及续页成本。用户结构化回复“采用硬门槛（推荐）”：固定10万篇及相同负载，选择性较高的≥3字搜索 p95 降低≥50%；1～2字和高命中词分别报告，p95 均不劣化超过10%。基线阶段冻结词集、首屏／续页场景及重复轮次。无未决产品取舍；根据证据调整技术细节。
- 更新日期：2026-11-16。
- 状态：实现 进行中；验证 FAIL（修复后待验）；合并 未合并；发布 未发布。

## 目标与范围

建立当前公开内容搜索读模型、同事务同步、可恢复回填、pg_trgm 候选索引及查询开关，交付新旧逐页差异检查、并发故障验证与性能报告。保留业务表最终授权，沿用现有搜索界面、历史及精确标签页契约。回退至旧查询后仍维护读模型。

## 接口与依赖

- 需求001已由 PR #3 合入本基线；搜索本身已有 Gate 外 prepare 与最终事务批量投影，不重做授权基座。
- 主线包含0045标签post_id索引及0046同步跳过优化；搜索 lower 使用 `und-x-icu`，不复用使用 `C` lower 的标签索引键。
- 新路径显式开关默认关闭；完成一致性校验才允许启用。迁移、运行时最小权限、历史schema及正式 Goose 升级共同验证。
- 验证仅使用任务自建 WSL2 Linux 文件系统上的一次性 PostgreSQL；不得连接正式／日常业务库。

## 验收标准

- 新旧结果逐页一致，覆盖中文1／2／3字、中英混合、Unicode大小写、标点、`%`／`_`／反斜杠、标签边界、无命中／高命中、编辑后当前内容，两种排序、全频道／单频道及 lookahead。
- 发布／编辑／删除／审核／内容擦除与回填交错无漏更新；最终重验拒绝旧内容、撤权与版本冲突；旧游标按原规则拒绝。
- 100,000篇、冻结的相同数据与负载下，选择性较高的≥3字 p95 降低≥50%；短词与高命中词 p95 各不劣化超过10%。单列首屏／续页、SQL扫描量、索引体积及写入额外耗时。
- Go格式／构建／test／vet、真实SQL／迁移／最小权限／HTTPS和适用产品CI证据绑定最终代码；缺项如实待验。

## 当前进度与证据

技术调整（固定负载未变）：首轮诊断显示两字词及高命中词退化。实际SQL探针证实原夹具的数据库 `LC_CTYPE=C` 下，直接中文文本的 `show_trgm` 为空，给索引指定ICU也不能解决；10,000行小样本中文索引重验10,000行。改用ICU lower之后的UTF-8 hex ASCII候选键，探针同词只访问10行，仍在排名／LIMIT前用逐字段／逐标签strpos精确复核。短词／不可提取词回退原查询，候选事务局部force_custom_plan避免复用稀有词的通用计划。新增ICU实际版本标记，升级后不允许使用未重建的规范化数据。首轮3样本诊断不是验收PASS，保留在外部 `perf-diagnostic-v1.json`；正式负载、门槛和三轮规则未变。

第二轮诊断 `perf-diagnostic-v2.json`：三类选择性词端到端降至约27–54ms，中文实际GIN候选100行；高命中词仍慢，EXPLAIN显示优化器将实际100,000行估为10行，导致100,000次posts主键查找。新增最多128行的SYSTEM页采样（只读、Gate外）选择执行路径，样本至少32行且命中≥25%时走完整原查询；它不限制或抽样搜索结果，也不作为授权依据。短词直接原查询。此项处理宽编码键缺少有效列统计的实际问题，性能负载／阈值保持v1。

首次正式三轮（产品`ae4ad28`）FAIL：36项中高命中首屏第1轮602.19→667.83ms（1.109倍），超过1.10；其余35项达标，不能替代整体通过。readtiming显示该轮候选查询574.12→586.43ms，路由0.43ms，anchor_write尾延迟36.88→132.98ms；主要差异在anchor I/O，未修改Gate或放宽验收。保留完整`performance-ae4ad28-fail.json/log`。为增加真实查询余量，将高命中路径改为无LIKE／GIN的全量规范化文档精确扫描，减少跨表拼装，仍按原完整候选排名及分页；低频索引和短词回退不变，重新绑定版本验收。

扩大schema回归发现并修正：`TestPostSchemaPartyInventoryAndPrivateColumnsPostgres`禁止c_posts内视图；统一源定义改为owner-only规范化函数（点查与全量校验使用独立常量SQL形状），不放宽既有无视图约束。函数同样校验body摘要并撤销runtime执行权；失败日志`backend-full-v1-fail.log`保留。之前只针对源视图的证据不冒充此修订通过。

并发复核：回填按keyset处理且不等待已被业务占用的帖子行，遇忙停止在该行之前，首次即忙返回-1；运维脚本有界重试，提交游标保持原位。避免与账号清理等多帖事务的不同锁序形成循环等待，也不因SKIP LOCKED跳过历史缺行。同步函数仍在同一帖子行围栏后重读当前源数据；编辑、删除与回填不允许旧批次覆盖新状态。

性能口径 v1（首次大数据测量前冻结）：100,000篇当前公开帖，固定 `req005.post/task.<n>` ID 和 SQL种子；每篇普通正文重复8次，中文标题稀有词每997篇、ASCII正文词每701篇、中英混合标签词每571篇。词集依次为 `稀有词`、`needle`、`Lab研究`、`学`、`校园`、`校园生活`；前三项按50%门槛，后两类短词及高命中词按110%上限。全频道 relevance，页大小20，首屏及第二页分别报告；同库同配置、单并发、12连接上限、每轮每路径预热3次与测量20次，旧／新成对交替顺序，固定3轮且每轮分别判定，禁止挑轮次。两种排序／频道范围的全部组合由等价性回归覆盖。`POST_SEARCH_PERF_QUICK=1` 仅跑1轮／3样本诊断，绝不计为硬门槛验收。端到端样本走原生C Gate（测试可信时钟固定以避免长测量过期），同时记录 readtiming 阶段及实际生产SQL的 EXPLAIN ANALYZE BUFFERS、索引体积、1000行回填批次耗时和事务回滚的写语句额外成本。

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 入口核对 | `47bf7e9`；D盘源码库／origin SpeechFUL-Develop | PASS：隔离分支已建立，原 main 与其他 Worktree 均保留 |
| 实现 | 上述基线＋本分支产品差异 | 读模型、事务同步、可恢复回填、索引与路由、独立开关、schema／权限完整性检查及性能workflow已接入；性能待正式验收 |
| Go基础检查 | Go1.22.2／WSL2；`go test -mod=readonly ./...`、`go build -mod=readonly ./...`、`go vet -mod=readonly ./...`、回填脚本`sh -n` | PASS；外部任务目录 `host-go-test.log`／`go-build.log`／`go-vet.log`。无DSN的host测试不证明SQL |
| 聚焦真实SQL＋race | PostgreSQL16／Goose3.22.1；任务独占Unix socket、一次性C/V库；`FEED_TEST_RACE=1`聚焦fixture | PASS：7种Goose升级、等价性、注销／隐藏／删除／筛选／Gate换代／游标与重试、占用行回填断点、插入式发布、source view／函数／触发器／最小权限；`race-expanded-pass.log` |
| 运维回填脚本 | 同一一次性库，实际执行`backfill-post-search.sh 1` | PASS：独立提交回填、校验及VACUUM／ANALYZE；补验修复了环境PGDATABASE不展开URI的问题，现显式传入dbname |
| API／搜索客户端 | 仓库固定规范校验；Linux Flutter3.47.5、原锁离线依赖；搜索／API两文件；当前Dart探针＋真实C HTTPS／SQL | PASS：13份OpenAPI、29受保护操作静态检查；搜索analyze无问题、65项Flutter测试；当前编译Dart探针完整搜索链路通过；`openapi.log`／`mobile.log`及Dart SQL日志 |
| 邻接客户端扩大检查 | 同基线、Flutter及测试源码无差异；额外加入标签／编辑UI文件 | PASS：12项标签／编辑测试全过。原8项MediaComposerFixture超时定位为系统只有libsqlite3.so.0，测试原生资产要求libsqlite3.so；仅在任务私有lib目录建立别名并设置本次LD_LIBRARY_PATH，未改Flutter／夹具或系统库。`mobile-adjacent.log`；保留原失败日志 |
| 性能／远程CI | 固定口径v1；待下述正式三轮 | NOT_RUN；此前两轮quick仅诊断，不计硬门槛通过；远程CI、合并、部署均未执行 |

## 阻碍与下一步

无产品取舍阻碍。规范化函数版本的逐页等价、故障交错、回填、最小权限、7种Goose升级、无视图／私有对象清单及HTTPS回归已通过。最新quick诊断高命中首屏536.69→455.06ms、续页521.26→383.10ms，支持减少跨表拼装的方向；仍仅3样本、不作验收PASS。下一步固定修订提交并重跑同口径正式三轮；保留ae4ad28正式FAIL及所有诊断证据。

运维顺序（尚未执行部署）：先保持 `posts.searchDocuments=false` 应用0047，使用迁移owner明确设置 `POST_SEARCH_BACKFILL_DSN` 执行 `sh services/api/authlab/backfill-post-search.sh 1000`；每批独立提交，断点在 `post_search_document_state.last_post_id`，失败可重跑。双向全量一致性校验、VACUUM／ANALYZE完成后才显式开启 `posts.searchDocuments=true`。回退仅关闭此开关，保留表和触发器持续维护；需要重新全量修复时owner先关开关，将ready置false、last_post_id复位，再回填并校验。运行时只有读权限，不能自行标记ready或执行维护函数；缺结构、索引、同步hook、函数／视图完整性或ready时拒绝开启。
