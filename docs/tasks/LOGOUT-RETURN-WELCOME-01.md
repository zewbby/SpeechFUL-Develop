# LOGOUT-RETURN-WELCOME-01 — 退出登录返回欢迎页

- 模式：常规；负责人：当前 Session。
- 分支／Worktree／PR：上一版 [PR #148](https://github.com/zewbby/SpeechFUL-Develop/pull/148) 已于本次修正期间进入主线；修正分支 `codex/fix/logout-confirm-welcome-v112-20261114`，`E:/Hnuhole-env/source/SpeechFUL-logout-return-welcome-20261114`，基线 `origin/main@2fdf8f6a2b62d708d229e3fc372081df39f85bd0`；新 PR 待创建。
- 授权与需求确认：2026-11-14 用户明确完整流程为“点击退出登录 → 弹框 → 点确定 → 到欢迎页”，取消留在原页；随后要求修复，并按最新 v1.1.2 的包名、签名及公网服务打包安装到手机，手机交互由用户自行确认。此前已授权本任务直接修改、推送及创建 PR。无未决产品取舍。
- 更新日期：2026-11-14。
- 状态：修正实现已完成；本地验证 PASS、v1.1.2 公网包安装 PASS、手机交互待用户确认、修正 PR 产品 CI 待验；原 #148 已合并，修正尚未合并；正式发布未执行。

## 目标与范围

设置页点击退出先弹确认框；取消保留会话与当前页。点确定后才执行退出，清除受保护路由并稳定停在欢迎页。显式退出后的旧页面认证回调不能再自动打开登录页；欢迎页的“开始”仍可由用户主动打开登录页。安全存储未能确认退出时保留原有故障页，不改会话撤销与持久待办协议。

## 接口与依赖

无新增接口。沿用 `AuthSessionController.logoutVersion`、认证状态与根级导航。

## 验收标准

- 设置页点击退出后先弹确认框，不提前退出或导航；取消仍在原页，点确定后才退出。
- 从设置页确认退出或嵌套受保护页面退出后，显示带“开始”入口的欢迎页，不出现登录表单；旧页面认证回调不能二次打开登录页，返回操作不能恢复旧账号页面。
- 退出后用户主动点击“开始”才进入登录页，重新登录可正常进入新账号。
- 服务端撤销待办重试不会再次改变欢迎页；安全存储失败仍显示故障而非误报退出成功。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | `7aebaab`（与装机源码 `66b9141` 的 `apps/mobile` Git tree 同为 `87352a54e16135f77c0de3b011d97d8b8551c123`） | 增加设置页确认弹框；显式退出后拦截旧页面自动登录回调。 |
| 本地静态与界面测试 | Windows Flutter 3.47.5／Dart 3.13.4；`flutter analyze --no-pub`；`flutter test --no-pub --reporter expanded test/login_home_navigation_test.dart test/personal_route_account_test.dart test/settings_screen_test.dart test/identity_management_screen_test.dart` | PASS；零分析问题，42 项测试通过，覆盖确认前不退出、取消、确认后欢迎页、旧回调、主动重新登录、设备页退出、撤销重试及存储故障。 |
| 首次错误装机 | 误用默认 `flutter build apk --debug --no-pub` 并安装 `org.hnuhole.hnuhole_mobile` | FAIL；漏传公网双地址，APK 含 `.invalid` 默认地址，用户实际看到“登录结果暂时无法确认”。该包在后续检查中已不在手机应用列表；不能作为公网验收证据。 |
| 正确 v1.1.2 构建 | `66b9141` 为 v1.1.2 标签 `f5e77b3` 的后代；独立构建副本仅把 applicationId 改为原 `publictrial`；Release／arm64、`1.1.2`／`2026111402`、原签名、FRP 双地址 | PASS；2035 个源码文件核对无意外差异；AOT 含两个 FRP 地址且无 `.invalid` 地址；APK SHA-256 `e1154a4011bf22027f41ac50d868727d3906a95793c614bf430ddb8bf09943f9`。[构建回执](E:/Hnuhole-env/logout-return-welcome-v112-20261114/build-receipt.json)。 |
| 公网与手机 | 两个 FRP `/health/ready`；V2323A `10CEAG17RY003M7`；`adb install -r` 原 `publictrial` 包 | PASS；双入口 200；安装从 `2026111401` 升至 `2026111402`，原 firstInstallTime 保持，手机 base.apk SHA 与构建物一致。用户负责实际交互确认，当前待验。 |
| 修正 PR 产品 CI | 待创建修正 PR，产品提交 `7aebaab` | 待验；本地测试、构建和手机安装不代替产品 CI。 |

## 阻碍与下一步

推送修正分支并创建新 PR，核对其产品 CI；手机交互待用户确认。修正尚未合并，正式发布未执行。
