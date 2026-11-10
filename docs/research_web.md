# Web Research — CN "Leica style" cloud photo-editing on Xiaomi 17 Ultra (nezha), HyperOS 4

Status: web-only research (no ROM inspection). Sources are public web pages; treat quotes as claims by their authors, not as ground truth.
Legend: **[VERIFIED]** = stated by 2+ independent sources or an official/primary source; **[UNCERTAIN]** = single source or inference; **[NOT FOUND]** = searched, nothing public found.

---

## 0. TL;DR (most actionable)

1. The CN-only feature is **「徕卡一瞬」 (Leica Moment)**, exclusive to **小米17 Ultra 徕卡版** (Leica Edition), *not* the regular 17 Ultra. It has **two layers**:
   - **Layer 1 (on-device, free, unlimited):** camera capture profiles — simulate **Leica M9** (CCD look) and **Leica M3 + MONOPAN 50** B&W film. Implemented as an on-device model trained on hundreds of thousands of real M9 photos, *not* a simple LUT/filter.
   - **Layer 2 (cloud, "二瞬"):** in **相册 (Gallery)** press the "徕卡一瞬" button → the photo is uploaded and re-processed by an **end-to-end image large model** for extra tone/texture ("画质二次增强", "云端无损处理"). **This is the cloud part.** **[VERIFIED]** ([163/快科技](https://m.163.com/dy/article/KI3KGQ8F0511CPVM.html), [smzdm](https://post.smzdm.com/p/avgp5e5p/))
2. The derivative feature **「传奇一瞬」 (Legendary Moment)** ships on Xiaomi 18 Pro series (launched 2026-09-23) and is explicitly described by a Xiaomi camera PM as the "去徕卡版" version that can be pushed to non-Leica-licensed models. Same two-layer model: on-device free; gallery cloud enhancement metered. **[VERIFIED]** ([qudong](https://site.qudong.com/article/524278.html), [weibo @67891abc](https://sina.cn/news/detail/5348775912802981.html), [smzdm](https://post.smzdm.com/p/a5rxopw3/))
3. **Pricing/quota = server-side gating evidence.** For 17U Leica Edition the cloud processing is reported **permanently free**; for 传奇一瞬 the cloud enhancement has **60 free photos/month** (another blogger computes 40/month from a 19 CNY/month 超级小爱 credit subscription), limited-time free trial "at least until **2026-12-31**". Metering requires server-side account/entitlement state, i.e. a pure client-side port **cannot** reproduce layer 2. **[VERIFIED for existence, UNCERTAIN for exact numbers]** ([weibo @67891abc](https://sina.cn/news/detail/5348775912802981.html), [smzdm pricing analysis](https://post.smzdm.com/p/a5rxopw3/))
4. **Community ports confirm the split.** Rootless repackaged camera APKs ("免root改包") circulating in CN only deliver layer 1; testers explicitly say "只能一瞬不能二瞬" (get Moment, not Second-Moment) because the cloud enhancement is gone. Strong evidence the cloud half is the hard/blocked part. **[VERIFIED]** ([smzdm](https://post.smzdm.com/p/avgp5e5p/))
5. **Closest prior art (same device codename nezha):** [`mexusbg/Nezha-Leica-Camera-Enabler`](https://github.com/mexusbg/Nezha-Leica-Camera-Enabler) — Magisk/KernelSU module that sets `ro.theme_customize=LCC`, `ro.theme_leica=true`, `camera.debug.safe.check.disable=true` + a bundled LSPosed APK that patches **Camera + Gallery editor + Settings**; author reports testing on EEA ROM. This is a *camera/Leica UI* unlock, not the cloud processing. **[VERIFIED]** ([README](https://raw.githubusercontent.com/mexusbg/Nezha-Leica-Camera-Enabler/main/README.md), [XDA thread](https://xdaforums.com/t/enable-leica-camera-on-xiaomi-17-ultra.4785071/))
6. **Internal naming clue:** a research repo for porting Xiaomi camera to OPPO/OnePlus hardware names the Leica M3/M9 code paths **`Legendary*` / `Legend*`** (`LegendaryNativeCaptureBridge`, `LegendaryProcessingProvider`, `LegendM9Container`, package `local.mio.os4camerabridge`) and notes its port has the **local Monopan chain but only a "云处理完成" marker** for the cloud step. → when grepping CN APKs, search `legend`, `leica`, `monopan`, `m9`, `云处理`. **[UNCERTAIN — one hobbyist repo, but very specific]** ([Maga-King/xiaomi-camera-lsposed-bridge](https://github.com/Maga-King/xiaomi-camera-lsposed-bridge))
7. **Magisk pi format:** official docs support `system/`, and `vendor`/`product`/`system_ext` *only* as `system/vendor`, `system/product`, `system/system_ext` subfolders (auto-symlinked). **`mi_ext` is NOT documented/supported by Magisk's magic mount** — only via third-party metamodules (KernelSU Magic Mount-rs has an explicit `partitions = ["mi_ext", ...]` knob). **[VERIFIED]** ([Magisk guides](https://topjohnwu.github.io/Magisk/guides.html), [Magic Mount-rs](https://modules.kernelsu.org/en/modules/magic_mount_rs/))
8. **NOT FOUND:** any public Xiaomi cloud image-processing API docs, endpoint domains, auth protocol, or exact package/method names for the 徕卡一瞬/二瞬 cloud call. Also no public Magisk module that ports the *cloud gallery* half to global — only camera/UI unlocks.

---

## 1. What exactly is the CN feature? (naming, apps, timeline)

### 1.1 徕卡一瞬 (Leica Moment) — 17 Ultra Leica Edition exclusive
- Two picture profiles: **Leica M9** (CCD color/tone, shot locked to daylight WB) and **Leica M3 + MONOPAN 50** (B&W film simulation, per-pixel silver-halide grain, RGB channel response curves). Xiaomi says the M9 look is **not a filter**: the image pipeline was rebuilt and an **on-device model** trained on hundreds of thousands of M9 photos reproduces tone, color and optical softness. **[VERIFIED]** ([163/快科技](https://m.163.com/dy/article/KI3KGQ8F0511CPVM.html))
- Gallery second-pass enhancement: after shooting in 徕卡一瞬 M9 mode, **tap the "徕卡一瞬" button in 相册 (Gallery)** to run an **end-to-end image large model** ("端到端影像大模型") for a quality re-enhancement; requires **system version ≥ 3.0.7.0**. **[VERIFIED]** ([163/快科技](https://m.163.com/dy/article/KI3KGQ8F0511CPVM.html))
- It is the flagship-exclusive selling point of the **7999 CNY 17 Ultra Leica Edition**; regular 17 Ultra did not get it. **[VERIFIED]** ([smzdm](https://post.smzdm.com/p/avgp5e5p/), [XDA](https://xdaforums.com/t/xiaomi-17-ultra-leica-edition-software-filters-on-regular-17-ultra-possible.4781638/))
- Global sibling: the black/silver Leica Edition is sold overseas as **"Leica Leitzphone powered by Xiaomi" (~1999 EUR)** — same hardware/design, so it is the natural global-ROM reference point for what got dropped. **[VERIFIED]** ([smzdm](https://post.smzdm.com/p/avgp5e5p/), [163](https://www.163.com/dy/article/KMT029400511B8LM.html?referFrom=))
- Ongoing updates: 17U Leica Edition is being adapted for **Leica M10R** body look and **Summicron 35mm / Summilux 75mm** optical bokeh simulation (as of 2026-10). **[VERIFIED]** ([IT之家](https://digi.ithome.com/archiver/1/013/580.htm))

### 1.2 传奇一瞬 (Legendary Moment) — 18 series, License-free derivative
- Debuted on Xiaomi 18 Pro / Pro Max (2026-09-23), trained on "millions of camera works", end-to-end imaging large model, camera-grade depth bokeh; **"原片数据可在相册上传云端无损处理"** (raw data can be uploaded from Gallery to cloud for lossless processing). **[VERIFIED]** ([qudong](https://site.qudong.com/article/524278.html), [sohu](https://www.sohu.com/a/1081321502_114760))
- Xiaomi camera PM framing: 传奇一瞬 ≈ "去徕卡版" of 徕卡一瞬, portable to models without Leica licensing. **[VERIFIED]** ([weibo @67891abc](https://sina.cn/news/detail/5348775912802981.html))
- Cloud billing: on-device capture **free & unlimited**; **gallery cloud re-processing** is the paid/metered part — 60 free photos/month per one blogger, ~40/month per another (100 credits per photo, 4000 credits ≈ 19 CNY/month 超级小爱 plan); limited-time free window **until at least 2026-12-31**. **[VERIFIED existence / UNCERTAIN numbers]** ([weibo @67891abc](https://sina.cn/news/detail/5348775912802981.html), [smzdm](https://post.smzdm.com/p/a5rxopw3/))
- Community nickname for layer 2: **"二瞬"** (Second Moment) = "云端增强" (cloud enhancement). File-size anecdote: pure layer-1 output ~27 MB, with layer-2 up to ~60 MB; cloud-enhanced repack ~40 MB; non-cloud rootless repack only 1–2 MB. **[UNCERTAIN — user anecdotes]** ([smzdm](https://post.smzdm.com/p/avgp5e5p/))

### 1.3 Apps involved (for local RE, from public sources)
- `com.android.camera` — camera app, capture-side modes / "传奇一瞬"/"徕卡一瞬" toggles. **[VERIFIED]** (scope list of [HyperCeiler](https://github.com/ReChronoRain/HyperCeiler), [Nezha module](https://raw.githubusercontent.com/mexusbg/Nezha-Leica-Camera-Enabler/main/README.md))
- `com.miui.gallery` — 相册, hosts the gallery-side button/entry. **[VERIFIED]** (HyperCeiler scope)
- `com.miui.mediaeditor` — **小米相册-编辑 / Xiaomi Gallery Editor**, separate APK, hosts editing pipeline incl. Leica frames/watermarks. **[VERIFIED]** ([HyperCeiler scope](https://github.com/ReChronoRain/HyperCeiler), [APKPure listing](https://apkpure.net/tw/xiaomi-gallery-editor/com.miui.mediaeditor/download), [Nezha module scope](https://raw.githubusercontent.com/mexusbg/Nezha-Leica-Camera-Enabler/main/README.md))
- Possibly relevant per Xiaomi-cloud / AI: `com.miui.cloudservice`, `com.xiaomi.aicr` (澎湃 AI 引擎 / HyperOS AI engine), `com.xiaomi.aiasst.vision`. **[UNCERTAIN — inference from app scopes, not confirmed as the cloud call path]** ([HyperCeiler scope list](https://github.com/ReChronoRain/HyperCeiler))
- **[NOT FOUND]** the exact binding/service class or artifact that performs the cloud upload (likely an obfuscated Xiaomi service / SDK).

---

## 2. Cloud image-processing / 端云协同 — what is public

- CN Xiaomi marketing uses **"端云协同" / "端云结合"** for this class of feature: on-device model for zero-latency/offline capture, cloud large model for maximum-quality second pass. Press describes "端云结合模式下的徕卡风格". **[VERIFIED as marketing description]** ([sina](https://sina.cn/news/detail/5348538848381062.html), [163](https://m.163.com/dy/article/KI3KGQ8F0511CPVM.html))
- Explicit **"上传云端无损处理"** (upload to cloud for lossless processing) for the gallery second pass; 18-series article title says "支持云端无损处理". **[VERIFIED]** ([qudong](https://site.qudong.com/article/524278.html), [sohu](https://www.sohu.com/a/1081321502_114760))
- Xiaomi's broader CN AI-editing stack (e.g. 超级小爱 "随心修图", on-device AI model updates) is a **different, metered AI product line**, and the 传奇一瞬 cloud quota is reported to be denominated in **超级小爱积分 (Super Xiaoai credits)** → suggests the entitlement/billing system is Xiaomi-account/region bound. **[UNCERTAIN but consistent]** ([smzdm](https://post.smzdm.com/p/a5rxopw3/), [php.cn on 超级小爱 AI 修图](https://www.php.cn/faq/1738289.html))
- **Region gating conclusion:** no public doc states "global cannot call it", but (a) the feature is CO-launched with Leica CN licensing, (b) cloud processing is metered via CN account credits, (c) all community ports lose exactly the cloud layer ⇒ working hypothesis: **auth/entitlement is server-side per-region/account, possibly also per-device SKU.** Treat as **[UNCERTAIN — high confidence inference, unverified server behavior]**.
- Endpoints/domains/API: **[NOT FOUND]**. No public documentation, no leaked endpoint lists found by web search. Do not expect a documented "Xiaomi cloud image processing API".

---

## 3. Prior art (Magisk / KernelSU / LSPosed)

| Project | Type | What it proves | Link |
|---|---|---|---|
| **Nezha-Leica-Camera-Enabler** (mexusbg) | Magisk/KSU module + bundled LSPosed APK | Same device (nezha). Props `ro.theme_customize=LCC`, `ro.theme_leica=true`, `camera.debug.safe.check.disable=true` unlock Leica camera UI; LSPosed companion patches Camera + Gallery editor + Settings (removes non-working frames, hides Camera-ring settings, renames watermark to "XIAOMI 17 Ultra by Leica"). Author tested on **EEA** ROM; instructs "clear Camera app data". Discovery credited to Max Weinbach. | [repo](https://github.com/mexusbg/Nezha-Leica-Camera-Enabler) · [README](https://raw.githubusercontent.com/mexusbg/Nezha-Leica-Camera-Enabler/main/README.md) · [XDA](https://xdaforums.com/t/enable-leica-camera-on-xiaomi-17-ultra.4785071/) · [X post](https://x.com/mweinbach/status/2038763588655993271) |
| **xiaomi-camera-lsposed-bridge** (Maga-King) | LSPosed source archive / research | Ports Xiaomi camera to OPPO hardware; contains **Leica M3 local Monopan processing chain** (native worker, JPEG/YUV codec, `LegendM9Container`, `LegendaryNativeCaptureBridge`, `LegendaryProcessingProvider`), scope includes `com.android.camera` + `com.miui.mediaeditor`; explicitly says its result is local processing, **not** the "云处理完成" marker. Strong leads for internal class naming. | [repo](https://github.com/Maga-King/xiaomi-camera-lsposed-bridge) |
| **MIUI Leica Camera Port for AOSP** (HolyBear0610) | Magisk/KSU module (~215 MB) | Proves large camera+libs APK payloads are shippable as systemless modules; device/ROM-sensitive, may crash camera service. | [magisk.dev listing](https://magisk.dev/modules/miui-leica-camera-port/) |
| **HyperCeiler** (ReChronoRain) | LSPosed module (huge) | Canonical HyperOS feature-unlock framework; scope list includes gallery / mediaeditor / camera; credits `LSPosed/CorePatch` and `BypassSignCheck` (i.e. signature-check bypass is a known need for patched system apps). States it does NOT support some international HyperOS ROMs well. | [repo](https://github.com/ReChronoRain/HyperCeiler) |
| **Rootless repackaged camera APKs** (CN community, non-root) | APK repack | Deliver the M9/M3 *tone* only; testers report no "二瞬"/cloud enhancement, watermark mismatches ("17ultra" text on a 15 Ultra), packages distributed via netdisk/Feishu and **re-signed**. Shows the client can be patched but cloud capability cannot. | [smzdm roundup](https://post.smzdm.com/p/avgp5e5p/) |
| XDA users enabling "Leica Essential" on regular Ultra | Manual decompile | Confirms the switch is in the camera app itself (dex/resource gating), not server-pushed. | [XDA thread](https://xdaforums.com/t/xiaomi-17-ultra-leica-edition-software-filters-on-regular-17-ultra-possible.4781638/) |

**Gap:** no public project porting the **gallery cloud re-processing** to a non-CN ROM, and no public reverse-engineering of the cloud protocol. Our project would be first — expect the cloud half to be blocked by account/region entitlement.

---

## 4. Magisk v24+ / KernelSU module format (official docs)

Source: [Magisk Developer Guides](https://topjohnwu.github.io/Magisk/guides.html) — **[VERIFIED]**.

- Module = folder `/data/adb/modules/$MODID` with `module.prop` (strict keys: `id`, `name`, `version`, `versionCode`, `author`, `description`, optional `updateJson`; `id` regex `^[a-zA-Z][a-zA-Z0-9._-]+$`; LF line endings).
- **`system/`** is recursively merged into `/system`; existing files replaced, new files added. It is mounted unless `skip_mount` exists.
- **Other partitions:** put files in **`system/vendor`**, **`system/product`**, **`system/system_ext`**; Magisk auto-creates symlinks `vendor`, `product`, `system_ext` → `system/...` at the module root and handles whether the partition is separate. **`mi_ext` is not mentioned** → [NOT FOUND / unsupported by Magisk magic mount]. Confirmed indirectly: third-party [Magic Mount-rs metmodule](https://modules.kernelsu.org/en/modules/magic_mount_rs/) needs an explicit `partitions = ["mi_ext", ...]` config for `mi_ext`, and its `extra_mount` doc explicitly mentions `mi_ext`/`my_product` as special cases. **[VERIFIED that mi_ext requires special handling]**
- **Replace whole folder:** empty file named `.replace` inside the module folder. **Remove file/folder:** dummy char device `mknod <name> c 0 0`, or `REMOVE="..."` in `customize.sh` (installer creates the dummy nodes). `REPLACE="..."` similarly creates `.replace`.
- `system.prop` → loaded as system props via `resetprop` (same `key=value` as build.prop) — this is exactly how the Nezha module applies `ro.theme_*` flags. Note boot-script caveat: use `resetprop -n`, never `setprop`, in `post-fs-data`.
- `sepolicy.rule` for extra SELinux rules; `post-fs-data.sh` (blocking, pre-zygote) vs `service.sh` (late_start, recommended); `action.sh` for a Magisk app Action button.
- Installer zip: `META-INF/com/google/android/update-binary` (= Magisk `module_installer.sh`) + `updater-script` containing only `#MAGISK`, optional `customize.sh` (sourced; can declare `REPLACE`/`REMOVE`, use `ui_print`/`abort`/`set_perm`/`set_perm_recursive`, vars `MODPATH`, `ARCH`, `API`, `BOOTMODE`, `IS64BIT`, ...). Do **not** ship `install.sh`; never call `exit` in `customize.sh`.
- Not from docs but relevant: replacement of `/product/priv-app` APKs needs the proper SELinux context on the payload (`set_perm ...` default context is `u:object_r:system_file:s0`; priv-app APKs normally are `u:object_r:system_file:s0` on many devices but verify) — **[UNCERTAIN]**, local team should verify per-file contexts from the ROM's file_contexts.

### 4.1 Replacing system APKs — signature issues
- Magisk's mount is transparent at the filesystem layer; PackageManager re-scans the APK from the mounted path. Docs say nothing about signature. **[VERIFIED absence]**
- Practical evidence that signature/state mismatch matters: the Nezha module's install steps require **"clear Camera app data"**, and community repacks are explicitly **re-signed** and occasionally rejected / break watermark identity. LSPosed `CorePatch` / `BypassSignCheck` exist specifically to bypass Android signature checks on downgraded/modified system apps (credited by HyperCeiler). **[UNCERTAIN for exact mechanism, VERIFIED that the problem class exists]**
- Recommended mitigation sequence for a module swapping a system APK: keep same package name; `pm clear <pkg>` (and/or `pm uninstall -k --user 0` / remove `/data/app` update leftovers) after first boot; if PM refuses, use CorePatch-style signature-check bypass or patch the APK to keep original signing (hard without keys). Flag to Lead as a risk, verify on-device.

### 4.2 Region / feature gating mechanisms found
- Xiaomi build-time region machinery: `ro.boot.hwc` = CN/GLOBAL/INDIA, `ro.boot.product.hardware.sku`, and per-SKU build.prop files under `/vendor` / `/odm` (e.g. `munch.build.prop` CN, `munchg.build.prop` global/EU, `munchin.build.prop` India) imported dynamically → hybrid fingerprints when cross-flashing. **[VERIFIED]** ([XDA "Switch region without unlock and/or root" p.7](https://xdaforums.com/t/switch-region-without-unlock-and-or-root.4745619/page-7))
- Runtime app-level gating: Xiaomi apps are widely known to use `IS_INTERNATIONAL_BUILD`-style constants / `FeatureParser` / cloud "feature control" (云控). **I could not verify exact symbol names from a public authoritative source in this session → [NOT FOUND / UNCERTAIN].** The concrete verified knob for this device is the property set the Nezha module uses: `ro.theme_customize=LCC`, `ro.theme_leica=true`, plus `camera.debug.safe.check.disable=true` (the last one strongly suggests a camera "safe check" that gates premium/region features — good hook target).
- More upstream feature flags are typically cloud-controlled (`云控`): Xiaomi staff publicly mention "云控能力" for camera/watermark features → some enablement may be server-side even after client unlock. **[UNCERTAIN but supported]** ([IT之家 on 云控能力](https://m.ithome.com/html/849442.htm))

---

## 5. Implications for our Magisk port (recommendations to Lead)

1. **Two-phase plan.** Phase A (feasible, prior art exists): prop + client patch to expose the CN camera/gallery Leica entries on global — reuse `ro.theme_customize=LCC`, `ro.theme_leica=true`, `camera.debug.safe.check.disable=true`, plus LSPosed/dex patches in `com.miui.mediaeditor`/`com.miui.gallery`. Phase B (high risk): cloud second-pass — likely needs CN account + CN server entitlement; assume client-only port yields a dead button. Plan a graceful fallback (hide button / local-only processing).
2. **Local RE targets (grep strings):** `legend`, `legendary`, `leica`, `monopan`, `m9`, `m10r`, `summicron`, `徕卡一瞬`, `传奇一瞬`, `二瞬`, `云端`, `云处理`, `无损`, `端到端`, plus mediaeditor/gallery package names above. The `Legend*` naming from the third-party research repo is the single best lead.
3. **Filesystem payload:** keep everything under `system/`, `system/product`, `system/system_ext`; if the CN ROM puts Leica assets on `/mi_ext`, Magisk (and probably stock KernelSU magic mount) will NOT mount them → either relocate the payload into `system/product` with matching paths, or require the Magic Mount-rs metamodule with `partitions=["mi_ext"]`. Verify partition layout from the extracted ROM first.
4. **Do not blindly `.replace`** app dirs; copy individual files (e.g. the APK) unless whole-dir swap is required. For APK replacement, budget for `pm clear` + possible signature-check bypass (CorePatch approach) and possible Play Integrity / Xiaomi integrity side effects.
5. **Legality/safety note:** the M9/M3 models and Leica assets are proprietary; community practice is unofficial and Xiaomi/Leica have been tightening (signature re-checks, potential billing enforcement after 2026-12-31). Avoid redistributing raw proprietary blobs in the module; extract from the user's own CN ROM at install time if possible.
6. **What would confirm/refute the cloud hypothesis quickly (local work):** decompile CN `com.miui.mediaeditor` / `com.miui.gallery` and look for (a) a Xiaomi cloud SDK / passport (account) dependency, (b) request builder with device/region headers, (c) feature-control JSON keys that gate the "徕卡一瞬" button. If the button is gated by a cloud feature-control key rather than a local `Build.IS_INTERNATIONAL_BUILD` check, client patches alone won't enable it.

---

## 6. Source list (all links)

Primary/technical:
1. [Magisk Developer Guides (official module format)](https://topjohnwu.github.io/Magisk/guides.html)
2. [KernelSU Modules — Magic Mount-rs (mi_ext / extra_mount partitions)](https://modules.kernelsu.org/en/modules/magic_mount_rs/)
3. [mexusbg/Nezha-Leica-Camera-Enabler (repo)](https://github.com/mexusbg/Nezha-Leica-Camera-Enabler) · [README raw](https://raw.githubusercontent.com/mexusbg/Nezha-Leica-Camera-Enabler/main/README.md)
4. [Maga-King/xiaomi-camera-lsposed-bridge (Leica M3/M9 local chain research)](https://github.com/Maga-King/xiaomi-camera-lsposed-bridge)
5. [HyperCeiler (LSPosed, app scopes, CorePatch/BypassSignCheck credits)](https://github.com/ReChronoRain/HyperCeiler)
6. [MIUI Leica Camera Port for AOSP (magisk.dev)](https://magisk.dev/modules/miui-leica-camera-port/)
7. [Xiaomi Gallery Editor `com.miui.mediaeditor` (APKPure)](https://apkpure.net/tw/xiaomi-gallery-editor/com.miui.mediaeditor/download)

Feature / news:
8. [快科技/网易: 小米揭秘徕卡一瞬如何实现（端侧模型+胶片建模, 相册二次增强需 3.0.7.0）](https://m.163.com/dy/article/KI3KGQ8F0511CPVM.html)
9. [微博 @67891abc: 传奇一瞬相机直出免费，收费的是相册二次处理；17U 云端处理永久免费；60 张/月](https://sina.cn/news/detail/5348775912802981.html)
10. [驱动中国: 小米18 Pro「传奇一瞬」详解，原片数据可上传云端无损处理](https://site.qudong.com/article/524278.html)
11. [搜狐: 小米18 Pro「传奇一瞬」功能详解，原片数据可在相册上传云端无损处理](https://www.sohu.com/a/1081321502_114760)
12. [IT之家: 17 Ultra 徕卡版适配 M10R / Summicron 35mm、18 Fold 适配传奇一瞬](https://digi.ithome.com/archiver/1/013/580.htm)
13. [什么值得买: 传奇一瞬直出免费、云端增强 12 月底收费（19 元/月、60 或 40 张/月口径）](https://post.smzdm.com/p/a5rxopw3/)
14. [什么值得买: 徕卡一瞬 0 元破圈（一瞬 vs 二瞬/云端增强、改包只能一瞬不能二瞬、重签名风险）](https://post.smzdm.com/p/avgp5e5p/)
15. [新浪: 小米 18 Pro 影像评测——端云结合模式下的徕卡风格](https://sina.cn/news/detail/5348538848381062.html)
16. [IT之家: 小米苗雷谈云控能力](https://m.ithome.com/html/849442.htm)
17. [网易: 小米17 Ultra 徕卡海外版（Leitzphone）1999 欧元](https://www.163.com/dy/article/KMT029400511B8LM.html?referFrom=)

Forums / community:
18. [XDA: Enable Leica Camera on Xiaomi 17 Ultra (Nezha module thread)](https://xdaforums.com/t/enable-leica-camera-on-xiaomi-17-ultra.4785071/)
19. [XDA: Leica edition software filters on regular 17 Ultra possible? (decompile, Leica Essential)](https://xdaforums.com/t/xiaomi-17-ultra-leica-edition-software-filters-on-regular-17-ultra-possible.4781638/)
20. [XDA: Switch region without unlock and/or root (ro.boot.hwc, per-SKU build.prop)](https://xdaforums.com/t/switch-region-without-unlock-and-or-root.4745619/page-7)
21. [Max Weinbach X post — original Leica flag discovery (cited by Nezha module)](https://x.com/mweinbach/status/2038763588655993271)

---

## 7. Confidence / open questions

- **High confidence:** feature naming/layers, 徕卡一瞬 exclusivity to Leica Edition, cloud second pass existence and its dependence on Xiaomi cloud entitlement, Magisk module format & partition rules, existence and content of the nezha Leica enabler module, `mi_ext` needing special handling.
- **Medium confidence:** exact quota numbers (60 vs 40/month), "permanently free for 17U" (single blogger), whether global Leitzphone truly lacks layer 2 (no direct test found), exact clouds SDK/account dependency.
- **Not found:** cloud endpoint/API/protocol, exact APK class/method names for the upload, any public port of the cloud half, authoritative `IS_INTERNATIONAL_BUILD`/`FeatureParser` documentation.
- **Next step for team:** verify against extracted ROM — partitions present (`mi_ext`?), presence/version of `com.miui.mediaeditor` and `com.miui.gallery`, grep `legend/leica/monopan/云处理`, and diff CN vs global APK for the gallery entry point.
