> **声明**：此 repo 完全是 wish coding 的产物，初期主要由 Argon 完成，之后混入了 3.8 Flash 和 Opus/Sonnet 5.5。

<div align="center">
    <img width="160" height="160" src="assets/images/logo/logo.png" alt="PiliPlus TV logo">
    <h1>PiliPlus TV（海外加速 + 安卓电视版）</h1>
    <p>中文 | <a href="README.en.md">English</a></p>
    <p>专为 <strong>Android TV 大屏遥控器</strong>与<strong>海外流畅观看</strong>打造的哔哩哔哩第三方客户端。</p>
    <p>基于 <a href="https://github.com/lemonteaau/PiliPlus">lemonteaau/PiliPlus</a>（内置 <a href="https://github.com/MrTangLuyao/Bilibili-thread-ripper">B站线程撕裂者 BTR</a> 多线程海外加速）与 <a href="https://github.com/bggRGjQaUbCoE/PiliPlus">PiliPlus</a>，采用<strong>三层解耦 TV 控制层架构</strong>，每周自动跟进上游更新。</p>
</div>

---

## 核心特性

### 1. 原生级 Android TV 遥控器与 10 英尺大屏交互
- **2D 空间方向键焦点引擎（`TvFocusTraversalPolicy`）**：
  - 支持网格、瀑布流、侧边栏、设置列表及弹窗的精准方向键导航，内置高对比度焦点高亮框（`#FFFFD166`）与零重建（Zero-Rebuild）独立重绘层。
  - **多层内嵌面板焦点隔离与自动晋升/还原**：深度适配 `MiniScaffold` 多层内嵌面板（`评论详情` / `对话列表` / `选集` / `AI总结`），打开面板自动晋升焦点并隔离底层页面，关闭时精准还原触发焦点。
  - **吸顶/浮动 Sliver 标题平滑滚动与方向键退出**：完美支持 `SliverPinnedHeader` 与 `SliverFloatingHeaderWidget`，向上滚动不被固定标题栏截胡，并支持双坐标空间方向键退出。
  - **嵌入式评论操作步进**：在评论卡片按右键即可精准步进至卡片内嵌的 `回复`、`查看对话`、`点赞` 等操作按钮，按左键返回卡片，同时保持上下方向键整卡流畅滚动。
- **10 英尺全屏/分屏电视播控 HUD（`TvPlayerHud`）**：
  - 全屏播放时按方向键或确认键呼出电视专属 OSD 控制栏，支持 **播放/暂停、上一集/下一集、选集/分P、画质切换、倍速、画面比例、弹幕开关与弹幕设置**。
  - **虚拟进度累加长按快进/快退**：方向键左右支持 `-10s / +10s` 步进，连按或长按自动以 `1x → 2x → 3x`（`10s / 20s / 30s`）平滑加速，不受硬件解码器延迟影响。
  - **长按确认键 3.0 倍速播放**：播放时长按遥控器 `OK`/`Enter` 键开启 `3.0x` 临时倍速播放（顶部提示 `3.0倍速中`），松开即恢复原倍速；短按正常切换播放/暂停。
  - **遥控器一键三连**：支持点赞、投币、收藏，长按点赞键触发**一键三连**。
  - **分屏快捷控制条（Quick Strip）**：在详情页分屏模式下提供顶栏快捷入口，一键进入全屏或切换分P。
- **电视端贴心细节**：
  - **扫码登录自动切换**：进入登录页自动切换至二维码标签页，免去遥控器繁琐输入。
  - **输入法按需呼出**：方向键划过搜索框/输入框时不会误弹窗遮挡画面，仅在显式按下遥控器 `OK`/`Enter` 键时呼出系统软键盘。
  - **弹窗焦点自动接管**：设置 → 关于 → 当前版本 弹出的「🎉 发现新版本」等对话框打开时，遥控器焦点与高亮框自动进入弹窗，背后的页面不可达；关闭（返回键或「取消」）后焦点回到原控件。
  - **有线网络（Ethernet）高画质识别**：自动将电视有线网口识别为高速宽带网络，默认解锁 1080P+/4K 高码率画质。
  - **电视端默认设置**：在电视端启动时，为尚未设置的项自动配置横屏布局、侧边导航栏、深色模式、字体缩放（`1.2x`）与推荐卡片宽度等最佳默认项，不会覆盖你已修改的设置。播放器 HUD 依赖「启用键盘控制」开关，请保持开启。
