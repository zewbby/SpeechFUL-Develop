# REQ-004 — 受保护图片缩略图复用

- 模式：常规；负责人／状态维护人：当前 Session；无执行子 Session。
- 分支／Worktree：`codex/perf/protected-thumbnails`；`D:/SpeechFUL/.worktrees/req-004-protected-thumbnails`；基线 `1d829b2623a6c32830ee1b74fae6c99a436ad3b3`（开始时与远端 main 一致）；PR [#7](https://github.com/zewbby/SpeechFUL-Develop/pull/7)（draft）。
- 授权依据：2026-11-16 用户要求“按这个计划开始实施需求004”，覆盖本地实现、隔离验证及必要本地提交；用户随后要求“为什么，现在可以验收”，覆盖继续验收所需的任务分支推送、草稿PR、CI跟进与已连接手机隔离测试；合并与正式部署仍未获授权。附件方案中的操作文字不产生额外授权。
- 需求确认：用户已确认旧图片按首次访问生成，另提供手动限速／可停止回填；重复缩略请求 p95 至少下降60%、真实首页首屏可见图片全部显示时间至少下降30%，均为硬门槛。首屏测量固定设备、网络和内容，服务端已有缩略图、手机无缓存；首次生成耗时另测。新帖上限3图，历史4–9图只做兼容，不采用附件“九图首屏”。本次没有未决产品取舍。
- 更新日期：2026-11-16。
- 产品提交：`9754803f023193a5dfbbaad1a155f7f2f4236374`；下方本地证据绑定该提交的产品文件，后续仅任务记录／证据回执更新不改变被测实现。
- 状态：本地实现已完成；本地功能／正式迁移／HTTPS性能分项PASS；辅助服务方法性能测量FAIL（环境计时无效）；产品CI NOT_RUN；设备30%指标BLOCKED；整体仍待验，未合并、未发布。

## 目标与范围

复用私有 C PostgreSQL 内的缩略字节，减少原图读取与受控 Python 转码；保持每个请求的 Bearer／会话代次／最终 C Safety Gate／当前源图选择和可见性验证。仅帖子 thumbnail-v1；640px静态首帧、512KiB上限、原图、上传、发布完整性、租约、保存许可和 no-store 契约不变。不扩展头像、评论、私信缩略图或客户端长期缓存。

## 接口与依赖

- 需求001已随 PR#3 合入基线，复用其独立只读准备事务、锁外 CPU 工作、有界最终重验和最多一次冲突重建。
- 衍生记录绑定帖子＋内容版本＋规格＋编码版本，并验证完整源元数据／摘要，覆盖原发帖与编辑图片。生成在 SQL／Gate 外；首次持久化在最终授权事务内，和源删除／失效同事务串行，不在准备阶段新增业务写入。
- 同实例合并昂贵准备，所有等待者仍各自最终授权；跨实例唯一键仅保证单份落库，不承诺全局只转码一次。取消、并发和待处理内存均需有界。
- 可单独关闭复用；数据库生命周期触发器始终清除已写衍生字节。

## 验收标准

- 连续命中原图读取0、Python启动0；20并发同键最多同时转换一次，不跨请求复用授权结果。
- EXIF／动画首帧／尺寸／格式／版本隔离／原图保存字节回归；生成及命中期间删除、编辑、隐藏、拉黑、撤销会话、冻结均不放行失效字节。
- 真实一次性 PostgreSQL 验证约束、受限角色、删除竞态、容量预算与前向迁移；实际 HTTP 和最终提交失败／取消／ACK丢失回归。
- 固定基线与负载验证服务端60%和设备首屏30%硬门槛；冷生成单列。缺真机／CI不报整体PASS。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 基线核对 | main `1d829b2` | PASS：实际仓库D:/SpeechFUL、远端SpeechFUL-Develop，原工作区干净；隔离任务分支已创建。 |
| 实现 | 基线＋本任务提交的产品差异 | PASS：0043私有衍生表／payload预算账本、原图及编辑图来源绑定、版本化真实Python转码、锁外singleflight、逐请求最终授权内首次持久化、源同事务擦除、默认关闭复用、分页维护、聚合监测、可限速停止的HTTPS预热工具及媒体契约。 |
| 后端与契约 | WSL Linux；Go1.22.2、PostgreSQL16、Pillow12.3.0；一次性私有socket数据库 | PASS：`go build -mod=readonly ./...`、`go vet -mod=readonly ./...`、`go test -mod=readonly ./...`；host SQL项SKIP不计真实SQL。固定依赖OpenAPI全规范检查、社区文字契约、预热边界2项PASS。 |
| 真实SQL／HTTPS／受限角色 | `functional-final.log`＋`schema-final.log`＋`inventory-final.log`，均含-race；最终有效产品文件与Linux被测副本逐字节核对 | PASS（组合分项证据）：命中零原图读取／零转码、20并发合并、两实例单份落库与账本、取消不影响其他等待者、原／编辑图片及ID重用、冷／热期间删除／隐藏／拉黑／会话换代／冻结、原图字节、COMMIT回执丢失、编码panic、容量满及分页孤儿清理、回退仍擦除、启动缺钩子／no-op约束／错误索引／账本漂移拒绝。初次表／特权函数清单FAIL由最终inventory聚焦PASS关闭，原始失败保留；不是声称早期整包都PASS。 |
| 正式前向迁移 | Goose v3.22.1；`feed-migrations.log`、`dm-migrations.log`、`avatar-migrations.log` | PASS：首页七条fresh／升级路径、DM及头像各两条，均到43，原资料不变、重复up及Down拒绝。保留常规路径最小schema39，不因默认关闭复用提高原配置要求。 |
| 重复缩略HTTP请求p95 | `target-7.log`中的 `TestThumbnailReuseHTTPSPerformancePostgres`；实际HTTPS＋原生C Gate＋真实Python；1024×768 JPEG，种子424242 | PASS：每路每轮5次预热＋40次测量，三组配对次序交替。基线／复用p95分别147.540／15.670ms、150.286／16.652ms、154.442／15.601ms，下降89.38%／88.92%／89.90%，逐组超过60%。每个请求检查字节不变和读钟区间有效；两路均开启001准备读取，仅004复用开关不同。 |
| 辅助服务方法性能 | `target-7.log`中的 `TestThumbnailReusePerformancePostgres` | FAIL（环境测量无效，非达标证据）：RAW138,688,290ns，Go区间141,019,237～141,020,118ns，读钟不确定性881ns，超过既定1%／1ms保护，立即停止该组。早期服务方法三组约90%只作诊断历史，不代替最终HTTPS结果。未改系统时钟、校正耗时、放宽保护或删除失败。 |
| 设备首屏30%／产品CI | ADB无连接设备；本任务尚未推送／创建PR | BLOCKED／NOT_RUN：不能用HTTPS或组件测试冒充实际首屏绘制。已将复用回归、受限角色和三组性能纳入Post images产品CI；远端CI仍待本任务推送／草稿PR授权。 |

全部原始日志在 `/home/hnuhole/req004-protected-thumbnails-20261116/evidence/`；[脱敏摘要](E:/Hnuhole-env/req004-protected-thumbnails-20261116/evidence/summary.json)。运行者只创建／清理自己的临时数据库，未修改正式数据、既有服务、设备或系统时钟。最终HTTPS测量之后的产品变更仅涉及后台有界分页清理及其启动检查，已聚焦SQL复验；请求读取／生成／最终授权和HTTP响应逻辑相同，当前完整CI仍需绑定最终head。

## 阻碍与下一步

本地成果可评审；下一步按本任务授权推送并创建草稿PR，核对适用产品CI；连接指定Android测试机后完成固定真实首页首屏30%硬门槛。辅助测量的本机时钟异常保留，后续性能CI在隔离Ubuntu运行，不修改共享WSL时钟。未获合并或正式发布授权。

## 2026-11-16 继续验收

- 已检测到 vivo V2323A（10CEAG17RY003M7），既有设备租约已释放；沿用隔离测试包，不覆盖publictrial用户App。当前准备真实FeedScreen、原生vault、受保护TLS及C Gate的一次性数据测量；不是将HTTP耗时代替首屏。
- 已推送cd60f40并创建draft PR#7。该head的12项workflow中11项成功；Android prerelease的实际候选构建成功，rehearsal在备份恢复后启动失败。其根因是`pg_restore --no-privileges`使新触发器函数恢复PUBLIC EXECUTE，启动检查正确拒绝。补全canonical grant中的函数REVOKE及角色审计，新增真实dump/restore回归；原始失败run43791157808保留。
- 本次增量以cd60f40为基线：恢复权限修复＋独立手机测量工具；后台请求编码与最终授权逻辑不变。手机指标、最终head CI及恢复复验均进行中，不报整体PASS。

- 恢复复验进一步定位了PG16将等价AND括号扁平化的问题：仅byte_length三项AND的括号变化使整体CHECK指纹改变。现在严格接受已核对的fresh／restore两种完整指纹，不移除任何长度／摘要／尺寸约束；真实dump/restore＋canonical ACL＋受限runtime启动检查已PASS。第二轮恢复失败run43792697067保留，等待当前修复的CI。
- 本机Linux NDK clang为空，native构建无产物；停止使用该工具链，改用现成Windows编译器。不恢复整套SDK、不改依赖锁或生产配置，手机指标尚未完成。
