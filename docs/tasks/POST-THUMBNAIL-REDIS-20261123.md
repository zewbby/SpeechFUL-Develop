# POST-THUMBNAIL-REDIS — 帖子缩略图 Redis 热缓存

- 模式：常规
- 负责人／状态维护人：当前 Session
- 执行 Session（指挥模式）：无
- 分支／Worktree／PR：`codex/perf/post-thumbnail-redis`；`E:\speechful-post-thumbnail-redis`；未创建 PR
- 本轮规则版本（指挥模式）：不适用
- 授权依据与边界：用户“阅读并完成任务”并指定《SpeechFUL 帖子缩略图 Redis 缓存实施方案（2026-11-23）》；该方案不授权 push、合并、试用环境升级或生产部署，本记录不产生新授权
- 需求确认：以方案正文为实现契约；默认关闭，PostgreSQL 仍为原图、衍生字节、版本、可见性与最终授权权威。未决产品取舍：Redis 私有副本最大逻辑残留时间、每实例资源预算、目标流量分配、生产开关阈值；若要求删除与 PostgreSQL 同事务抹除 Redis 字节，本方案不满足，生产开关保持关闭。迁移因基线已有 `0054` 顺延为 `0055`
- 更新日期：2026-11-24
- 状态：实现 已完成（本地提交 `176b1f0`）；验证 进行中（静态/单元/真实 Redis/迁移冒烟 PASS；真机同客户端复用 A/B PASS；真实隔离 lab 全矩阵与 Redis A/B NOT_RUN）；合并 未合并；发布 未发布

## 目标与范围

在既有 PostgreSQL 私有缩略图复用路径前增加一个可丢弃、默认关闭的 Redis 热缓存，仅覆盖 `thumbnail-v1-640` 的受保护读取：

- 请求仍先读 PostgreSQL 元数据、执行原最终授权事务；Redis 命中值按 PostgreSQL 元数据校验长度、宽高、WebP 容器与 SHA-256，最终事务再次核对来源证明和衍生行身份。
- 独立 Redis 实例、`allkeys-lfu`、固定绝对截止时间；失败/超时/坏值回落有界 PostgreSQL 读取，再回到既有生成路径。
- 只有已存在的 PostgreSQL 衍生行且本次授权成功提交后才回填；`SET NX PXAT`，队列有界，截止时间锚定最终授权时间。
- 新增同事务 `AFTER DELETE` outbox、租约删除 worker、聚合指标、配置样例、授权脚本与设计说明。
- 不包含原图、头像、评论/私信图片、查看器保存、公开 URL、客户端离线缓存；不改客户端入口。

## 接口与依赖

- 新增 `internal/postthumbnailcache`：配置、键构造、`GETRANGE` 读取校验、有界回填队列、`UNLINK` 删除、熔断、指标。
- `authprivacy` 新增可注入 `thumbnailHotCache`；`WithPostThumbnailRedisCache` 启动时校验 outbox/触发器/函数摘要与运行时权限。
- 迁移 `0055_thumbnail_cache_outbox.sql`；授权 `infra/postgres/grant-post-images.sql`；示例 `infra/postthumbnail/redis.example.conf`。
- 运行时配置 `postImages.thumbnailRedis` 必须同时启用 `thumbnailReuse` 与 `preparedMediaReads`，命名空间绑定环境，地址须区别于共享准入与评论快照 Redis。
- CI `post-images.yml` 增加一次性 Redis 7.4 容器与命令/过期回归；隔离 PostgreSQL lab 仍须 Linux unix socket 环境。

## 验收标准

