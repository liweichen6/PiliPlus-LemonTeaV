# PiliPlus TV 4K, the Video Plane Variant

`variant/4k-passthrough` is `main` plus M16: 4K on the TV's video plane (`4K 视频直通`). It's a separate app with its own releases, updated by hand.

**Why it's separate** (the user's decision, 2026-10-31): `main` merges upstream and publishes automatically, and CI has no TV. Upstream changes the code this path relies on often: `media_kit_video` moved 15 times in six months, and `androidAttachSurfaceAfterVideoParameters` changed on 2026-10-10. On this path, a change that still compiles could put 4K60 back on the GPU, which shuts `<physical-tv>` down. So this branch only moves when someone has checked it on a TV.

## What Differs From `main`

| | `main` | `variant/4k-passthrough` |
| :--- | :--- | :--- |
| App | `PiliPlus TV`, `com.lemontea.piliplus.tv` | `PiliPlus TV 4K`, `com.lemontea.piliplus.tv.passthrough` |
| 4K on `<physical-tv>` | Freezes, can shut the TV down | Plays on the video plane |
| `4K 视频直通` | Doesn't exist | On by default |
| Follows upstream | Automatically | When someone merges `main` |
| Releases | Here, automatic | `liweichen6/PiliPlus-LemonTeaV-4K`, on a tag |
| Updater | This repository | The release repository |

* **Its own application ID**: the two apps keep separate data. With one ID, going back to the normal app would keep a stored 4K default on a build with no video plane. Each needs its own login.
* **Its own release repository**: the normal app's updater offers `releases[0]` of this repository, drafts aside, even a pre-release. That code is on users' TVs and can't be changed, so a variant release here would be offered to all of them.
* `-Pdev` builds stay `PiliPlus TV dev`, `com.lemontea.piliplus.tv.dev`, on either branch.

## Updating From `main`

Never merge this branch into `main`.

1. `git merge main`. Conflicts should be small: the hooks in `lib/plugin/pl_player/controller.dart`, `lib/plugin/pl_player/view/view.dart` and `lib/pages/setting/models/video_settings.dart`, the identity lines in `android/app/build.gradle.kts`, `lib/http/api.dart` and `lib/common/constants.dart`, and `tv-checks.yml`.
2. Check what moved:

   ```bash
   git diff HEAD~1 HEAD -- pubspec.lock | grep -A3 -E '^.  media_kit'
   ```

   Keep `videoPlane?.configuration` ahead of the texture configuration in `_initPlayer`. Read `android_video_controller/real.dart` in `media_kit_video` if it moved: with `androidAttachSurfaceAfterVideoParameters: true` and a `vo` other than `gpu`, it must still never set `wid` or `vo`.
3. Apply the patches, run analyze and the TV tests, and build `-Pdev`.
4. Pass the device check below on `<physical-tv>`, on the `plane` guard from [`tool/tv_m16/run.sh`](../../tool/tv_m16/run.sh).
5. Push. A push builds and runs the TV checks, and publishes nothing.

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

## Releasing

Only after the device check, on the commit that passed it:

```bash
git tag "v$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)-fork.$(git rev-list --count HEAD)-4k"
```

```bash
git push origin --tags
```

The tag runs the TV checks and the build, then publishes to the release repository, source included. A red check publishes nothing.

## Setup (Owner, Once)

1. Create `liweichen6/PiliPlus-LemonTeaV-4K`, public, empty.
2. In that repository, **disable Actions**: it receives this tree, including workflows that sync upstream.
3. Add a token with `contents` and `workflows` write on that repository to this repository's secrets, as `VARIANT_REPO_TOKEN`.

Until then, the app's update check reports that it can't find a release, and a tag fails at the publish step with nothing released.
