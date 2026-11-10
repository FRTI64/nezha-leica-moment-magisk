# Leica Moment Port (nezha) — Magisk modules

Porting layer for the China-ROM **徕卡一瞬 / 二次增强** (Leica Moment / Leica look cloud
re-render) feature onto the **global HyperOS 4 ROM of the Xiaomi 17 Ultra (`nezha`)**.

> **User requirement: no property spoofing** (「不想通过伪装属性的方式使用」).
> The recommended artifact is therefore **`LeicaMoment_nezha_v1.2.0_CameraOnly.zip`**, which
> replaces the camera APK **only** and makes **no system-property changes of any kind**.
> Feature gating is moved out of Magisk into the separate **LSPosed module** (direct method
> hooks). The older `PropsOnly` / `Full` variants are kept for reference but are **DEPRECATED**
> because they set system properties via Magisk (`resetprop`).

*No on-device test was possible for this build* (no device attached); everything below is based
on static analysis of the two ROMs, verified Magisk behaviour and the official Magisk module
rules. Treat the modules as experimental.

* Global ROM analysed: `OS4.0.0.8.XPAMIXM` (`ro.product.mod_device=nezha_global`)
* CN ROM source: `OS4.0.5.0.XPACNXM` (`ro.product.mod_device=nezha`)
* Companion documents: [`ANALYSIS.md`](../docs/ANALYSIS.md) (overall synthesis),
  [`LSPOSED_MODULE.md`](../docs/LSPOSED_MODULE.md) (no-props gating module),
  [`global_analysis.md`](../docs/global_analysis.md) (detailed evidence + smali refs),
  [`research_web.md`](../docs/research_web.md). Camera-hook research (task-9) will land in
  `docs/camera_hook_targets.md`; it was still in progress when this module was built.

---

## 1. Deliverables

| File | Prop spoofing? | Contents | Recommendation |
|---|---|---|---|
| `dist/LeicaMoment_nezha_v1.2.0_CameraOnly.zip` | **NO — none at all** | CN `MiuiCamera.apk` (6.7.000280.0) magic-mounted over `/product/priv-app/MiuiCamera/MiuiCamera.apk`; stale ART oat/vdex hidden; one-time camera data clear. No property layer. | **RECOMMENDED** (fits "no property faking") |
| `dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | yes (`resetprop`) | Property layer only; no APK payload. | DEPRECATED — use CameraOnly / LSPosed |
| `dist/LeicaMoment_nezha_v1.0.0_Full.zip` | yes (`resetprop`) | Property layer + CN camera APK payload. | DEPRECATED — use CameraOnly |
| `dist/SHA256SUMS.txt` | — | sha256 of the three zips. | — |
| `BUILD_INFO.md` | — | Input hashes, per-file lists, build commands, full validation + no-prop grep output. | — |

All variants share module id `nezha_leica_moment`: flash **one** of them. Flashing another
variant later replaces it (same id). Versions: CameraOnly `1.2.0-cameraonly` /
versionCode `12000`; the two deprecated props variants stay at `1.0.0` / `10000`.

The zips ship `action.sh` + `diag.sh` diagnostics (Magisk **Action** button, see §5.3). The
CameraOnly diagnostics do **not** report any spoofed property — there is nothing spoofed.

---

## 2. CameraOnly = no property spoofing (guaranteed)

The CameraOnly variant contains only:

```
module.prop
META-INF/com/google/android/{update-binary,updater-script}
customize.sh                    # REMOVE="/system/product/priv-app/MiuiCamera/oat" + permissions
post-fs-data.sh                 # NO-OP: only writes a boot-marker line to the module log
service.sh                      # one-time am force-stop + pm clear com.android.camera (guarded)
uninstall.sh                    # removes the module's runtime data dir on uninstall
action.sh / diag.sh             # diagnostics (camera APK/versions/log; no property fields)
README.md
system/product/priv-app/MiuiCamera/MiuiCamera.apk   # CN MiuiCamera 6.7.000280.0
```

Guarantees and how they are enforced:

* **No property-setting calls anywhere.** No `resetprop`, no `setprop`, no `SystemProperties`
  manipulation in any script. `post-fs-data.sh` is a no-op marker only (it does not create the
  old `/data/adb/leica_moment/config.env` property layer either).
* **No property *names* in any non-APK zip entry.** `build.sh` runs `verify_no_props()` on the
  built zip: the build fails if any non-APK entry contains `resetprop` or the property names
  that the deprecated variants used to fake. Evidence (grep over the built zip) is recorded in
  `BUILD_INFO.md` §6.
* **Nothing outside the mount layer changes on the device.** The real `/product` partition is
  never written; uninstall + reboot restores the stock camera APK and its ART files.
  The only persistent side effects are the module's runtime dir `/data/adb/leica_moment/`
  (logs + data-clear guard) and one-time camera app data clear (see below).

`service.sh` is identical in logic to the deprecated Full variant but without any property
dependency: after boot it verifies that the CN APK is really active (on-device APK size
`200,627,029` and `versionName 6.7.000280.0`), then runs
`am force-stop com.android.camera` + `pm clear com.android.camera` **once** (guard file
`/data/adb/leica_moment/.camera_cleared_6.7.000280.0`). If the payload is not active it only
logs a warning and does not touch camera data.

---

## 3. What is proven (static analysis)

1. **The global ROM already ships the whole editor/cloud stack.** Global
   `com.miui.mediaeditor` 2.10.40.4.8-global contains `LegendaryActivity`,
   `LegendaryViewModel`, `LegendaryJobManager`, `aigc.cloud.internal.legend.LegendCloudManager`,
   `EdgeCloudLegendAlgorithm` and the same endpoints as CN:
   `https://api.open.ai.xiaomi.com` + `/aiPhotoCloud/api/legend/create|getResult`,
   `/aiPhotoCloud/api/legendV2/create|getResult|list`. Global `com.miui.gallery` Flutter assets
   are byte-identical to CN (`app_tools.json`, `app_functions_v2.xml`, 一瞬/徕卡 strings).
   ⇒ **No CN gallery/editor APK is needed.**
