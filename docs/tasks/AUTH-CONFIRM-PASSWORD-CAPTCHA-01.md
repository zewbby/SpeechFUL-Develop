# AUTH-CONFIRM-PASSWORD-CAPTCHA-01 — 注册确认密码与登录注册防刷

- 模式：常规；负责人／状态维护人：当前 Session。按 `grill-with-docs` 依赖的事实调查要求委派一次只读核查，无并行实现。
- 分支／Worktree／PR：`codex/feat/auth-confirm-password-captcha`；`D:/SpeechFUL/.worktrees/auth-confirm-password-captcha`；初始基线 `origin/main` = `22071c8d06aa5c4e564139c59672a3767609a92e`。本地安装需保留已安装 1.2.0 的更新，正将任务对齐到该安装包源码 `f6df995a10f169d1610de1f3fdb90bc0247242b9`；不推送、不创建 PR。
- 授权依据与边界：用户要求注册确认密码、登录／注册弹出验证码防刷；回答确认免费自部署滑块拼图、每次密码登录和登录／注册校邮发码都验证、找回密码发码一并保护。后续明确组件与登录／注册页风格一致；完成后制作并安装手机本机测试包，**不发布、不增加版本号**。仅操作本任务隔离测试资源；不修改正式业务数据，不推送／PR／合并／正式部署。
- 需求确认：免费开源 GoCaptcha 自部署；无验证码服务费或按次收费，使用现有服务器资源。每次新密码登录或三类校邮发码先验证，邮箱 OTP 确认与注册资料提交不重复弹窗；取消不提交业务请求。沿用现有校邮准入、注册回登录和暂停恢复凭据流程。无未决产品取舍。
- 更新日期：2026-11-17
- 状态：实现 已完成；验证 本地通过项 PASS，安装源码对齐及设备待验；合并 未合并；发布 未发布。

## 目标与范围

注册增加确认密码，两次不一致阻止提交。密码登录、注册／登录／找回密码发码弹出同主题滑块拼图；UI 沿用认证页颜色、字体、24px 弹窗圆角、按钮和 180ms 缩放淡入，跟随深浅色与减少动效设置。手机本机测试包沿用 **1.2.0 / 2026111701** 和原 publictrial 签名，连接任务独立本地 C/V 测试链路，不变更公开下载或正式服务。

## 接口与依赖

- 两侧各自新增 `POST /api/v1/captcha/challenges`、`POST /api/v1/captcha/solutions`；C 仅允许密码登录用途，V 仅允许三类发码用途。原保护操作新增 `Captcha-Token`；缺失返回 428，错误／过期／重放返回 422，不受理业务。
- 拼图在服务端用固定版本 `github.com/wenlng/go-captcha/v2 v2.0.5` 生成；原生 Flutter 展示，自有程序生成几何素材，无第三方网络调用。Apache-2.0 许可；不等同商业行为风控服务，结合现有限流用于基础防刷。
- PostgreSQL 保存限时答案与凭证摘要，C/V 独立；120 秒挑战仅一次作答，60 秒证明仅一次消费，绑定本方用途、安装标识、原幂等键与用户名／邮箱。`DELETE RETURNING` 支持多实例原子消费。C 不收邮箱／OTP，V 不收密码；不替代最终 Safety Gate、会话／凭据版本与现有限流。
- 新增 C `0051_auth_captcha.sql`（避开已安装版本的 0050 通知索引）、V `0010_auth_captcha.sql`，及受限 runtime 授权。服务启动检查迁移与 SELECT／INSERT／DELETE 权限，不因配置缺失静默放行。
- 客户端仅驻留验证码凭证；取消／验证加载失败在业务 POST 前终止，恢复本轮替换的原发码状态；原未知操作不清理。确认密码只在页面内存，切模式／完成／退出清理，不额外传给服务端。

## 验收标准

- 确认密码为空／不一致时提示，修正后正常注册，原成功／未知结果回登录行为保持。
- 四类主动操作均先验证；通过才提交，输错／过期可刷新，取消可立即重试。旧未知发码记录保留；旧已发送流程在取消新请求后恢复。
- 服务端拒绝跳过验证、跨用途／安装／原键／主体、重放和并发多次消费，原认证及 Gate 保持。
- 弹窗与完整认证页面视觉一致，375px 深浅色及 320px／1.6 倍字体无溢出；设备上的拼图与密码确认完整链路自验。
- 安装包版本、包名与签名核实后覆盖安装到唯一连接的 vivo V2323A；不清除原应用数据，不上传或公开发布。

## 当前进度与证据

证据目录 `E:/Hnuhole-env/auth-confirm-password-captcha-20261117/`；部分日志位于同前缀的 `*-20261117-*.log`。初轮绑定基线 `22071c8` 加本任务差异；源码对齐后聚焦复验并补最终承载提交。

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| Flutter 分析与交互 | 独立 WSL2 Linux；Flutter 3.47.5／Dart 3.13.4，pub.dev 原锁文件缓存 | PASS：完整 analyze 零问题，8 个认证回归文件共 208 项通过；`*-analyze-final.log`、`*-flutter.log` |
| 取消状态 | 同上，`test/captcha_flow_test.dart` | PASS：8 项，首次取消、恢复旧发码状态、保留旧未知请求；`*-flows.log` |
| Go | WSL2 Go 1.22.2；authcaptcha、authprivacy、HTTP、runtime test／vet；`go build ./...` | PASS：新生成／重放用例 race 通过；全认证包普通回归、vet 与构建通过，`*-captcha.log`、`*-go-final.log`。首次全 HTTP `-race` 暴露既有 DM 测试改写时钟与异步 TLS 关闭的竞态，保留 `*-go.log`，未修改无关业务 |
| 真实 PostgreSQL／HTTPS | runner 新建私有 socket 一次性 C/V 库；`TestCaptchaHTTPSPostgres`、`TestHTTPSPostgresEligibilityAndSignup` | PASS：4 类入口阻拦／放行、C/V 隔离、重放与 8 路并发仅一胜；原注册全链路通过。`*-sql.log`。SQL 测试仅从私有测试库读取生成答案，不提供产品答案接口；未连接正式数据 |
| API 契约 | 固定 PyYAML 6.0.1／openapi-spec-validator 0.9.0，完整 `check-specs.py` | PASS：13 份 OpenAPI／项目契约。适用 auth-feedback CI 已补触发范围与新用例；远端 NOT_RUN（用户要求不推送） |
| UI／安装 | 任务本地截图、同版本 Android APK | 进行中；手机现有版本 1.2.0／2026111701 已只读核实，唯一设备 vivo V2323A |

## 阻碍与下一步

完成已安装源码对齐、视觉与最终差异复验；制作保留原签名与版本号的本地测试 APK，启动任务独立本地后端，通过仅 C/V 公共 HTTPS 端口的 ADB reverse 连接手机，安装并自验后交付。不得将本机测试、内存替身或测试签名描述为正式发布／生产验收。

参考：[GoCaptcha 源码与许可](https://github.com/wenlng/go-captcha)。
