# LETTER-TO-STUDENTS-20261116 - 致同学的一封信

- 模式：常规；负责人／状态维护人：当前 Session。
- 分支／Worktree／PR：`codex/feat/letter-to-students`；`E:/code_collection/java_code/SpeechFUL.git`；统一 PR [#8](https://github.com/zewbby/SpeechFUL-Develop/pull/8)，同时交付黑名单重做。实现基线为开发仓库 `zewbby/SpeechFUL-Develop` 的 `main@1d829b2`；该仓库当前为公开仓库。
- 授权依据与边界：用户要求“新建分支，制作《致同学的一封信》，进行文案编写 & 弹窗实现，完成之后进行pr，第一步是写文案”，后续确认弹窗交互。覆盖本任务开发、验证、提交、推送及向当前开发仓库 `zewbby/SpeechFUL-Develop` 创建 PR；合并、发布未执行。2026-11-16 GitHub API 核对该仓库当前为公开，名称与现有 `develop` 远端一致。
- 需求确认：以用户随后提供的全文为当前文案，保留措辞、段落与“SpeechFUL项目组”署名。用户确认每个账号首次登录新设备进入首页时自动展示；关闭按钮为“我已阅读”，位于正文最下方，必须滑动到底部后才能看到并使用。阅读状态按账号和本机安装实例保存；设置保留重读入口。无未决取舍。
- 更新日期：2026-11-16。
- 状态：实现 已完成；合并分支本机验证 PASS，统一 PR CI 以 #8 实时状态为准；合并 未合并；发布 未发布。

## 目标与范围

在登录后首页展示《致同学的一封信》，完成按账号和本机安装实例记录的首次弹窗、确认后的交互、验证及 PR。

## 文案

### 致同学的一封信

同学，你好：

欢迎来到 SpeechFUL，一个自由说话的地方。

一门课程的体验，一家值得推荐的饭店，一次寻找搭子的尝试，或是一件困扰自己的事情，都可以在这里聊聊。校园生活里有许多的事，我们想为这些声音留出位置。

我们希望，匿名能让表达轻松一些。你可以用自己选择的名字，分享经历、提出疑问，倾诉一些自己独特的感受。

让世界多一些爱与真诚，这是我们写在 SpeechFUL 里的愿望。

谢谢你来到这里。

SpeechFUL项目组

## 接口与依赖

现有移动端使用 Flutter，登录和目录就绪后完成身份初始化，再进入首页。信件通过同一根 Navigator 展示，分享链接及私信通知在首次阅读完成后继续导航。设置侧栏提供重读入口。

阅读记录使用已有 `FlutterAuthVault`，独立命名空间按环境及账号派生，Android 排除备份，iOS 使用本机 Keychain 及安装标记。确认后写入并读回核对；退出保留本机记录，新安装／另一设备分别读取自身记录。未新增认证字段、API、数据库迁移或公共身份关联。

正文使用随包宋体子集（130,532 bytes），来源、许可证及重建命令见 `apps/mobile/assets/fonts/StudentLetterSerif-SOURCE.md`。标题 20、正文 16／1.85 行高、段距 20；左对齐正文、右对齐署名，按钮位于同一滚动内容末尾。沿用现有明暗主题，8px 弹窗圆角。用户已明确实现，本轮直接使用真实 Flutter 渲染检查，不另建生成图审批流程。采用 frontend-design、hnuhole-ui-craft 及 ui-ux-pro-max 的排版／触控／大字原则；本地检索返回 Flutter 3.44 的语义及 TextScaler 通用建议，实际使用与验证版本为 3.47.5。

## 验收标准

- 弹窗标题、正文和署名与上述文案一致，段落清楚，全文可阅读。
- 每个账号在新设备首次进入首页自动展示；同一设备退出重登后不重复展示；切换账号分别判断。
- 正文必须滚动到底部后才能使用“我已阅读”；确认结果持久保存，保存失败时弹窗保持打开并允许重试。
- 设置中可重新打开信件；重读入口不改变已保存的首次阅读状态。
- 完成受影响模块验证及适用产品 CI 后交付 PR。

## 当前进度与证据

| 项目 | 被测版本／环境 | 结果与证据 |
| --- | --- | --- |
| 分支与现状 | 实现 `4067ae9db5635580ffbdc883d0011d368d210db4`；PR #8；Windows | PASS：任务分支已推送，PR 基于 `main@1d829b2623a6c32830ee1b74fae6c99a436ad3b3` 创建，当前 open、mergeable。 |
| 文案 | 用户本轮消息 | 已记录用户全文。 |
| 交互 | 用户 2026-11-16 确认 | 已确认首次展示、按钮文案、滚动门槛、账号／设备范围。 |
| 产品实现 | `4067ae9db5635580ffbdc883d0011d368d210db4` | 已完成：首次阅读、账号＋本机安装记录、底部阅读按钮、设置重读及中／繁／英／日文；无 API／schema 变更。 |
| Flutter 关联验证 | 同基线＋本任务差异；Windows／Flutter 3.47.5／Dart 3.13.4 | PASS：72 项（信件、登录首页、设置、本地化、外观和私信运行时），另 39 项（信件及导航、身份、通知、个人页和社区翻译）；两组有重叠，不合计为独立项。`flutter analyze --no-pub` 无问题。 |
| 协作验证 | 同基线＋本任务差异；`python -B -X utf8 -m unittest discover -s tools/tests -p test_collaboration.py -v`、`git diff --check` | PASS：协作回归 19 项；差异空白检查通过。 |
| 真实渲染 | `apps/mobile/build/student-letter-render/` | PASS：375×812、320×640／2 倍字深色、812×375 横屏、768×1024 繁体及日文共 10 张首末状态。实际查看中文首末、小屏大字暗色末尾及英文横屏末尾；随包宋体子集解决系统字体回退黑块。按钮首次不可触达，到底后可见且高度 ≥48；减少动画已覆盖。 |
| PR 产品 CI | PR #8 head `4067ae9db5635580ffbdc883d0011d368d210db4`；GitHub Actions | PASS：所有非跳过检查成功，`actual-process-acceptance` SKIPPED。包括 `flutter-and-android`、`flutter-and-real-feed`、`flutter-auth-regression`、`avatar-flutter`、`client`、`compile`、`candidate`、`rehearsal` 及服务端检查。 |
| 黑名单合并交付 | 合并提交 `81971208d0eb7599a9d9851cd2c3ec098e038316`＋任务记录更新；Windows／Flutter 3.47.5 | PASS：`flutter analyze --no-pub` 无问题；信件、黑名单及 Feed UI 聚焦测试共 60 项通过。统一 PR #8 的最终 head CI 以 PR 实时状态为准。 |
| Android bundle | 本机 `flutter build bundle --debug --no-pub`；PR #8 CI | BLOCKED（仅本机）：宿主缺少 Android SDK。PR 的 `flutter-and-android` 已 PASS，目标平台构建缺口已由 CI 覆盖。 |
| 原生设备／生产 | 本轮宿主验证 | NOT_RUN；宿主存储替身不代证原生跨进程／真机／生产验收。 |

## 阻碍与下一步

仓库要求的 `grill-with-docs` 及其依赖未在本地找到，已说明并通过用户明确答复收敛交互。实现、本机验证、推送和 PR 产品 CI 已完成；PR #8 等待审查。合并与发布未获授权，原生设备／生产验收继续保持 NOT_RUN。