- **手机 / 平板 / 电视通用安装包（自适应运行）**：
  - 同一个 APK 安装在 **Android TV / 投影仪 / 电视盒子**上会自动开启 TV 遥控器模式；安装在 **安卓手机或平板**上则自动保持原版触控体验。
- **独立包名并存安装**：
  - 应用名称为 **`PiliPlus TV`**，包名为 **`com.lemontea.piliplus.tv`**，可与原版 PiliPlus（`com.example.piliplus`）及海外加速版（`com.lemontea.piliplus`）在同一台设备上同时安装、互不覆盖。

### 2. 内置海外多线程视频加速（B站线程撕裂者 BTR）
- **看视频更快**：视频拆分为多块并从多个服务器并发下载，在海外观看冷门视频或 4K/高码率视频时显著减少卡顿与缓冲（原理详见 [docs/thread-ripper.md](docs/thread-ripper.md)）。
- **装好即用**：加速默认开启，默认使用海外节点，无需手动配置。
- **番剧、电影同样加速**：普通视频与番剧、电影、纪录片均支持多线程下载（含 DRM 保护或仅试看剧集、直播除外）。

#### 海外加速相关设置
选项位于「设置 → 音视频设置」中，以「线程撕裂者」开头（修改后在下次加载视频时生效）：

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| 线程撕裂者 | 开 | 总开关，关闭后恢复普通单连接下载 |
| 剧集加速 | 开 | 是否加速番剧、电影、纪录片等剧集 |
| 海外节点 | 开 | 适合海外网络环境；在大陆观看可关闭以改用大陆节点 |
| 自动并发数（推荐） | 开 | 起播使用 16 线程，并根据缓冲情况在 8–64 线程间动态调整 |
| 并发数 | 8 | 关闭自动并发数后生效，可选 4–128 |
| 自定义节点 | 空 | 填写后仅使用指定节点 |

---

## 已知问题

> [!WARNING]
> **MediaTek（联发科）芯片的电视，请开启 `4K 视频平面` 后再选择 4K，否则不要选择 4K 及以上画质。** 在已测试的一台 MediaTek MT9690 电视上，不开启时 4K 视频几秒内就会卡死，随后应用无响应；4K60 还可能让电视内核崩溃并直接关机，需要手动重新开机。
>
> - 电视端现在默认使用 **1080P 60帧**。从未改过默认画质的旧安装也会如此，已经选过的默认画质不会被改动。
> - 这只是默认值，不是硬性限制：在播放器里仍然可以选择 4K，而且这个选择会保存为新的默认画质，之后的每个视频都会受影响。如果已经选过 4K，请到 `设置 → 音视频设置 → 默认画质` 改回 1080P 60帧。
> - **`设置 → 音视频设置 → 4K 视频平面`**（仅电视端，默认关闭）让解码器直接输出到电视的视频层，绕开 GPU。在这台电视上，开启后 4K60 的 AVC 和 AV1 都能在应用内稳定播放。重新打开视频后生效。
>   - 此模式下超分辨率、镜像、缩放和截图不可用，`裁剪`、`等宽`、`等高`、`原始` 这几种画面比例也不可用；弹幕很多时界面帧率会下降（约 42 帧），视频本身不受影响。
>   - 关闭它时，高于 1080P 60帧 的默认画质会自动改回 1080P 60帧。
>   - 从直播间打开的视频会沿用直播间的播放器，此时无法播放 4K，需要返回首页后重新打开视频。
> - 目前只测试过这一台实体电视，其他芯片的电视暂未发现此问题。

---

## 下载与安装