2. **The editor CTA is gated by an exact predicate.** In the global mediaeditor,
   `MediaEditorProviderForGallery` answers `method_is_legend_available` using
   `Build.DEVICE=="nezha" && ro.theme_customize=="LCC" && ro.miui.build.region=="cn"`.
   The predicate is read per call; it is reachable by **direct method hooks**
   (`mx.a.g()`, `r21.e.b()` in the global build) — this is what the LSPosed module does in
   no-props mode (see §4), **without touching any property**.
3. **The Leica-SKU props are normally never set on a non-Leica unit.** Both ROMs contain
   byte-identical `/odm/etc/nezha_5.x.prop` overrides, but they are only imported when the
   bootloader SKU/hwversion selects them. (This is why the *deprecated* variants used Magisk
   `resetprop`; the no-props path replaces them with LSPosed method hooks instead.)
4. **APK replacement is signature-compatible.** CN and global MiuiCamera are signed v2+v3 with
   the *same* Xiaomi MIUI certificate, SHA-256
   `c9009d01ebf9f5d0302bc71b2fe9aa9a47a432bba17308a3111b75d7b2149025` (verified from
   `META-INF/CERT.RSA` of both APKs). Same package name, higher `versionCode`
   (670002800 vs 660005705) ⇒ the package manager treats the mounted CN APK as an update.
5. **The capture-side Leica-Edition UI lives only in the CN camera APK.** CN MiuiCamera
   6.7.000280.0 adds dex/resources that global 6.6.000570.5 does not have
   (`legend_ccd/cmos/bw`, `legend_35mm/75mm`, `legendary_leica_m3/m9/m10r_{icon,template,text_icon,logo}`,
   `legendary_summicron_35mm`, `legendary_summilux_75mm`, `isLeicaMode`, `isLeicaCustomize`, …);
   global `resources.arsc` has 0 of those. The Leica filter coefficients themselves
   (`/odm/etc/camera/leica_filter_param*.bin`, `mialgo_monopan_cl.bin`) are present on **both**
   ROMs, byte-identical.
6. **The global `/product` partition has stale ART artifacts for the old camera APK**
   (`/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.odex` 295,768 B,
   `MiuiCamera.vdex` 47,645,728 B, from the OS4.0.0.8 image). They are hidden by the module so
   ART recompiles the replaced APK.
