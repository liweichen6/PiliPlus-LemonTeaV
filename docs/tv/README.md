# PiliPlus-LemonTeaV：三层解耦 TV 控制层开发文档

中文 | [English](./README.en.md)

本目录（`docs/tv/`）包含 **PiliPlus-LemonTeaV**（`PiliPlus TV`）的架构规范、里程碑规划、性能演进日志，以及上游同步与本地 APK 构建指南。本项目基于 [`lemonteaau/PiliPlus`](https://github.com/lemonteaau/PiliPlus) 与 [`bggRGjQaUbCoE/PiliPlus`](https://github.com/bggRGjQaUbCoE/PiliPlus)，专为 **Android TV 大屏遥控器**与**海外多线程流畅播放**打造。

---

## 1. 核心设计目标

1. **近零上游合并冲突（Near-Zero Merge Conflicts）**：将上游业务代码改动压缩到极致（**仅触碰 `lib/` 下 5 个文件，共计 `< 20 行`挂载代码**），确保每周自动合并 `lemonteaau/PiliPlus` 时无需人工处理冲突。
2. **原生级 10 英尺遥控器交互（D-Pad First Experience）**：提供 2D 空间方向键焦点寻路引擎（`TvFocusTraversalPolicy`）、零重建（Zero-Rebuild）独立重绘焦点高亮框（`ValueNotifier<Rect?>` + `RepaintBoundary` + `CustomPaint`）、离屏预渲染平滑滚动（`cacheExtent`）、保活离屏页面焦点隔离（`PageView`/`TabBarView`）、`MiniScaffold` 多层内嵌面板焦点隔离与自动晋升/还原（`评论详情` / `对话列表` / `选集` / `AI总结`）、弹窗菜单与 `SmartDialog` 覆盖层对话框（如「发现新版本」更新弹窗）的统一焦点层（打开时焦点进入、背后页面不可达、关闭后还原）、吸顶/浮动 Sliver 标题双坐标空间滚动与退出、嵌入式评论操作步进、弹窗/菜单/列表边界闭环跳出，以及支持长按确认键 `3.0x` 倍速与虚拟进度快进的 10 英尺电视播控 HUD（`TvPlayerHud`）。
3. **框架层补丁适配（`patch.ps1` / `tool/tv_patch.sh`）**：通过构建期补丁解决 Flutter/Material 在电视端的焦点限制（`GestureDetector` 不可聚焦、`RadioGroup` 吞噬上下方向键、`InkResponse` 缺少键盘长按三连/坐标菜单触发及 `NavigationMode.directional` 下忽略 `enabled && canRequestFocus` 的缺陷），无需侵入修改 40+ 个上游业务页面。
4. **通用安装包与多版本并存（Universal APK & Side-by-Side Coexistence）**：
   - **独立包名**：`com.lemontea.piliplus.tv`（桌面名称：**`PiliPlus TV`**），可与原版 PiliPlus（`com.example.piliplus`）及海外加速版（`com.lemontea.piliplus`）在同一台设备上并存安装。
   - **自适应运行**：在 Android TV / Leanback 设备（系统上报 `UI_MODE_TYPE_TELEVISION` 或 `FEATURE_LEANBACK`，或编译注入 `--dart-define=PILI_FORCE_TV=true`）上自动开启 TV 控制层；在安卓手机与平板上自动保持原版触控体验。
   - **电视端默认设置**：每次在电视端启动，`TvPlatform` 只为**尚未设置**的项补写电视友好默认值（横屏、侧边栏、深色模式、字体 `1.2x` 等），不会覆盖你已修改的值。其中包括「启用键盘控制」（`keyboardControl`）：播放器 HUD 与分屏快捷控制条挂在播放页的按键处理上，而上游仅在该开关开启时才构建它，因此在电视端手动关闭它会让 HUD 与 Quick Strip 一并消失，请保持开启。

---

## 2. 文档索引

| 文档 | 内容说明 |
| :--- | :--- |
| [**README.md**](./README.md)（[English](./README.en.md)） | TV 模块总览、包名与多版本并存说明、上游同步指南、本地 APK 构建指南与签名配置说明。 |
| [**ARCHITECTURE.md**](./ARCHITECTURE.md) | **三层解耦 TV 控制层架构规范**（`lib/tv/*`、`lib/scripts/tv_*.patch`、`TvBridge.kt`）、核心性能与健壮性机制（`F1`–`F9`、`M6`–`M10`）与 23 项 TV 功能不变量（`C1`–`C23`）。 |
| [**REVIEW.md**](./REVIEW.md) | **TV 控制层全面代码与架构审查报告**：模块逐文件深度评估、边界条件与代码卫生审查结论（`R1`–`R20`）及上游合并风险矩阵。 |
| [**PLAN.md**](./PLAN.md) | 按 **阶段（Phase 1–3）→ 里程碑（Milestone）→ 史诗（Epic）→ 任务（Task）** 组织的完整实施、优化与回归修复路线图。 |
| [**PROGRESS.md**](./PROGRESS.md) | 任务级执行日志、提交哈希、优化前后性能基准对比与真机/模拟器双端验证记录。 |

---

## 3. 上游同步指南（`lemonteaau/PiliPlus`）

### 方式 A：通过 GitHub Actions 每周自动同步 / 手动触发同步
工作流 [`.github/workflows/sync-upstream-build.yml`](../../.github/workflows/sync-upstream-build.yml) 会在以下时机运行：
- **每周定时运行**：每周六 `16:16 UTC`（`GMT+0`，北京时间周日 `00:16`）自动运行（`cron: "16 16 * * 6"`）；
- **代码推送触发**：向 `main` 分支推送代码时自动触发（忽略纯文档 `**.md` 改动）；
- **手动触发**：在 GitHub 仓库页面点击 **Actions** → **Sync upstream and build custom apps** → **Run workflow**。

工作流执行步骤：
1. 拉取 `https://github.com/lemonteaau/PiliPlus.git`（`main` 分支）并合并入本仓库 `main`（通过 [`.gitattributes`](../../.gitattributes) 中的 `merge=ours` 策略自动保留本仓库的 `README.md` 与 `README.en.md`）。
2. 计算提交计数 `version_code = $(git rev-list --count HEAD)`，生成版本标签 `v<upstream_version>-fork.<version_code>`。
3. 执行 [`lib/scripts/patch.ps1 android`](../../lib/scripts/patch.ps1) 应用全部 38 个 Flutter SDK、pub-cache 及 TV 框架补丁。
4. 使用签名密钥构建分架构 Release APK（`arm64-v8a`、`armeabi-v7a`、`x86_64`）并自动发布至本仓库 GitHub Releases。

### 方式 B：在本地通过命令行同步上游
在拉取或合并上游前，**请务必先还原本地 SDK 与依赖包补丁**，保持工作区干净：

```bash
# 1. 还原本地 Flutter SDK 与 pub-cache 补丁
./tool/tv_patch.sh revert

# 2. 添加上游远程仓库（首次执行）并拉取最新 upstream/main
git remote add upstream https://github.com/lemonteaau/PiliPlus.git 2>/dev/null || true
git fetch upstream main

# 3. 启用 'ours' 合并驱动（自动保留本仓库 README.md / README.en.md）并合并上游
git config merge.ours.driver true
git merge --no-edit upstream/main

# 4. 重新应用补丁，执行静态分析与 TV 自动化测试验证兼容性
./tool/tv_patch.sh apply
flutter analyze --no-pub lib/tv/ lib/pages/video/widgets/player_focus.dart lib/utils/connectivity_utils.dart test/tv_navigation_test.dart test/tv_player_hud_test.dart
flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart

# 5. 提交或推送前还原补丁，确保 SDK 与工作区干净
./tool/tv_patch.sh revert
git push origin main
```

---

## 4. 本地构建 Release APK 指南

### 环境要求
- **Flutter SDK**：需与 [`pubspec.yaml`](../../pubspec.yaml) 中锁定的版本一致（`3.47.7` stable，Dart `>=3.13.0`）。
- **Java 17** 与 **Android SDK**（`compileSdk = 37`）。
- **补丁脚本**：[`./tool/tv_patch.sh`](../../tool/tv_patch.sh)（适用于 macOS/Linux 的 Bash 脚本，与 CI 使用的 [`lib/scripts/patch.ps1`](../../lib/scripts/patch.ps1) 完全等价）。

### 构建步骤

```bash
# 1. 应用全部 38 个 Flutter SDK、pub-cache 及本地 material_ui 补丁
./tool/tv_patch.sh apply

# 2. 检查补丁状态（全部 38 项均应显示 [APPLIED]）
./tool/tv_patch.sh status

# 3. 计算构建元信息（与 CI 中的 lib/scripts/build.ps1 保持一致）
VERSION_CODE=$(git rev-list --count HEAD)
COMMIT_HASH=$(git rev-parse HEAD)
BUILD_TIME=$(date +%s)
VERSION_NAME=$(awk '/^version:/ {sub(/\+.*/, "", $2); print $2}' pubspec.yaml)

# 4. 构建分架构（split-per-abi）Release APK
flutter build apk --release --split-per-abi \
  --build-number="$VERSION_CODE" \
  --dart-define="pili.name=${VERSION_NAME}.lemontea" \
  --dart-define="pili.code=${VERSION_CODE}" \
  --dart-define="pili.hash=${COMMIT_HASH}" \
  --dart-define="pili.time=${BUILD_TIME}" \
  --no-pub

# 5. 构建完成后务必还原补丁，保持本地 Flutter SDK 与仓库整洁
./tool/tv_patch.sh revert
```

### 构建产物说明
生成的 APK 位于 `build/app/outputs/flutter-apk/`：

| 文件名 | CPU 架构 | 适用设备 |
| :--- | :--- | :--- |
| `app-arm64-v8a-release.apk` | 64 位 ARM (`arm64-v8a`) | 新款 64 位安卓电视、电视盒子（如 Shield TV、Chromecast 4K）及绝大多数安卓手机/平板 |
| `app-armeabi-v7a-release.apk` | 32 位 ARM (`armeabi-v7a`) | **绝大多数物理智能电视、投影仪及 32 位电视盒子（若 `arm64-v8a` 安装失败请选此项）** |
| `app-x86_64-release.apk` | 64 位 x86 (`x86_64`) | 电脑端 Android TV / 手机模拟器（x86_64） |

> **提示（在触控手机/模拟器上强制开启 TV 模式）**：
> 在 `flutter run` 或 `flutter build apk` 时添加 `--dart-define=PILI_FORCE_TV=true`，即可在带触摸屏的设备上强制开启 TV 焦点框与播控 HUD。

---

## 5. APK 签名与 GitHub Actions 密钥配置

### GitHub CI 签名 Secrets
为确保应用内「检查更新」（`Update.checkUpdate`）下载新版本后可直接覆盖安装（不发生签名冲突），需在 **GitHub → Settings → Secrets and variables → Actions** 中配置以下 **4 个仓库密钥（Secrets）**：

| Secret 名称 | 说明 |
| :--- | :--- |
| `SIGN_KEYSTORE_BASE64` | `.jks` 签名证书文件的 Base64 编码字符串（`base64 -i key.jks \| tr -d '\n'`） |
| `KEYSTORE_PASSWORD` | 证书库密码（storePassword） |
| `KEY_ALIAS` | 密钥别名（keyAlias） |
| `KEY_PASSWORD` | 密钥密码（keyPassword） |

[`sync-upstream-build.yml`](../../.github/workflows/sync-upstream-build.yml) 在构建前会校验这 4 个 Secret 是否非空，防止因未配置密钥而意外发布临时 debug 签名的 Release 安装包。

### 本地签名配置（`android/key.properties`）
- 若本地存在 `android/key.properties` 与 `android/app/key.jks`（均已加入 [`android/.gitignore`](../../android/.gitignore)，不会被提交），Gradle 会自动使用正式签名构建：
  ```properties
  storeFile=key.jks
  storePassword=<你的证书库密码>
  keyAlias=<你的密钥别名>
  keyPassword=<你的密钥密码>
  ```
- 若本地未创建 `android/key.properties`，[`android/app/build.gradle.kts`](../../android/app/build.gradle.kts) 会自动回退至 `signingConfigs["debug"]`（使用本机 `~/.android/debug.keystore`），开箱即可直接本地编译测试。
