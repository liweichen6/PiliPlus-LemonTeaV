# PiliPlus TVP, the Video Plane Variant

`variant/4k-passthrough` is `main` plus M16: 4K on the TV's video plane (`4K 视频直通`). It's a separate app, built by hand, with no releases and no update check.

**Why it's separate** (the user's decision, 2026-10-31): `main` merges upstream and publishes automatically, and CI has no TV. Upstream changes the code this path relies on often: `media_kit_video` moved 15 times in six months, and `androidAttachSurfaceAfterVideoParameters` changed on 2026-10-10. On this path, a change that still compiles could put 4K60 back on the GPU, which shuts `<physical-tv>` down. So this branch only moves when someone has checked it on a TV.

## What Differs From `main`

| | `main` | `variant/4k-passthrough` |
| :--- | :--- | :--- |
| App | `PiliPlus TV`, `com.lemontea.piliplus.tv` | `PiliPlus TVP`, `com.lemontea.piliplus.tv.passthrough` |
| 4K on `<physical-tv>` | Freezes, can shut the TV down | Plays on the video plane |
| `4K 视频直通` | Doesn't exist | On by default |
| Follows upstream | Automatically | When someone merges `main` |
| APKs | Releases here, automatic | Artifacts of a manual Actions run, kept 90 days |
| Update check | This repository's releases | Off, and a manual check says where the APK is |

* **Its own application ID**: the two apps keep separate data. With one ID, going back to the normal app would keep a stored 4K default on a build with no video plane. Each needs its own login.
* **No releases**: the normal app's updater offers `releases[0]` of this repository, drafts aside, even a pre-release. That code is on users' TVs and can't be changed, so a variant release here would be offered to all of them. Artifacts never reach it.
* **No update check**: the only releases it could find are the normal app's, which would install beside it, not over it.
* `-Pdev` builds stay `PiliPlus TV dev`, `com.lemontea.piliplus.tv.dev`, on either branch.

## Updating From `main`

Never merge this branch into `main`.

1. `git merge main`. Conflicts should be small: the hooks in `lib/plugin/pl_player/controller.dart`, `lib/plugin/pl_player/view/view.dart` and `lib/pages/setting/models/video_settings.dart`, the identity lines in `android/app/build.gradle.kts`, the update hook in `lib/utils/update.dart`, and `tv-checks.yml`.
2. Check what moved:

   ```bash
   git diff HEAD~1 HEAD -- pubspec.lock | grep -A3 -E '^.  media_kit'
   ```

   Keep `videoPlane?.configuration` ahead of the texture configuration in `_initPlayer`. Read `android_video_controller/real.dart` in `media_kit_video` if it moved: with `androidAttachSurfaceAfterVideoParameters: true` and a `vo` other than `gpu`, it must still never set `wid` or `vo`.
3. Apply the patches, run analyze and the TV tests, and build `-Pdev`.
4. Pass the device check below on `<physical-tv>`, on the `plane` guard from [`tool/tv_m16/run.sh`](../../tool/tv_m16/run.sh).
5. Push. A push runs nothing here, so start a build as below.

## Device Check

The short list. M16.3 in [`PLAN.md`](./PLAN.md) has the full one. Ask before the first 4K60 run of a session.

| Check | Pass |
| :--- | :--- |
| 1080p first | The decoder logs `hwRender:1, gdec:0`. No 4K60 until it does |
| 4K60 AVC and AV1, 10 minutes each, warm TV | No freeze, ANR or shutdown; layer stays `DEVICE` |
| Home and back, TV sleep and back, at 4K60 | Playing again within about 10 s |
| Next-video, split-screen and fullscreen | New decoder with `hwRender:1`; right rect |
| Open a 4K video from a live room | Refused, with no `gdec:1` |
| Turn the setting off with a stored 4K default | The next video opens at 1080P60 |
| `dumpsys -t 6 media.player` afterwards | Answers in under a second |

## Building

Only after the device check, on the commit that passed it:

1. In this repository's **Actions** tab, open **Build PiliPlus TVP** and press **Run workflow**.
2. Under **Use workflow from**, pick `variant/4k-passthrough`. It defaults to `main`, and a run on any other branch fails at once and builds nothing.
3. The run does the TV checks, then the build. A red check means no APK.
4. Download `PiliPlus-TVP-Android-<run number>` from the run's page. It needs a GitHub login, and GitHub keeps it for 90 days.

From a shell, the same run:

```bash
gh workflow run tv-variant-build.yml --ref variant/4k-passthrough
```

GitHub only offers **Run workflow** for a file on the default branch, so `tv-variant-build.yml` is on `main` too. A run uses the copy on its own branch, so the one on `main` only provides the button. Changing that copy publishes a normal release, because it isn't Markdown.

The signing secrets are the ones `tv-sync-build.yml` already uses. Nothing else needs setting up.