7. **Magisk can mount exactly `/system`, `/vendor`, `/product`, `/system_ext`**
   (`SECONDARY_READ_ONLY_PARTITIONS` in Magisk's `native/src/core/module.rs`), so
   `/product/priv-app/MiuiCamera/...` is a supported payload path
   (`system/product/priv-app/MiuiCamera/MiuiCamera.apk` in the zip). `/odm`, `/mi_ext` are not
   mountable; no `/product/priv-app/MiuiCamera` entry exists in the global `mi_ext` dump, so
   MIUI's `mi_ext` overlay is not expected to shadow this payload (verify on device, §9).

---

## 4. Feature gating in no-props mode (LSPosed)

CameraOnly deliberately does **not** unlock anything by itself: gating stays exactly as on the
stock ROM. The no-props unlock is provided by the separate **LSPosed module** documented in
[`LSPOSED_MODULE.md`](../docs/LSPOSED_MODULE.md), which hooks the app's availability
**methods** instead of faking system properties:

* **Gallery editor → 二次增强 / 徕卡一瞬 entry:** LSPosed module v2.0.0 (no-props rebuild,
  task-10) replaces the earlier in-process `SystemProperties` masking with direct
  availability-predicate hooks (`mx.a.g()` / `r21.e.b()` on global mediaeditor, `rt.a.g()` /
  `ah0.b.g()` on CN mediaeditor) and keeps the Xiaomi-account Cookie/login features. No global
  property is modified; the user still has to accept the CTA and pass server-side entitlement.
* **Camera capture-side Leica UI:** the CN camera APK alone is not enough — the camera decides
  whether to offer the Leica-Edition capture UI by reading cached SKU/theme flags. A no-props
  path therefore needs **LSPosed camera hooks** (research task-9, in progress; will be
  documented in `docs/camera_hook_targets.md`). **This LSPosed camera-hook piece is not
  finished yet.** Until it exists, expect the CN camera to behave like the global camera in
  terms of feature gating even with CameraOnly flashed (the new APK/resources are present, but
  the mode may not be offered).
* **Editor-only users need no Magisk module at all.** If you only care about the gallery
  editor's 二次增强 entry, use just the LSPosed module; do not flash a camera module.
* **Cloud entitlement is server-side** (hardware-auth token, account, CTA, server device lists,
  quota: `leica_support_devices` / `lcc_support_devices`). No client-side module can grant it.

---

## 5. What the modules do

### 5.1 CameraOnly (recommended)

See §2. Summary: magic-mounts the CN camera APK, hides stale ART oat/vdex, clears camera app
data once after verifying the swap — and nothing else. No property layer, no `post-fs-data`
property code, no region spoof.

### 5.2 Deprecated props-based variants (PropsOnly / Full)

These are kept for reference/experiments only. They **do** set system properties every boot via
`post-fs-data.sh` + `resetprop -n` (which writes the property area directly and bypasses
`property_service`; `setprop` would deadlock in that boot stage):

| Property | Value | Controlled by | Why (deprecated path) |
|---|---|---|---|
| `ro.theme_customize` | `LCC` | `LEICA_SKU_PROPS=1` | Editor predicate; camera theme readers |
| `ro.theme_leica` | `true` | `LEICA_SKU_PROPS=1` | Leica-SKU flag |
| `ro.boot.product.theme_customize` | `P1_Leica` | `LEICA_SKU_PROPS=1` | Camera/watermark readers |
| `ro.special_edition` | `true` | `LEICA_SKU_PROPS=1` | Leica-Edition SKU flag |
| `camera.debug.safe.check.disable` | `true` | Full only | Camera debug switch |
| `ro.miui.build.region` | `cn` | `REGION_SPOOF=1` (default) | **Global region spoof** required by the editor predicate |

> These variants are **DEPRECATED for the "no property faking" requirement**: they change
> global ROM properties (and `REGION_SPOOF=1` changes `ro.miui.build.region` for the whole
> system, with OTA/region-feature side effects). Use CameraOnly + LSPosed instead.

### 5.3 Diagnostics (Magisk Action button)

All variants ship `action.sh` (Action button entry point) + `diag.sh` (collector). Magisk shows
an **Action** button on the module card; tapping it appends a snapshot to
`/data/adb/leica_moment/diag.log` and prints the tail in the console. The same snapshot can be
produced from a shell:

```sh
adb shell su -c 'sh <module-dir>/diag.sh'
adb pull /data/adb/leica_moment/diag.log
```

Common content: date, module id/version, ROM incremental, device ids, module camera payload
presence/size, on-device `/product/priv-app/MiuiCamera/MiuiCamera.apk` and `oat` type/size,
`versionName`/`versionCode`/`codePath` for `com.android.camera` and `com.miui.mediaeditor`, the
last 40 lines of `module.log`, and follow-up commands. The **CameraOnly** snapshot explicitly
says the variant modifies no properties and contains no property fields; the deprecated
variants also dump their Leica/region property values. Read-only apart from appending
`diag.log`; well under 5 s.

### 5.4 What the modules do NOT do

* No Xposed/Zygisk hooks, no APK patching/re-signing, no CN gallery/editor replacement.
* No server/entitlement bypass, no device model/cert/attestation spoofing, no account tricks.
* No `/odm` or `mi_ext` modification (Magisk cannot magic-mount them anyway).
* CameraOnly does not change properties; the *deprecated* variants do (by design).

---

## 6. Requirements

* Xiaomi 17 Ultra (`nezha`), global HyperOS 4 ROM `OS4.0.0.8.XPAMIXM` (analysis baseline).
  Other builds / CN ROM / future OTAs are untested; the camera payload is a CN-ROM APK.
* Unlocked bootloader + **Magisk** (module installer requires Magisk v20.4+; a current Magisk
  release is recommended). KernelSU/APatch are **untested** (the REMOVE/dummy-device semantics
  are Magisk-specific).
* For feature gating in no-props mode: **LSPosed** + the separate LSPosed module
  (`docs/LSPOSED_MODULE.md`), and for the camera capture UI an LSPosed camera-hook build that
  is still being researched (task-9).
* Space: the CameraOnly zip is ~118 MiB (~124 MB) compressed; installed payload ~192 MB in
  `/data/adb/modules/nezha_leica_moment/`. PropsOnly is ~11 KB.
* A way to disable modules if something goes wrong (see §10), and a Xiaomi account for the
  cloud feature (server-side).

---

## 7. Install

1. Copy the chosen zip to the phone.
2. Magisk app → **Modules** → **Install from storage** → pick the zip → reboot.
   (Recovery flashing also works; `META-INF/com/google/android/update-binary` is the official
   Magisk `module_installer.sh`.) If the camera app has been updated from GetApps/Play, the
   `/data/app` update takes precedence over the mounted system APK — remove the update once
   and reboot: `su -c 'cmd package uninstall-system-updates com.android.camera'`.
3. First boot: `post-fs-data.sh` only writes a boot marker (CameraOnly); `service.sh` waits for
   boot completed, verifies the APK, and clears camera data once (the camera may be killed).
4. Verify (root shell):

```sh
su
stat -c '%s' /product/priv-app/MiuiCamera/MiuiCamera.apk     # expect 200627029
stat -c '%F' /product/priv-app/MiuiCamera/oat                # expect: character special file
dumpsys package com.android.camera | grep -m1 versionName    # expect 6.7.000280.0
cat /data/adb/leica_moment/module.log                        # "CameraOnly variant booted -- no system properties ..."
```

   There is no `getprop` checklist for CameraOnly — this variant sets nothing.
5. Install/activate the LSPosed module for feature gating (see `docs/LSPOSED_MODULE.md`); for
   the camera capture UI, camera hooks are still in research (task-9). Accept the CTA in the
   editor if prompted and be logged into a Xiaomi account; watch logcat while triggering the
   cloud job:

```sh
adb logcat | grep -Ei 'LeicaMomentLSP|LegendCloudManager|legendary|mediaeditor|hardwareAuthToken'
```

---

## 8. Configuration (deprecated props variants only)

Only `PropsOnly`/`Full` use `/data/adb/leica_moment/config.env`, created with defaults on first
boot; edit it and **reboot** (post-fs-data reads it once per boot). `CameraOnly` creates no
config file and ignores this section.

```sh
# 1 = spoof ro.miui.build.region=cn; 0 = leave the ROM region untouched
REGION_SPOOF=1

# 1 = set ro.theme_customize=LCC + ro.theme_leica=true + ro.boot.product.theme_customize=P1_Leica + ro.special_edition=true
LEICA_SKU_PROPS=1

# 1 = one-time `pm clear com.android.camera` after the camera APK swap (Full variant only)
CLEAR_CAMERA_DATA=1
```

> **Region-spoof warning (deprecated variants, default ON).** `REGION_SPOOF=1` changes
> `ro.miui.build.region` from `global` to `cn` **for the whole ROM** — every app and framework
> component that reads this property sees a China-region device (possible OTA/update
> behaviour, region-locked features, theme/cloud/ads routing). This is exactly the property
> faking the user asked to avoid; use CameraOnly + LSPosed no-props hooks instead.

---

## 9. Troubleshooting checklist

| Symptom | Check / fix |
|---|---|
| Camera still the old version (any variant with payload) | `stat -c '%s' /product/priv-app/MiuiCamera/MiuiCamera.apk` must be `200627029`; if not, the module is disabled/not mounted, or a `/data/app` camera update is active → `cmd package uninstall-system-updates com.android.camera` + reboot. `service.sh` logs `on device : version=… codePath=…` and a warning. |
| Camera crashes / behaves oddly | Remove the module and reboot; the stock camera returns. |
| No Leica capture UI with CameraOnly | Expected until the LSPosed camera hooks exist (task-9, in progress): CameraOnly intentionally does not fake properties, so the camera's own gating is unchanged. |
| Editor CTA (徕卡一瞬 / 二次增强) not visible | Needs the LSPosed module (v2.0.0 no-props mode) active for `com.miui.mediaeditor` + reboot, plus Xiaomi account + CTA acceptance; the Magisk module does not gate the editor. |
| CTA visible but cloud job fails / queues forever / 4xx | Expected residual risk — server-side entitlement/`hardwareAuthToken`/account/CTA/CloudConfig. Check logcat; there is no client-side fix. |
| Artifacts / slow first camera start | Expected: `oat` is hidden and ART recompiles after the APK swap; subsequent starts are normal. |
| MIUI overlay shadowing | `stat -c '%F' /product/priv-app/MiuiCamera/oat` should be `character special file`; `mount | grep -E 'mi_ext|overlay'`. |
| Need a snapshot for a bug report | Tap the module's **Action** button, or run `diag.sh` (§5.3), then share `/data/adb/leica_moment/diag.log`. |
| Deprecated variants: props not applied | Check `/data/adb/leica_moment/module.log`; reboot after editing `config.env` (that mechanism does not exist in CameraOnly). |

---

## 10. Uninstall, disable, bootloop recovery

**Uninstall / revert (camera APK and any deprecated-variant props revert automatically):**

1. Magisk app → Modules → remove the module → reboot, **or**
   `su -c 'touch /data/adb/modules/nezha_leica_moment/remove'` and reboot.
2. After reboot the real `/product` camera APK, its oat/vdex and all stock props are back
   (the modules only ever changed the mount layer; property changes are runtime-only).
3. Optional cleanup: `su -c 'pm clear com.android.camera'` (remove CN-camera app data so the
   global camera starts clean) and `rm -rf /data/adb/leica_moment` if left behind.

**Disable without uninstalling:** Magisk app toggle, or
`su -c 'touch /data/adb/modules/nezha_leica_moment/disable'` → reboot. The module is not
mounted; camera data is kept.

**Bootloop / boot problems.** The modules do not modify any real partition, so a true bootloop
is unlikely (camera-only crashes are more likely and only affect the camera app), but keep these
escape hatches: Magisk **Safe Mode** (hold the device's safe-mode key/Volume Down while booting —
Magisk then disables all modules for that boot; check current Magisk docs for your device), or
boot TWRP/recovery and delete `/data/adb/modules/nezha_leica_moment` (or create a file named
`disable` inside it), or use `adb shell magisk --remove-modules` if adb and root are available.
If you cannot get a shell/recovery, re-flash the stock boot image / Magisk-patched boot of your
ROM to recover (data is not touched by these modules).

---

## 11. Risks

| Risk | Level | Applies to | Notes / mitigation |
|---|---|---|---|
| Camera capture UI still gated (no-props mode needs LSPosed camera hooks, task-9 in progress) | Medium–High | CameraOnly | The module only ships the CN APK/resources; until the no-props camera hooks exist the Leica capture UI may not be offered. |
| Cloud job refused server-side (entitlement, quota, `hardwareAuthToken`, CN account, CTA) | High | all | Unfixable client-side; the CTA may show but the job may fail. Not bypassed. |
| Camera APK replacement side effects | Medium | CameraOnly, Full | One-time data clear (settings/history lost), CN-localised UI/telemetry, 3 CN-only manifest permissions, version differs from global. Remove module to revert. |
| LSPosed dependency for gating | Medium | CameraOnly (feature-wise) | No Magisk-only unlock in no-props mode by design; LSPosed modules are also experimental/untested on device. |
| Stale-oat removal / ART recompile | Low–Medium | CameraOnly, Full | First camera start slower; background dex2oat. Remove module to revert. |
| MIUI `/mi_ext` overlay shadowing the `/product` payload | Low | CameraOnly, Full | Verified absent in the OS4.0.0.8 image dump; check `stat` output in §7. |
| OTA / future ROM updates | Medium | all | OTA may replace camera/editor; the module keeps overriding with the older CN camera APK. Re-evaluate/disable before OTA; no OTA guarantee. |
| **Region spoof side effects** (`ro.miui.build.region=cn`) | Medium–High | **deprecated PropsOnly/Full only** | Whole-ROM region change (OTA/region features/apps/theme/cloud). Not present in CameraOnly. |
| Play Integrity / attestation | Low by design | all | No module sets model/cert/attestation props; Magisk itself remains the usual factor. |
| Data/privacy | Medium | all | CN camera APK may contact CN services; cloud feature requires a Xiaomi account + CTA acceptance. |
| Brick/bootloop | Low | all | No partition writes; recovery paths in §10. |

**No warranty. This is an experimental research build; you are responsible for your device,
your account and your data.**

---

## 12. Repository layout

```
work/leica/module/
├── README.md            <- this file
├── BUILD_INFO.md        <- hashes, file lists, build commands, validation + no-prop grep output
├── build.sh             <- rebuilds all variants (assemble src/ -> validate -> dist/);
│                           enforces the CameraOnly no-props contract
├── smoke_test.sh        <- offline script-logic tests (stubbed environment, no device needed)
├── common/              <- source of truth for the shared module files
│   ├── module.prop.tmpl customize.sh post-fs-data.sh service.sh uninstall.sh
│   ├── action.sh diag.sh README.md
│   └── cameraonly/      <- CameraOnly-specific no-props scripts + README
├── src/CameraOnly/      <- complete Magisk module root, no property changes (generated)
├── src/PropsOnly/       <- complete Magisk module root, deprecated props variant (generated)
├── src/Full/            <- complete Magisk module root, deprecated props + APK (generated)
└── dist/                <- flashable zips + SHA256SUMS.txt
```

Rebuild: `cd work/leica/module && ./build.sh` (`all` | `cameraonly` | `propsonly` | `full`).
It pins the CN APK sha256, copies the official `update-binary`/`updater-script` from
`work/leica/module_skel/`, runs `work/leica/scripts/build_module.sh` (which validates each zip
with `work/leica/scripts/check_module.py`), verifies the APK payload hash inside each payload
zip, and — for CameraOnly — fails the build if any non-APK entry contains a property-spoofing
string. `./smoke_test.sh` executes the real boot scripts against stubbed Android commands
(including CameraOnly's no-property guarantee).

---

## 13. Technical references

* Magisk developer guides (module layout, `REMOVE`/`REPLACE`, boot scripts, `setprop` deadlock):
  <https://topjohnwu.github.io/Magisk/guides.html>
* Magisk tools (`resetprop -n` = bypass property_service):
  <https://topjohnwu.github.io/Magisk/tools.html>
* Magisk `SECONDARY_READ_ONLY_PARTITIONS` (`/vendor`, `/product`, `/system_ext`):
  <https://github.com/topjohnwu/Magisk/blob/master/native/src/core/module.rs>
* Magisk official `module_installer.sh` (`REMOVE` → `mknod $MODPATH$TARGET c 0 0`):
  <https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh>
* LSPosed: <https://github.com/LSPosed/LSPosed>, module dev docs:
  <https://github.com/LSPosed/LSPosed/wiki/Develop-Xposed-Modules>
