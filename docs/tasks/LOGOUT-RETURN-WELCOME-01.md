# LOGOUT-RETURN-WELCOME-01 — 退出登录返回欢迎页

- 模式：常规；负责人：当前 Session。
- 分支／Worktree／PR：`codex/fix/logout-return-welcome-20261114`，`E:/Hnuhole-env/source/SpeechFUL-logout-return-welcome-20261114`，[PR #148](https://github.com/zewbby/SpeechFUL-Develop/pull/148)；基线 `origin/main@3da31522de5a31835fc8f398837fa06ba122fe69`。
- 授权与需求确认：2026-11-14 用户要求退出登录直接到欢迎页，不到登录界面；在查看代码事实后明确要求直接修改，随后授权推送和创建 PR。无未决产品取舍。
- 更新日期：2026-11-14。
- 状态：实现已完成；本地验证 PASS、产品 CI 待验；合并未合并；发布未发布。

## 目标与范围

显式退出成功后清除受保护路由并停在欢迎页。欢迎页的“开始”入口仍可由用户主动打开登录页。安全存储未能确认退出时保留原有故障页，不改会话撤销与持久待办协议。

## 接口与依赖

无新增接口。沿用 `AuthSessionController.logoutVersion`、认证状态与根级导航。

## 验收标准

- 从设置页或嵌套受保护页面退出后，显示带“开始”入口的欢迎页，不出现登录表单；返回操作不能恢复旧账号页面。
- 退出后用户主动点击“开始”才进入登录页，重新登录可正常进入新账号。
- 服务端撤销待办重试不会再次改变欢迎页；安全存储失败仍显示故障而非误报退出成功。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 实现 | `14590a16947b2e1d727acfd4244356d21ee6c2ee` | 已移除成功退出后自动压入登录页的动作，并更新登录导航测试。 |
| 依赖与格式 | Windows，Flutter 3.47.5／Dart 3.13.4；`flutter pub get --offline --enforce-lockfile`、`dart format --output=none --set-exit-if-changed`（3 个受影响 Dart 文件） | PASS；锁文件和格式无变化。 |
| 静态分析 | 同上；`flutter analyze --no-pub` | PASS；零问题。 |
| 导航测试 | 同上；`flutter test --no-pub --reporter expanded test/login_home_navigation_test.dart test/personal_route_account_test.dart` | PASS；28 项，覆盖欢迎页、受保护路由清理和重新登录。另以 `--name 'device logout\|revocation retry\|logout storage failure'` 单独确认 3 个边界用例通过。 |
| Android 构建 | 同上；`flutter build apk --debug --no-pub`，现有 JDK 17 与 Android SDK | PASS；生成调试 APK，仅证明构建；未装机。 |
| 差异 | `git diff --check`；最终代码核对 | PASS；变更仅涉及根级导航、对应测试和本记录。 |
| 产品 CI／设备 | [PR #148](https://github.com/zewbby/SpeechFUL-Develop/pull/148)，产品提交 `14590a1` | 产品 CI 待核对；真机与发布验收 NOT_RUN。 |

## 阻碍与下一步

本地提交、推送及 PR 创建已完成。核对 PR 当前 head 的适用产品 CI；合并与发布尚未进行。