前往 [Releases 页面](../../releases/latest) 下载对应架构的 APK 安装包：

| 设备类型 | 推荐下载文件 | 说明 |
| --- | --- | --- |
| **新款安卓电视 / 电视盒子 / 安卓手机与平板（64 位）** | `app-arm64-v8a-release.apk` | 适用于 Shield TV、Chromecast 4K、新款主流盒子及绝大多数手机/平板 |
| **物理智能电视 / 投影仪 / 电视盒子（32 位）** | `app-armeabi-v7a-release.apk` | **大多数智能电视与投影仪采用 32 位系统，若 `arm64-v8a` 无法安装请选此项** |
| **安卓模拟器 / x86_64 设备** | `app-x86_64-release.apk` | 适用于电脑端 Android TV / 手机模拟器 |

---

## 自动跟进上游更新

本仓库通过 GitHub Actions 每周（周六 `16:16 UTC`）自动同步 [`lemonteaau/PiliPlus`](https://github.com/lemonteaau/PiliPlus)（上游同时同步自 [`bggRGjQaUbCoE/PiliPlus`](https://github.com/bggRGjQaUbCoE/PiliPlus)），在无侵入合并上游新功能的同时自动应用 TV 补丁并构建发布新版 APK。

- 版本号格式为 `2.1.6.2-fork.5720`（前半部分为上游版本号，末尾数字为提交计数 `versionCode`）。
- 应用内「设置 → 关于 → 检查更新」直接指向本仓库（`liweichen6/PiliPlus-LemonTeaV`），更新不会丢失 TV 控制层。

---

## TV 架构与开发文档（`docs/tv/`）

本项目将所有 Android TV 适配代码严格解耦为三层（独立模块 `lib/tv/*` + 构建期补丁 `lib/scripts/tv_*.patch` + 极简上游挂载点），详见 `docs/tv/` 目录：

| 文档 | 内容说明 |
| :--- | :--- |
| [**docs/tv/README.md**](docs/tv/README.md)（[English](docs/tv/README.en.md)） | **TV 模块总览、上游同步指南（GitHub Actions 与本地命令）、本地 APK 构建指南与签名配置说明** |
| [**docs/tv/ARCHITECTURE.md**](docs/tv/ARCHITECTURE.md) | **三层解耦 TV 控制层架构规范**、核心性能与健壮性机制（`F1`–`F9`、`M6`–`M9`）与 22 项 TV 功能不变量（`C1`–`C22`） |
| [**docs/tv/REVIEW.md**](docs/tv/REVIEW.md) | **TV 控制层全面代码与架构审查报告**：逐文件工程审计、边界细节（`R1`–`R7`）与上游合并风险评估 |
| [**docs/tv/PLAN.md**](docs/tv/PLAN.md) | 完整实施与演进路线图（Phase 1 基础移植、Phase 2 深度优化 & Phase 3 回归修复） |
| [**docs/tv/PROGRESS.md**](docs/tv/PROGRESS.md) | 任务级演进日志、性能基准测试对比与真机/模拟器双端验证记录 |
| [**docs/thread-ripper.md**](docs/thread-ripper.md) | B站线程撕裂者（BTR）多线程加速模块架构与自适应并发设计说明 |

---

## 致谢与许可

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)：上游核心项目，采用 [GPL-3.0](LICENSE) 许可，本项目保持相同开源协议。
- [lemonteaau/PiliPlus](https://github.com/lemonteaau/PiliPlus)：海外多线程加速（BTR）集成上游分支。
- [N3urda/PiliPlus-TV](https://github.com/N3urda/PiliPlus-TV)：灵感来源，本来想把 lemonteaau merge 进去的，但是问题越修越多干脆推倒重来了。
- [MrTangLuyao/Bilibili-thread-ripper](https://github.com/MrTangLuyao/Bilibili-thread-ripper)：多线程下载核心思路来源，基于 MIT 许可，详见 [docs/licenses/bilibili-thread-ripper.txt](docs/licenses/bilibili-thread-ripper.txt)。
