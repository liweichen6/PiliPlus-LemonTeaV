# Way C: A Private Fork of MyTVB

> **Status** (2026-11-14): a comparison entry, added at the user's request. The user chose [Way A](./WAY_A_PLAN.md) for now; this way is looked at again after Way A's planning is done. Nothing here is built.
> **Beside this file**: [`REARCHITECTURE.md`](./REARCHITECTURE.md) has the review, the requirements and the comparison. [`WAY_B_PLAN.md`](./WAY_B_PLAN.md) is the ground-up way.

---

## 1. What It Is and Where It Stands

A plan to fork MyTVB privately and build the thread ripper into it. It exists outside this repository, with its own plan, design notes and progress log, and it's at its first task.

| | |
| :--- | :--- |
| **What it is** | MyTVB: a native Kotlin client for Android TV, Media3 1.9.3, views with canvas-drawn cards, about 129,000 lines, very active. The plan adds the thread ripper as a `DataSource` in about 35 tasks |
| **Strengths** | Native today. 4K, HDR, Dolby Vision, danmaku, comments, live and SponsorBlock exist. The shortest road to a native app on your own TV |
| **Its limit** | It has no licence, so a fork can never be published. With one user today (2026-11-14) that blocks nothing now: a private build is exactly what would be used. It blocks the day the app is to be offered to others, and at that point everything built on it would have to be left behind |
| **Its costs** | Its upstream moves at about six commits a day, the heaviest sync load of the three ways, against the maintenance driver. A dynamics feed isn't in its feature list (not checked in its code). It's untested on `<physical-tv>` at 4K60 |
| **What it's good for** | The quickest native app on the user's own TV, for as long as the app stays private. A personal fallback, like the official app through the LAN proxy. A reference for behaviour: one manifest for seamless quality, canvas-drawn cards, key handling. Read for ideas only; none of its code may enter a public GPL repository |

---

## 2. What Planning It Further Would Need

Not done now. When this way is taken up:

1. **The licence question first.** It decides whether this way can ever lead to a public app, or is a private build for good. Whether to ask the author is the user's call, and nothing is sent without approval.
2. **Its fit to the requirements**: check in MyTVB's code, not its README, for a dynamics feed, member pages, and view-only messages and articles.
3. **Its own device gate**: 1080p and then 4K60 on `<physical-tv>` under the guard, before any ripper work. That gate is already in the fork's plan.
4. **Its sync load**, measured: how many of the fork's hook files MyTVB's last hundred commits touched.

## 3. What It Offers the Other Ways Today

* Its design notes for the ripper as a Media3 `DataSource` are the user's own writing, and Way B's `:btr` module reuses them.
* MyTVB shows two things worth copying as ideas: one DASH manifest for every quality, so a switch has no reload, and cards drawn on a canvas for speed. Ideas only: none of its code may enter a public GPL repository.
