# AUTH-CONFIRM-PASSWORD-CAPTCHA-01 — 注册确认密码与认证防刷

- 模式：常规；当前 Session 维护。按 `grill-with-docs` 仅委派只读事实调查，无并行实现。
- 分支／Worktree：`codex/feat/auth-confirm-password-captcha`；`D:/SpeechFUL/.worktrees/auth-confirm-password-captcha`。
- 实际基线：已安装 1.2.0 源码 `f6df995a10f169d1610de1f3fdb90bc0247242b9`，保留其已有功能。初始 `origin/main` 为 `22071c8d06aa5c4e564139c59672a3767609a92e`，因缺少已安装界面更新而未用于最终构建。
- 设备被测产品提交：`ea34c05a12c1e816ab72f9a6d536f08b96c6ea9a`（前序本地实现 `d58252f`、`d0503dd`）。原本机交付时未 Push／PR／合并／部署；用户后续明确授权本次改动 Push、提 PR 并合并，正式部署／发布仍不在授权范围。
- 授权：用户要求开发后制作并覆盖安装手机本机测试包，不发布、不增加版本号；明确选择临时测试服务＋合成账号、线上保持原状。仅保留本任务创建且仍供手机测试使用的服务、测试库、证书和 USB 端口映射。
- PR 基线：最新 `origin/main` = `75154f7d8f221d55fdfe2e2e885c4b656ea863f3`；四个本任务提交已 rebase 到该主线，认证运行源码与已装机被测版本相同，其他差异仅为主线新增研究文档与规则。对齐后的产品提交 `8dcd502aea5ff7da1fe77f63f7e640da898ec2ed`，原设备证据仍绑定 `ea34c05`。
- PR：[SpeechFUL-Develop #16](https://github.com/zewbby/SpeechFUL-Develop/pull/16)，目标 `main`。本地与设备验证已通过，当前 head 的远端产品 CI 待验；按用户授权待检查通过后 Squash Merge。
- 更新日期：2026-11-17。
- 状态：实现 已完成；自动化／真实 SQL 验证 PASS；同版本安装 PASS；手机最终冻结／到期恢复／首页 PASS；合并 未合并；发布 未发布。

## 最终确认与范围

1. 注册增加确认密码，空值或不一致阻止提交；仅在页面内存中保留，不额外上传确认值，切换／结束清理。
2. 免费开源 GoCaptcha 自部署滑块，仅在注册、邮箱登录、找回密码的每次新校邮发码前弹出；确认邮箱 OTP、提交注册资料不重复弹。取消不发码，错误可换题重试。用户后续明确取消账号密码登录的滑块，此项覆盖早期“四入口全部弹窗”的确认。
3. 账号密码登录直接提交，错误弹框原文“账号或密码错误，请重试”。同一用户名连续第 5 次错误后冻结该用户名密码登录 5 分钟，冻结内正确密码也拒绝；服务端持久化，换设备／重开 APP 不能绕过。重复尝试不延长时间；前 4 次内密码登录成功或冻结到期后清零。冻结提示“尝试次数过多，请5分钟后重试”。用户已逐项确认阈值与范围，邮箱登录及找回密码不受此冻结影响。
4. 弹窗沿用认证页颜色、字体、24px 圆角、按钮与 180ms 缩放淡入；跟随深浅色和减少动效。手机保持 1.2.0／2026111701、原 publictrial 包名和签名，不清除原应用数据。

## 接口与安全实现

- V 新增 `POST /api/v1/captcha/challenges`、`POST /api/v1/captcha/solutions`，只接受三类发码用途；原发码接口要求 `Captcha-Token`。缺失 428，错误／过期／重放 422，不受理发码。C 无滑块接口和证明要求。
- GoCaptcha 固定 `github.com/wenlng/go-captcha/v2 v2.0.5`（Apache-2.0），服务端程序生成自有几何素材，原生 Flutter 展示，无第三方网络服务费或按次费；结合现有限流提供基础防刷，不等同商业行为风控。
- V PostgreSQL 保存答案与凭证摘要；120 秒挑战一次作答、60 秒证明一次消费，绑定用途、V 安装标识、原请求键及校邮。数据库时钟裁决过期，`DELETE RETURNING` 原子消费。
- C `0051_password_login_limits.sql` 保存用户名的带密钥摘要、失败数与固定冻结截止。原请求结果表记失败幂等结果，同键重放不重复计数；新键纠正密码。SQL 行锁串行化最终成功／失败，密码计算保持在锁外，事务内再次检查冻结与最终 Safety Gate、密码版本及账号状态。未知用户名与已有用户名同形处理。
- V `0010_auth_captcha.sql` 与 C 0051 独立迁移和 runtime 最小权限；启动拒绝缺表／缺权限，不静默放行。C/V 原有隔离、校邮准入、会话代次、资源归属及最终业务 Gate 均保留。
- OpenAPI 两侧契约、词汇表与 auth-feedback 产品 CI 已更新。用户已授权 PR 合并；远端产品 CI 待运行，发布仍未进行。

## 验证与证据

证据根目录：`E:/Hnuhole-env/auth-confirm-password-captcha-20261117/`。最终代码绑定 `ea34c05`；测试文件的格式化和纯证据文档不改变产品内容。原始失败日志保留，以下以列明的最终复验为准。

| 范围 | 环境／命令 | 结果与证据 |
| --- | --- | --- |
| Flutter | 独立 WSL2 Linux，Flutter 3.47.5／Dart 3.13.4；锁定 pub.dev 依赖；完整 `flutter analyze --no-pub` | PASS：零问题，`policy-analyze.log` |
| 认证客户端回归 | `flutter test --no-pub --concurrency=1`：auth_screen、auth_api、captcha_flow、registration_recovery、auth_session_controller、email_login、email_reset、auth_flows、auth_presentation | PASS：217 项，`policy-flutter.log`；覆盖密码登录不调用滑块、错误及冻结弹窗、确认密码、取消发码状态恢复 |
| 视觉 | 实际字体／图标和已解码图片；375px 深浅色、320px 深色／1.6 倍字体 | PASS：3 项无溢出，`ui-final.log`、`ui/*.png`；最终包手机浅色发码拼图 `frozen-email-captcha-ready.png`，深色截图 `recovery-captcha-ready.png` |
| Go | WSL2 Go 1.22.2；相关 authcaptcha／authprivacy／HTTP／runtime `go test`、`go vet`、`go build ./...` | PASS：`policy-go.log` 与 `verify-policy-backend.sh`；新 CAPTCHA race PASS `captcha-final.log`。首次全 HTTP race 曾暴露既有 DM 假时钟与异步 TLS 关闭竞态，未修改无关业务，不声称全包 race 通过 |
| 真实 SQL：密码冻结 | runner 明确归属的一次性私有 socket C/V 库，`-race`；`TestPasswordLogin*`、原 SessionLogin、SignupResult、EmailLogin、EmailResetPasswordAndPausedCredentials | PASS：`policy-sql.log` 中 authprivacy 包通过；第五次冻结、未知用户同形、成功／到期清零、同键不重复计数、8 路并发、暂停的正确密码证明不能跨冻结、邮箱登录不受影响。旧夹具重复幂等键和超长测试用户名已修正 |
| 真实 HTTPS／SQL／权限 | `TestCaptchaHTTPSPostgres`、`TestHTTPSPostgresEligibilityAndSignup`、`TestPasswordLoginRuntimePrivilegesPostgres` | PASS：`policy-sql-http-runtime.log`；三发码拒绝跳过／重放、跨用途、并发唯一消费、DB 过期；原注册登录；C 缺表及 SELECT／INSERT／UPDATE 任一缺失启动拒绝。该日志首个空匹配包不计验收 |
| API 契约与协作 | 完整 `packages/openapi/check-specs.py`，`tools/check-collaboration.py --staged`、`git diff --check` | PASS：13 份契约、协作检查及空白检查；适用产品 CI 已补充，远端待验（已获 Push／PR／合并授权） |
| 同版本安装 | vivo V2323A，包 `org.hnuhole.hnuhole_mobile.publictrial`；profile AOT，本机开发 CA 通过正常 TLS 校验 | PASS：`device-install-policy.log`、`android-receipt.json`。1.2.0／2026111701；签名 SHA256 `1538fb309499d651d7d12d7711a646c4a80fde4b1397857a9e39ce672b3dc9ae`；安装 APK 与交付 APK SHA256 相同 `25c04dd4841c58c92cb565888e38135f6ed716bd0435d11bb243abfea39f5334`，72,867,288 字节 |
| 源码对应 | Android 打包副本与最终运行源码对比，LFS 素材按摘要核实 | PASS：245 个运行文件一致，`source-comparison.json`；仅 publictrial 包名／原测试签名／构建内存配置存在打包差异，`local-source-proof.json` |
| 手机交互 | 前期确认密码与三发码完整链路；最终包错误／第五次冻结／重启／邮箱旁路 | PASS：`register-mismatch-verified.*`（无注册请求）、`registration-success-confirmed.*`、`recovery-reset-result.*`；最终 `actual-freeze-attempt-2` 至 `-5`、`freeze-correct-password-rejected.*`、`frozen-email-login-success.*`。自然到期后正确密码登录／首页 PASS：`verified-natural-expiry-success.*`、`final-verified-home.*`、`device-validation.json`；首冻 06:15:58Z，06:26:00Z 自然恢复（602 秒后实测，期间未改钟／改冻结数据），数据库固定 300 秒截止由 SQL 回归验证；失败计数 0、locked_until NULL，`device-counter-final.json` |

## 临时手机环境与交付

- APK：`E:/Hnuhole-env/auth-confirm-password-captcha-20261117/SpeechFUL-local-captcha-test.apk`；已覆盖安装，未卸载／清数据。
- 仅临时 C/V：`https://127.0.0.1:44623`、`https://127.0.0.1:46061`，通过本任务两项 ADB reverse。电脑、USB 连接及临时服务需保持运行；测试库不是线上数据。
- 合成邮箱不发真实邮件，电脑预览入口以 `device-lab.json` 的 `mailPreview` 为准。合成账号及测试密码保存在该外部本机文件，未提交到源码仓库，另见外部 `test-account.txt`（真实密码或个人账号未使用）。
- 临时服务最长 12 小时，测试 TLS 证书约 24 小时；外部隐藏 USB 助手仅自动恢复本任务两项转发，最长 12 小时且受相同 stop 文件约束；尚供用户试用，保留本任务进程和库。只在后续不再依赖时以任务 stop 文件关闭，runner 自行清理其明确归属的私有库，不清理其他资源。
- 正式发布、线上迁移、iOS、原生 Passkey 或生产风控验收均不在本次交付范围，NOT_RUN。
## PR CI 兼容复验

- 首轮 head `10f3869` 的 Auth feedback、Android candidate、iOS compile 等通过；跨模块 CI 暴露新增 0051 后，历史迁移测试仍将 0050 当作最新，以及冻结 C39 夹具缺少新的强制认证表。
- 仅调整相关回归：最新链路预期为 0051；回滚目标明确为 0049，允许先撤销可逆的 0051，再验证 0050 仍拒绝破坏历史事实。旧 C39 无新认证 schema 必须启动拒绝；只补认证 0051 并记真实 ledger／最小权限后可启动，仍不依赖可选读取加速表。产品认证和界面代码未变化。
- PASS：私有一次性 PostgreSQL 中通知／头像新建与升级、私信新建与升级、首页七种升级起点、认证权限及独立于可选读取加速的启动；`ci-fix-notice-avatar.log`、`ci-fix-dm.log`、`ci-fix-feed.log`、`ci-fix-runtime.log`。更新后远端 CI 待验，不将首轮有失败的整组 CI 记为 PASS。
- 完整 Gate 回归另发现新增表尚未进入精确隐私清单。已审计并加入 C 的用户名带密钥摘要／失败计时、V 的限时挑战／证明摘要；原禁止字段与跨方 schema 限制保持。实际通过密码失败、挑战和解题路径填充三表后，检查 C 无校邮／V 安装信息、V 无账号／身份／密码／C 安装信息；`ci-fix-privacy.log` PASS。最小权限审计对 C 失败表仅允许 SELECT／INSERT／UPDATE，对 V 滑块两表仅允许 SELECT／INSERT／DELETE，不对新增表套用通用 CRUD 放行。
- head `e402e53`：17 组远端 CI 中 16 组 PASS（包括完整 Authorization Gate、Auth feedback、Android candidate、iOS build、搜索性能）；Android prerelease 的真实恢复演练 FAIL，原因是旧 runtimeprobe 直接请求发码而未提交新必需的滑块证明。
- 演练工具改走公开挑战／解题／发码 HTTPS 接口；仅带任务 marker 的隔离 loopback V runtime 连接可读取该工具刚申请的挑战答案，C/V 连接和密码分别传递，生产服务不增加解题或绕过接口。Go race／vet／build 与 Python 工具回归 PASS（`ci-fix-runtimeprobe.log`、`ci-fix-prerelease-tools.log`；7 项需独立 SQL 选择加入的用例 SKIP），完整恢复演练与更新 head CI 待验。
- `7958dcb14c5869f40bf4da82d8aa287d4597f33f` 的干净 Linux detached checkout、独立本任务五套 PostgreSQL 16 cluster 与真实 HTTPS／Mailpit 完整演练 PASS：`environment.py init --rollback-sha 75154f7d8f221d55fdfe2e2e885c4b656ea863f3`、`rehearse`；含新实例冻结、注册登录、业务读写／拒绝、过期证据离线恢复、Gate 关闭、双实例备份恢复、旧会话拒绝、错误部署拒绝、旧主线二进制在新 schema 回滚与当前版本重部署。`ci-fix-prerelease-evidence.json` 绑定源提交、迁移摘要与工具版本。演练进程已停，仅本任务手机试用环境继续保留；更新 head 远端 CI 待验。
