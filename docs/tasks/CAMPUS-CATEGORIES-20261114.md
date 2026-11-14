# CAMPUS-CATEGORIES-20261114 - 优化校园分类

- 模式：常规；负责人／状态维护人：当前 Session。
- 分支／Worktree／PR：`codex/feat/campus-category-labels`；`E:/code_collection/java_code/SpeechFUL.git`；[私有 PR #151](https://github.com/zewbby/SpeechFUL-Develop/pull/151)（draft）。实际基线为 `zewbby/SpeechFUL-Develop` 的 `main@2fdf8f6a2b62d708d229e3fc372081df39f85bd0`，远端别名 `develop`；公开 `origin` 保留，未向其推送。
- 授权依据与边界：用户要求“新建分支，优化分类页面的标签，然后PR”，并指定 `https://github.com/zewbby/SpeechFUL-Develop.git`；后续要求将推荐分类改名并继续 PR，且明确指出 PR #151 三项失败需要勘察。授权本任务开发、关联 CI 修复、验证、提交、推送任务分支及更新原 PR。不合并、不部署、不修改正式数据。
- 需求确认：用户逐项指定七个原分类的新名称及三个新增分类，按提供顺序展示；后续明确将“海大安利”改为“吐血推荐”，其余分类保持不变。原分类保留 UUID 和 code，不迁移旧帖归属。示例说明分类语义，不自动建立固定主题标签或内容分类器。沿用既有布局、浏览与发帖独立选择、初始可见标志和权限检查；所有十类均可在完整目录选择。新增三类沿用非首批分类的初始标志，不自动改变用户筛选。无未决产品取舍。
- 更新日期：2026-11-14。
- 状态：实现 已完成；验证 BLOCKED（本轮本地回归 PASS；产品 CI 修复后的结果以当前 PR 检查为准，确认前保持 draft）；合并 未合并；发布 未发布。

## 目标与范围

依次提供：校园吐槽、避雷指南、吐血推荐、搭子寻觅、情感树洞、互助问答、人工智能、社团活动、求职经验、校友评论。新分类 code 为 `clubs`、`careers`、`alumni`，UUID 延续目录尾号 `008`、`009`、`010`。原科技分类承接人工智能、计算机交流与数码讨论；原情感分类承接表白、失恋、交友与深夜心情。

同步目录、翻译、图标、屏蔽上限、搜索分页及热榜容量，新增正式迁移，保留既有帖子、草稿、身份、屏蔽记录和排行榜输入关系。使用 hnuhole-ui-craft、frontend-design 与 ui-ux-pro-max 的一致性和长文案检查原则，不重设计页面；Flutter 定向数据库检索两次无匹配，采用实际组件布局和通用适配规范，不声称有专项检索结论。

## 接口与依赖

服务端 `/api/v1/channels` 在迁移后返回完整十分类；新客户端兼容完整七分类目录以支持先更新客户端，拒绝八／九分类及未知、重复或乱序目录。旧客户端仅接受七分类，后端迁移须配合客户端升级安排，PR 不执行上线。迁移不支持删除新分类回滚；已有内容只能冻结后前向修复。搜索游标继续满足既有 1024 字符上限并保留旧游标解码。

## 验收标准

- 七类改名、三类新增，名称和顺序与用户清单一致；旧 UUID/code、帖子归属和已存筛选不变。
- 浏览、独立发帖选择、搜索、屏蔽入口均接收十分类；末尾项目可滚动到达，窄屏／大字无溢出，选择后使用对应 UUID。
- 全部十类可屏蔽；搜索与热榜覆盖新分类，分页游标保持完整且受原认证与篡改校验保护。
- 新装及旧库升级均建立十分类，保留原业务事实；正式运行须先完成迁移。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 基线与范围 | `2fdf8f6`；Windows | PASS：私有主线、干净工作区、远端与任务分支已核对；公开仓库为快照，未向其推送。 |
| 实现 | 产品提交 `834a7cc87ad6bc9fe0f54ee8aac4912a1bb35034`，基线 `2fdf8f6` | 已完成：目录七类改名＋三类新增；原标识保留；屏蔽／搜索／热榜十类容量；十分类压缩搜索游标及旧游标解码；0040 正式迁移和运行时版本要求。后续仅任务记录链接更新不改变此产品证据版本。 |
| Go 聚焦回归 | 同基线＋最终 Go 差异；Windows；`go -C services/api test -mod=readonly ./internal/channels ./internal/posts ./internal/rankings` | PASS；含十分类目录、十分类热榜元数据、最大计数搜索游标与旧格式解码。Redis 真实实例用例因无专用 fixture SKIP。 |
| Go Linux 静态检查 | 同基线＋最终 Go 差异；`GOOS=linux go -C services/api build -mod=readonly ./...`、`go -C services/api vet -mod=readonly ./...` | PASS；编译与 vet 包含关联测试代码，不证明 Linux 测试或真实 SQL 已执行。Windows 全包测试受既有 `syscall.Flock` 平台依赖阻断，未修改该边界。 |
| Flutter 聚焦及关联回归 | Flutter 3.47.5／Dart 3.13.4；同基线＋最终 Flutter 逻辑差异；`flutter test --no-pub`，见下方文件清单 | PASS：界面等 8 文件 125 项；认证 API 48 项单独复跑通过，共 173 项。首轮认证 API 初始化因 PATH 缺 OpenSSL 受阻，追加已有 Git OpenSSL 后复跑；不是产品失败。 |
| Flutter 分析与依赖 | `flutter analyze --no-pub`；`flutter pub get --enforce-lockfile` | PASS；无分析问题，锁文件无差异。下载时仅为本进程导出 Windows 已信任公开根证书，未关闭 TLS 或改变全局信任。 |
| 渲染检查 | `apps/mobile/build/campus-categories-render/`；375×812、320×640／2 倍字／深色、812×375 | PASS：实际加载 HhNotoSansSC 字体并查看三张最终渲染；末项完整可见，可滚动选择十类，最小行高不低于 48。Flutter 宿主结果，不代替真机读屏和系统字体验收。CI 上传对应渲染目录。 |
| OpenAPI 与静态契约 | Python 3.12；固定 PyYAML 6.0.1、openapi-spec-validator 0.9.0；`packages/openapi/check-specs.py`、`tools/check-community-text-contract.py` | PASS：13 份 API 完整校验；29 个受保护操作的静态契约检查通过。 |
| 迁移辅助及协作工具 | `bash -n` 两个受影响 authlab runner；`python -m py_compile tools/prerelease/environment.py`；prerelease `test_environment.py`；协作 `test_collaboration.py` | PASS：shell／Python 语法；环境工具 3 项 PASS、Linux 所有权用例 1 项 SKIP；协作工具 19 项 PASS。工具单测不代替产品验收。 |
| 真实 SQL 与目标平台构建 | 本机无可用 WSL/PostgreSQL 和 Android SDK；`flutter build bundle --debug --no-pub` | BLOCKED：资源构建明确报 Android SDK 缺失，未自动安装大型 SDK。迁移新装、旧库升级、SQL 权限／HTTP／Redis 及 Android 目标构建由本分支 PR 的产品 CI 继续验证；缺口不记 PASS。真机／生产 NOT_RUN。 |

Flutter 文件清单：`campus_categories_test.dart`、`publish_category_test.dart`、`feed_ui_test.dart`、`post_search_test.dart`、`post_tags_test.dart`、`app_localizations_test.dart`、`community_localization_test.dart`、`auth_session_controller_test.dart` 共 125 项；`auth_api_test.dart` 48 项。日志在本机忽略目录 `apps/mobile/build/category-validation/`，不提交凭据、公开根证书、日志、构建产物或缓存。此后仅关联集成断言从七类改为十类及任务／迁移辅助记录变更，不改写上述本地测试证明范围。

## PR #151 失败排查与定向修复

用户后续确认“海大安利改为吐血推荐，其他不变”，已同步服务端目录、未合并的 0040 迁移、简繁英日翻译、测试和词汇表；保留原 `recommendation` code、UUID、顺序及其余九类。

旧 PR head `50215b9208948d9a3d32da724716393fe9bbe78d` 的 28 项检查为 24 PASS、3 FAIL、1 SKIP。三项错误均从对应 job 日志核实：

| 检查与证据 | 原因与修复 |
| --- | --- |
| [Android prerelease / rehearsal](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43597692690/job/132455737212) | `git archive` 整仓导出触发无凭据的字体 LFS smudge，失败于回滚源码导出。只归档实际构建需要的 `services/api`，保留解包路径和链接安全检查。新增真实临时 Git 仓库回归：全仓导出遇到不可用字体过滤器失败，后端导出成功。没有持久化 CI token 或放宽认证。 |
| [Direct message chat / reliable-chat-sql](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43597692747/job/132455660399) | 升级快照把分类改名、更新时间及新增三类误判成旧数据损坏。仅从原七类的保留快照排除允许变更的 `name/updated_at`，仍逐字段比较原标识和设置、账户、偏好；另经真实目录服务验证完整十类名称、标识、顺序和初始状态。私信消息、回执、配额及禁止向下迁移断言保留。 |
| [Feed UI / flutter-and-real-feed](https://github.com/zewbby/SpeechFUL-Develop/actions/runs/43597692880/job/132455685705) | `feed_api -> channel.dart -> flutter/foundation -> dart:ui` 使纯 Dart 真实传输探针 AOT 编译失败，本机已复现同一导入链。分类模型改用纯 Dart `meta` 注解，显式依赖已有锁定的 `meta 1.19.0`，无版本升级；未替换或跳过真实 HTTPS/SQL 探针。 |

`Comment snapshot Redis / actual-process-acceptance` 的 SKIP 来自既有 `workflow_dispatch` 条件；本任务未改条件、未触发历史人工验收，也不把 SKIP 算作 PASS。

本轮验证绑定 `50215b9` 加本节所述改名、分类模型依赖、私信升级断言及回滚导出差异；承载同一差异的提交及新 CI 见原 PR：

- PASS：`flutter test --no-pub` 运行上列九个文件，173 项；进程 PATH 使用已有 Git OpenSSL。
- PASS：`flutter analyze --no-pub`；五个 CI 原命令的 `dart compile exe integration/{feed_live_probe,post_search_live_probe,post_share_live_probe,post_tags_live_probe,feed_staging_probe}.dart` 均编译成功。
- PASS：`go -C services/api test -mod=readonly ./internal/channels ./internal/posts ./internal/rankings`；`GOOS=linux go -C services/api vet -mod=readonly ./internal/channels ./internal/authprivacy ./internal/authprivacyhttp`。
- PASS：`python -m unittest discover -s tools/prerelease/tests -v`：9 项 PASS，8 项 SKIP（Linux 所有权 1 项、需真实 PostgreSQL fixture 的角色审计 7 项）；不能替代真实回滚和 SQL 验收。
- PASS：`flutter pub get --offline` 仅更新 meta 的直接依赖标记，无版本或哈希改变；差异空白检查通过。
- BLOCKED 本地：分类 HTTP／私信真实 SQL 测试需要 Linux 与明确归属的一次性 PostgreSQL；Windows `syscall.Flock` 编译边界仍存在。完整演练、SQL 与 Android 结果以修复后 [当前 PR 检查](https://github.com/zewbby/SpeechFUL-Develop/pull/151/checks)为准。

## 阻碍与下一步

沿用私有 `SpeechFUL-Develop` 的 draft PR #151；适用产品 CI 的当前结果以 [PR 检查](https://github.com/zewbby/SpeechFUL-Develop/pull/151/checks)为准，不向公开仓库推送。三项失败修复后的真实 SQL、回滚演练与 Android 检查需继续核对，未通过前不标记完整验收。迁移不支持向下回滚；部署时必须安排旧客户端更新，先交付兼容七／十分类的新客户端，再协调后端迁移和完整服务端切换；不能将旧七分类客户端直接视为十分类兼容。无合并或正式部署授权。