- 未配置 Redis 时行为与基线一致；配置非法、schema/触发器/权限不符、探测失败时启动失败关闭。
- 热路径：Redis 有效命中有界且不读 PostgreSQL payload、不进入 Python 生成；未命中/坏值/超时回落，输出与原路径一致。
- 回填：现场生成、授权冲突、提交失败均不回填；已存在衍生行且提交成功后只回填一次，绝对截止时间不晚于最终授权时间 + TTL。
- 删除：衍生行删除在同一 PostgreSQL 事务产生 outbox；worker 以租约认领、事务外删除精确键、可重试/接管；禁止 `KEYS`/全扫描；积压与最老年龄可见。
- 指标不含键、帖子/账号 ID 或令牌标签；日志仅聚合计数。
- 真实 PostgreSQL/Redis/Python/HTTPS 与 A/B 性能证据按方案矩阵记录；缺证据不得声称生产通过。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | 提交 `176b1f0`，基线 `bc599b342da707169e55ddff90e8f2a54fc751cc` | 读路径、Redis 包、0055 迁移、worker、schema 校验、运行时装配、样例与文档；默认关闭 |
| 静态检查 | `176b1f0`；Go 1.22.2；`GOOS=linux GOARCH=amd64` | `go build -mod=readonly ./...` PASS；`go vet`（`postthumbnailcache`/`authprivacy`/`authprivacyruntime`）PASS；15 个改动 Go 文件去 CR 后 `gofmt -d` 无差异；`authprivacy`/`authprivacyruntime` 测试二进制交叉编译 PASS |
| 单元测试 | `176b1f0`；Windows amd64，Go 1.22.2 | `go test -count=1 ./internal/postthumbnailcache` PASS（配置/键/GETRANGE/NX PXAT/队列/熔断/删除/指标） |
| 真实 Redis | `176b1f0`；Redis 8.10.3（Windows 构建），`127.0.0.1:6391`，一次性无持久化实例 | `TestCacheAgainstRealRedis` PASS：写入、绝对 TTL、NX 不覆盖、同长损坏/超长拒绝、UNLINK |
| ACL 样例 | `176b1f0`；同上实例 | 受限用户 `~hnuhole:post-thumbnail:v1:test:* +ping +getrange +set +unlink`：`HELLO 3`/PING/GETRANGE/SET/UNLINK 可用；命名空间外键与未授权 `GET` 均返回 `NOPERM` |
| 真实 PostgreSQL 迁移冒烟 | `176b1f0`；Windows 便携 PostgreSQL 16.4，一次性本地集群 `127.0.0.1:55432`，最小 `c_posts.thumbnails` schema | PASS（仅迁移/触发器冒烟，非隔离 lab）：0055 Up 在事务内应用；函数 `prosrc` 去 CR 后 SHA-256 等于 `c709eae...`；触发器 `AFTER DELETE FOR EACH ROW`（mask 9）参数/条件/列/约束均空；PK `event_id` 与两个部分索引有效；运行时仅 SELECT/UPDATE/DELETE，无 INSERT/TRUNCATE/REFERENCES/TRIGGER/EXECUTE；以运行时角色删除衍生行仍由 definer 触发器生成且仅生成一条字段一致的 outbox 事件，直接 INSERT 被拒；更新后授权脚本 0055 块可重复执行；Go `checkThumbnailCacheSchema` 原始查询在 superuser 与 `SET ROLE hnuhole_c_runtime` 下均返回 true。冒烟中发现并修复 PK 断言误用 `NOT EXISTS` 及 `notnull` 别名语法问题 |
| 真实 PostgreSQL lab（全矩阵） | WSL2 `Ubuntu-2404`（Linux 6.6.87.2）；一次性 private unix-socket PostgreSQL 16.15；Pillow 12.3.0；真实 HTTPS C/V Gate fixture | NOT_RUN：WSL2 已可用，真机 fixture 已在隔离 private-socket PostgreSQL/Python/HTTPS 上跑通（见下行）；`run-post-images-isolated.sh` 完整矩阵尚未执行，不以 fixture 代替矩阵通过 |
| 真机同客户端复用 A/B | Xiaomi `24129PN74C`（Android 17／SDK 37，HyperOS V816）；代码 head `2e8bb2f`（APK 构建后工作树无产品差异）；profile APK SHA-256 `e1754fcbd70026152762d12b0640f1e8d34b735c7140ad8b513b0d156d152fa4`；WSL2 一次性 private-socket PostgreSQL 16.15＋Pillow 12.3.0＋真实 HTTPS C/V Gate；`/baseline` 仅 `WithPostImages`，`/reuse` 另开 `WithPostThumbnailReuse`，Redis 未启用 | PASS（同客户端开关归因，≥30%）：8 轮，前 2 轮预热，6 轮交替配对记录；基线（上中位）546.707ms、复用 359.552ms，下降 **34.23%**；中点中位 536.679/359.338ms＝33.04%，均值 531.366/359.904ms＝32.27%；12 样本；每轮首屏可见图片实际绘制，原生 vault 每轮 6 读 0 写；测试 status=PASS。原始结果 `.zcode/req004-result.json`，设备日志 `.zcode/req004-device-run.log`。边界：仅证明当前客户端复用开关收益；REQ-004 正式“双版本完整比较”验收与 Redis 热缓存增量均未由本结果覆盖 |
| Redis A/B 性能 | 真实 HTTPS + PostgreSQL + Redis | NOT_RUN：Redis 热缓存三组配对 A/B 尚未执行；上行真机 A/B 仅比较复用开关，不含 Redis，不能作为本行证据 |

## 阻碍与下一步

- WSL2 实际发行版为 `Ubuntu-2404`，unix socket PostgreSQL 与 Go/Python fixture 已可用；此前“WSL2 不可用”的判断来自错误的发行版名，已由本轮消除。原生 Windows PostgreSQL 仍不满足 unix socket 隔离条件。
- 待完成：执行 `services/api/authlab/run-post-images-isolated.sh` 的完整矩阵（真实 PostgreSQL/Redis/Python/HTTPS、双账号、替换/隐藏/删除、撤销/代次、提交 ACK 丢失、Redis 故障与删除竞态），以及 `TestThumbnailRedisPerformancePostgres` 三组配对 A/B；记录 p95 与计数。真机同客户端复用 A/B 已完成，REQ-004 正式“双版本完整比较”30% 验收仍待按该口径单独执行。
- 产品待决：最大逻辑残留时间、每实例资源预算、目标流量分配、生产开关阈值；若要求删除与 PostgreSQL 同事务抹除 Redis 字节，则该场景不得开启，生产开关保持关闭。
- 本地提交 `176b1f0`、`2e8bb2f` 已形成；未 push、未创建 PR、未合并、未部署，等待用户就推送/PR 另行授权。
