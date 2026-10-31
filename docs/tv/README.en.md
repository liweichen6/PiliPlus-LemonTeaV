# PiliPlus-LemonTeaV: Decoupled TV Control Layer Documentation

[中文](./README.md) | English

This directory (`docs/tv/`) contains the architectural specification, milestone/task plan, execution log, and developer build/sync guide for **PiliPlus-LemonTeaV** (`PiliPlus TV`) — an Android TV & overseas-accelerated Bilibili client built on top of [`lemonteaau/PiliPlus`](https://github.com/lemonteaau/PiliPlus) and [`bggRGjQaUbCoE/PiliPlus`](https://github.com/bggRGjQaUbCoE/PiliPlus).

---

## 1. Design Goals

1. **Near-Zero Upstream Merge Conflicts**: Keep upstream modifications to an absolute minimum (**only 5 Dart files in `lib/`, `< 20 lines` total**) so automated weekly merges from `lemonteaau/PiliPlus` run cleanly without manual conflict resolution.
2. **10-Foot D-Pad First Experience**: Provide spatial 2D directional focus traversal (`TvFocusTraversalPolicy`), zero-rebuild focus ring rendering (`ValueNotifier<Rect?>` + `RepaintBoundary` + `CustomPaint`), automatic scroll-into-view (`cacheExtent` pre-rendering), kept-alive offscreen `PageView`/`TabBarView` focus isolation, multi-layer `MiniScaffold` inline sheet focus isolation & LIFO promotion/restoration (`评论详情` / `对话列表` / `选集` / `AI总结`), a unified focus-layer stack that moves D-pad focus into popup menus and overlay dialogs outside the `Navigator` (such as the `SmartDialog` update dialog), keeps the page behind them unreachable, and restores the trigger on close, pinned/floating sliver header dual-coordinate scrolling and D-pad exits, embedded comment action stepping, closed-loop escape from scrollable dialogs/popups/lists, and a dedicated 10-foot TV Player HUD (`TvPlayerHud`) with progressive virtual seek and Hold-Select `3.0x` temporary speed.
3. **Framework-Level Widget Adaptation (`patch.ps1` / `tool/tv_patch.sh`)**: Fix Flutter/Material D-pad limitations (`GestureDetector` lacking focus, `RadioGroup` trapping arrow keys, `InkResponse` missing keyboard activation for `onTapDown`/`onTapUp` hold-to-triple-like and coordinate menus, plus respecting `enabled && canRequestFocus` in directional mode) at the build-time patch layer rather than editing 40+ upstream business pages.
4. **Universal APK & Side-by-Side Coexistence**:
   - **Application ID**: `com.lemontea.piliplus.tv` (Launcher label: **`PiliPlus TV`**) — coexists side-by-side with official PiliPlus (`com.example.piliplus`) and LemonTea PiliPlus (`com.lemontea.piliplus`).
   - **Adaptive Runtime**: Automatically activates the TV control layer on Android TV / Leanback devices (`UI_MODE_TYPE_TELEVISION`, `FEATURE_LEANBACK`, or `--dart-define=PILI_FORCE_TV=true`) while behaving identically to upstream touch PiliPlus on phones and tablets.
   - **TV Defaults**: On every TV launch `TvPlatform` fills in TV-friendly preferences for keys that are **not set yet** (landscape layout, side rail, dark theme, `1.2x` text scale, 1080P60 default quality, ...) and never overwrites a value you chose. This includes **启用键盘控制** (`keyboardControl`): the player HUD and the split-screen Quick Strip hang off the player page's key handler, which upstream builds only while that switch is on, so turning it off on a TV removes the HUD and the Quick Strip. Keep it on.

---

## 2. Documentation Index

| Document | Purpose |
| :--- | :--- |
| [**README.en.md**](./README.en.md) ([中文](./README.md)) | Overview, package identity, upstream sync guide, local APK build guide, and CI/CD signing setup. |
| [**ARCHITECTURE.md**](./ARCHITECTURE.md) | Deep dive into the Three-Tier Decoupled TV Control Layer (`lib/tv/*`, `lib/scripts/tv_*.patch`, `TvBridge.kt`), optimization & hardening mechanisms (`F1`–`F9`, `M6`–`M10`), and 23 capability invariants (`C1`–`C23`). |
| [**4K_VARIANT.md**](./4K_VARIANT.md) | The video plane variant, on `variant/4k-passthrough`: what differs from `main`, how to update it from `main`, its device check, and how to build it. |
| [**PLAYBACK_PARAMETERS.md**](./PLAYBACK_PARAMETERS.md) | Every mpv option tried on the video plane, with results, and which ones became settings. |
| [**REVIEW.md**](./REVIEW.md) | **Comprehensive Android TV Layer Code & Architecture Review**: file-by-file engineering audit, technical observations (`R1`–`R20`), and upstream sync risk matrix. |
| [**PLAN.md**](./PLAN.md) | Complete implementation, optimization, and remediation roadmap across **Phase 1–3 → Milestone → Epic → Task**, with verification criteria and privacy rules. |
| [**PROGRESS.md**](./PROGRESS.md) | Task-by-task execution log, commit hashes, before/after performance benchmarks, and dual-device verification results. |

---

## 3. Upstream Sync Guide (`lemonteaau/PiliPlus`)

### Option A: Automated Weekly / Manual Sync on GitHub Actions
The workflow [`.github/workflows/tv-sync-build.yml`](../../.github/workflows/tv-sync-build.yml) runs:
- **Automatically** every week on **Saturday at `16:16 UTC` (`GMT+0`)** (`cron: "16 16 * * 6"`),
- **On every code push** to `main` (ignoring `**.md` documentation-only changes), or
- **Manually** via GitHub → **Actions** → **Sync upstream and build PiliPlus TV** → **Run workflow**.

> `sync-upstream-build.yml` is upstream's own sync workflow (it syncs `bggRGjQaUbCoE/PiliPlus` and builds every platform). It is kept identical to upstream so upstream merges never conflict on it, and it must stay **disabled** in this repository's Actions settings.

What the workflow does:
1. Fetches `https://github.com/lemonteaau/PiliPlus.git` (`main`) and merges it into `main` (`README.md` and `README.en.md` are protected via `merge=ours` in [`.gitattributes`](../../.gitattributes)).
2. Computes `version_code = $(git rev-list --count HEAD)` and tags `v<upstream_version>-fork.<version_code>`.
3. Applies all 38 SDK, pub-cache, and TV patches via [`lib/scripts/patch.ps1 android`](../../lib/scripts/patch.ps1).
4. Signs and builds split-ABI Android release APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
5. Runs the TV checks (below) on the same commit, alongside the build.
6. Publishes a GitHub Release on `liweichen6/PiliPlus-LemonTeaV` only if both the build and the TV checks passed. A red check means no APK and no release; the version tag from step 2 may already exist and is moved by the next run.

### TV Checks (`tv-checks.yml`)
[`.github/workflows/tv-checks.yml`](../../.github/workflows/tv-checks.yml) runs on every pull request into `main` and before every release:
1. Applies all patches with `lib/scripts/patch.ps1 android` (a patch that no longer applies after a Flutter bump fails here).
2. `flutter analyze --no-pub --no-fatal-infos` on `lib/tv`, the upstream files that hook into it (`lib/main.dart`, `lib/pages/video/widgets/player_focus.dart`, `lib/utils/connectivity_utils.dart`) and the TV tests. Errors and warnings fail the check; infos don't, so an upstream lint info in a hook file cannot block a release.
3. `flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart`.

> **Repository setting (owner)**: in GitHub → **Settings** → **Branches**, protect `main` and require the status check **TV analyze and tests**, so a pull request cannot merge while it is red.

### Option B: Syncing Upstream Locally via CLI
Always revert local SDK/package patches before pulling or merging so your working tree is clean:

```bash
# 1. Revert local Flutter SDK & pub-cache patches
./tool/tv_patch.sh revert

# 2. Add upstream remote (one-time setup) and fetch latest upstream/main
git remote add upstream https://github.com/lemonteaau/PiliPlus.git 2>/dev/null || true
git fetch upstream main

# 3. Enable the 'ours' merge driver (keeps local README.md / README.en.md) and merge
git config merge.ours.driver true
git merge --no-edit upstream/main

# 4. Re-apply patches and verify static analysis & TV automated tests
./tool/tv_patch.sh apply
# (the same commands as tv-checks.yml)
flutter analyze --no-pub --no-fatal-infos lib/tv lib/main.dart lib/pages/video/widgets/player_focus.dart lib/utils/connectivity_utils.dart test/tv_navigation_test.dart test/tv_player_hud_test.dart
flutter test --no-pub test/tv_navigation_test.dart test/tv_player_hud_test.dart

# 5. Revert patches before committing or pushing
./tool/tv_patch.sh revert
# Every non-Markdown push to main publishes a release: push a branch and open a pull request instead
git push origin HEAD:sync/upstream
```

---

## 4. Building Release APKs Locally

### Prerequisites
- **Flutter SDK**: Matching the version pinned in [`pubspec.yaml`](../../pubspec.yaml) (`3.47.9` stable, Dart `>=3.13.0`).
- **Java 17** & **Android SDK** (`compileSdk = 37`).
- **Patch Helper**: [`./tool/tv_patch.sh`](../../tool/tv_patch.sh) (macOS/Linux bash equivalent of [`lib/scripts/patch.ps1`](../../lib/scripts/patch.ps1)).

### Step-by-Step Build Commands

```bash
# 1. Apply all 38 Flutter SDK, pub-cache, and local material_ui patches
./tool/tv_patch.sh apply

# 2. Verify patch status (all 38 patches should report [APPLIED])
./tool/tv_patch.sh status

# 3. Compute build metadata (matches CI's lib/scripts/build.ps1)
VERSION_CODE=$(git rev-list --count HEAD)
COMMIT_HASH=$(git rev-parse HEAD)
BUILD_TIME=$(date +%s)
VERSION_NAME=$(awk '/^version:/ {sub(/\+.*/, "", $2); print $2}' pubspec.yaml)

# 4. Build split-per-ABI release APKs
flutter build apk --release --split-per-abi \
  --build-number="$VERSION_CODE" \
  --dart-define="pili.name=${VERSION_NAME}.lemontea" \
  --dart-define="pili.code=${VERSION_CODE}" \
  --dart-define="pili.hash=${COMMIT_HASH}" \
  --dart-define="pili.time=${BUILD_TIME}" \
  --no-pub

# 5. Always revert patches after building so your Flutter SDK & repo stay clean
./tool/tv_patch.sh revert
```

### Output APK Files
Built APKs are written to `build/app/outputs/flutter-apk/`:

| File | Architecture | Target Devices |
| :--- | :--- | :--- |
| `app-arm64-v8a-release.apk` | 64-bit ARM (`arm64-v8a`) | Modern 64-bit Android TVs, TV boxes (e.g. Shield TV, Chromecast 4K), and Android phones/tablets |
| `app-armeabi-v7a-release.apk` | 32-bit ARM (`armeabi-v7a`) | Most physical smart TVs, projectors, and 32-bit TV sticks/boxes |
| `app-x86_64-release.apk` | 64-bit x86 (`x86_64`) | Android TV / Android emulators on x86_64 hosts |

> **Tip (Forcing TV Mode on a Touchscreen Device / Emulator)**:
> Pass `--dart-define=PILI_FORCE_TV=true` during `flutter run` or `flutter build apk` to force the TV control layer on a device that reports a touchscreen.

> **Tip (Debugging Playback on a TV)**:
> `tool/tv_m12/` holds the tools from M12's crash-debug track. `run.sh` runs one test over adb and records logcat, the kernel log and a sampler on the development machine, so they survive a kernel panic; `probe_app.sh` installs a small test app that plays a local file on a `SurfaceView` or a `TextureView`; `postpanic.sh` collects the evidence after a panic. They read `ANDROID_SERIAL`, `M12_MEDIA` and `M12_RUNS` from the environment. Some runs can shut the TV down: see [`M12_CRASH_DEBUG.md`](./M12_CRASH_DEBUG.md).

> **Tip (Listing a TV's Decoders)**:
> `./tool/tv_codecs.sh` prints, over adb, every video decoder that `MediaCodecList` reports on the device (the list the app actually sees): the sizes, frame rates, performance points and profile/level pairs each one claims. No app install or root is needed; pass `all` to include audio decoders, and set `ANDROID_SERIAL` to pick the device.

---

## 5. APK Signing & GitHub Actions Secrets

### GitHub CI Signing Secrets
To allow in-place app updates (`Update.checkUpdate`) without signature conflicts, configure these **4 repository secrets** in **GitHub → Settings → Secrets and variables → Actions**:

| Secret Name | Description |
| :--- | :--- |
| `SIGN_KEYSTORE_BASE64` | Base64-encoded `.jks` keystore file (`base64 -i key.jks \| tr -d '\n'`) |
| `KEYSTORE_PASSWORD` | Password for the keystore |
| `KEY_ALIAS` | Key alias inside the keystore |
| `KEY_PASSWORD` | Password for the key alias |

[`tv-sync-build.yml`](../../.github/workflows/tv-sync-build.yml) validates that all 4 secrets are non-empty before building so a release is never accidentally published with a temporary debug signature.

### Local Signing (`android/key.properties`)
- If `android/key.properties` and `android/app/key.jks` exist locally (both are git-ignored via [`android/.gitignore`](../../android/.gitignore)), Gradle signs release APKs with your release key:
  ```properties
  storeFile=key.jks
  storePassword=<your-keystore-password>
  keyAlias=<your-key-alias>
  keyPassword=<your-key-password>
  ```
- If `android/key.properties` is not present locally, [`android/app/build.gradle.kts`](../../android/app/build.gradle.kts) automatically falls back to `signingConfigs["debug"]` (`~/.android/debug.keystore`) so local builds work out of the box.
