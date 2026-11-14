# WELCOME-PLAIN-AT-01 — 欢迎页常规 @ 字形

- 模式：常规；负责人：当前 Session；无委派。
- 分支／Worktree：`codex/fix/v1-1-2-welcome-at`；`E:/Hnuhole-env/source/SpeechFUL-v1-1-2-welcome-at`。
- 基线：`f5127dc9566daf545afe9c2ce26cd233a4bc54dd`，已包含 v1.1.2 发布代码。
- 授权依据：2026-11-14 用户要求“合到v1.1.2里”，随后明确“要合并到main主线”；覆盖本修复提交、推送、PR、CI 后合并。不包含重新发布或装机。
- 需求确认：常规 @ 与 SpeechFUL 相同字体、字号、粗斜体；沿用已确认字形，无未决取舍。
- 更新日期：2026-11-14。
- 状态：实现已完成；验证进行中；未合并；未重新发布。

## 目标与范围

将欢迎页字标、SVG、生成器及来源说明同步恢复为 Roboto Black Italic 的常规 @。原 SpeechFUL 文字大小、主题、无障碍标签及欢迎流程保持一致。

## 接口与依赖

无 API 或数据变动。原本地修复 `28f0ad3`；v1.1.0 分支曾以 `2b47198` 包含常规 @，但未合回主线，后续 v1.1.2 因而再次使用旧 Threads 图标。本次使用 28f0ad3 的共同字号方案，保留原 SpeechFUL 字形高度。

## 验收标准

- 完整字标使用同一粗斜字体；SVG 与 Flutter 路径匹配。
- 明暗主题欢迎页可见，认证、启动及登录导航回归通过。
- 当前 PR head 的适用产品 CI 通过后合并 main。

## 当前进度与证据

被测基线 f5127dc 加本提交四个产品文件差异。日志目录 `E:/Hnuhole-env/welcome-at-v112-20261114/`。验证结果及 PR 链接后续追加。

## 阻碍与下一步

本地聚焦验证与远程产品 CI；通过后按用户授权合并。APK 重新构建／发布／设备安装不在此次 main 合并范围。

- PASS：锁定依赖离线恢复；Flutter analyze 无问题；固定 SHA256 字体重新生成 SVG／Dart，产物与 28f0ad3 相同（152.572×30）。初次测试因沙箱禁止 sqlite3 原生库下载失败，联网复跑中。

- PASS：dd3827f 产品差异的四个 Flutter 测试文件共 61 项通过（test-network.log）；375px 明暗欢迎页实际查看，常规粗斜体 @ 正确。渲染未加载 QA 中文字体，方框不作为中文排版证据。
- PR：[147](https://github.com/zewbby/SpeechFUL/pull/147)，远程产品 CI 进行中；最终 head 检查与合并以 PR 实时回执为准。目标平台构建由 Android CI 验证，真机 NOT_RUN；未重新发布。
