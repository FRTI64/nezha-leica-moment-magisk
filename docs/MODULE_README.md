# Leica Moment Port (nezha) — Magisk module

Porting layer for the China-ROM **徕卡一瞬 / 二次增强** (Leica Moment / Leica look cloud
re-render) feature onto the **global HyperOS 4 ROM of the Xiaomi 17 Ultra (`nezha`)**.

This directory contains the module sources, the build script and two built flashable zips.
**No on-device test was possible for this build** (no device attached); everything below is
based on static analysis of the two ROMs, verified Magisk behaviour and the official
Magisk module rules. Treat the module as experimental.

* Global ROM analysed: `OS4.0.0.8.XPAMIXM` (`ro.product.mod_device=nezha_global`)
* CN ROM source: `OS4.0.5.0.XPACNXM` (`ro.product.mod_device=nezha`)
* Companion analysis: [`ANALYSIS.md`](../docs/ANALYSIS.md) (overall synthesis),
  [`global_analysis.md`](../docs/global_analysis.md) (detailed, with smali evidence refs),
  evidence under `work/leica/global/analysis/`; web research under
  [`research_web.md`](../docs/research_web.md).

---

## 1. Deliverables

| File | Contents | Flash when |
|---|---|---|
| `dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | Property layer only. No APK payload, no camera data clear. | You want to test the editor-side gating (CTA predicate) with the global camera untouched. Smallest/safest. |
| `dist/LeicaMoment_nezha_v1.0.0_Full.zip` | Property layer + CN `MiuiCamera.apk` (6.7.000280.0) replacing `/product/priv-app/MiuiCamera/MiuiCamera.apk`; stale ART oat/vdex hidden; one-time `pm clear com.android.camera`. | You want the capture-side Leica-Edition code from the CN camera build. |
| `dist/SHA256SUMS.txt` | sha256 of both zips. | — |
| `BUILD_INFO.md` | Input hashes, per-file lists, build commands, full validation output. | — |

Both variants share module id `nezha_leica_moment`: flash **one** of them. Flashing the
other variant later replaces it (same id). Both zips also ship `action.sh` + `diag.sh`
diagnostics (Magisk **Action** button, see §4.5).

Module id `nezha_leica_moment`; runtime data/log dir `/data/adb/leica_moment/`.

---

## 2. What is proven (static analysis)

1. **The global ROM already ships the whole cloud/editor stack.** Global
   `com.miui.mediaeditor` 2.10.40.4.8-global contains `LegendaryActivity`,
   `LegendaryViewModel`, `LegendaryJobManager`, `aigc.cloud.internal.legend.LegendCloudManager`,
   `EdgeCloudLegendAlgorithm` and the same endpoints as CN:
   `https://api.open.ai.xiaomi.com` + `/aiPhotoCloud/api/legend/create|getResult`,
   `/aiPhotoCloud/api/legendV2/create|getResult|list`. Global `com.miui.gallery` Flutter assets
   are byte-identical to CN (`app_tools.json`, `app_functions_v2.xml`, 一瞬/徕卡 strings).
   ⇒ **No CN gallery/editor APK is needed**; only the gating state and (for capture) the
   camera APK.
2. **The editor CTA is gated by an exact, runtime-read predicate.** In the global
   mediaeditor, `MediaEditorProviderForGallery` answers `method_is_legend_available` with:
   ```
   Build.DEVICE == "nezha"
     && SystemProperties.get("ro.theme_customize", "").equals("LCC")
     && SystemProperties.get("ro.miui.build.region", "cn").equalsIgnoreCase("cn")
   ```
   `ro.miui.build.region` is read *per call* (no static cache), and the target device is
   already `nezha`, so two `resetprop` values flip the predicate. (There is a second,
   mutually exclusive predicate `method_is_xm_legend_available` = device in
   `{hongkong, madrid, nezha}` && `ro.theme_customize != LCC` && region `cn`.)
3. **The Leica-SKU props are normally never set on a non-Leica unit.** Both ROMs contain
   byte-identical `/odm/etc/nezha_5.x.prop` overrides (`ro.boot.product.theme_customize=P1_Leica`,
   `ro.theme_customize=LCC`, `ro.theme_leica=true`, `ro.special_edition=true`, …), but they are
   only imported when the bootloader SKU/hwversion selects them. `ro.theme_customize` is absent
   from every flashable `build.prop` on both ROMs. ⇒ a Magisk props layer is the correct tool.
4. **APK replacement is signature-compatible.** CN and global MiuiCamera are signed v2+v3 with
   the *same* Xiaomi MIUI certificate, SHA-256
   `c9009d01ebf9f5d0302bc71b2fe9aa9a47a432bba17308a3111b75d7b2149025`
   (verified from `META-INF/CERT.RSA` of both APKs and via androguard). Same package name,
   higher `versionCode` (670002800 vs 660005705) ⇒ the package manager treats the mounted CN
   APK as an update, no signature mismatch.
5. **The capture-side Leica-Edition UI lives only in the CN camera APK.** CN MiuiCamera
   6.7.000280.0 adds dex/resources that global 6.6.000570.5 does not have
   (`legend_ccd/cmos/bw`, `legend_35mm/75mm`, `legendary_leica_m3/m9/m10r_{icon,template,text_icon,logo}`,
   `legendary_summicron_35mm`, `legendary_summilux_75mm`, `isLeicaMode`, `isLeicaCustomize`, …);
   global `resources.arsc` has 0 of those. Global camera only has a partial skeleton
   (`LegendaryModule`, `LegendaryEnter`, `LegendarySelectedActivity`, base `legendary_m3/m9`).
   The Leica filter coefficients themselves (`/odm/etc/camera/leica_filter_param*.bin`,
   `mialgo_monopan_cl.bin`) are present on **both** ROMs, byte-identical.
6. **The global `/product` partition has stale ART artifacts for the old camera APK**
   (`/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.odex` 295,768 B,
   `MiuiCamera.vdex` 47,645,728 B, from the OS4.0.0.8 image). They are hidden by the module so
   ART recompiles the replaced APK.
7. **Magisk can mount exactly `/system`, `/vendor`, `/product`, `/system_ext`**
   (`SECONDARY_READ_ONLY_PARTITIONS` in Magisk's `native/src/core/module.rs`), so
   `/product/priv-app/MiuiCamera/...` is a supported payload path
   (`system/product/priv-app/MiuiCamera/MiuiCamera.apk` in the zip). `/odm`, `/mi_ext` are not
   mountable; no `/product/priv-app/MiuiCamera` entry exists in the global `mi_ext` dump, so
   MIUI's `mi_ext` overlay is not expected to shadow this payload (verify on device with the
   commands in §6).

---

## 3. What is NOT proven (may fail on device)

* **The cloud job itself is server-side.** Even with the CTA visible, the create-task request
  carries `imgUrl`, Xiaomi account cookie, `Build.DEVICE`, an `isLCC` flag and is authenticated
  with a device-attestation `hardwareAuthToken` (`https://api.open.ai.xiaomi.com/auth/v1/hardwareAuthToken`,
  `.../hardwareNonce`). Results are metered server-side (`deductType`, `points`, `counts`).
  Support lists `leica_support_devices`, `lcc_support_devices`, `mist_support_devices` are
  **delivered by the server** (camerainfra CloudConfig), not present in the ROM. A global-ROM,
  non-CN-account device can therefore be **refused (4xx) or charged/limited** by the server.
  **There is no client-side fix for this** and this module does not attempt one.
* **The cloud path needs state the module cannot create:** a logged-in Xiaomi account, the
  **CTA/privacy agreement** accepted (`CloudConfig.initialize` is deferred until CTA), the
  camerainfra CloudConfig rules (MiPush CN / FCM global push channel, `mediaeditor_filter_config_v2`)
  and runtime-downloaded SDKs (`legend_mode`, `algorithm_monopan`). Also `/odm/etc/default_cloud.json`
  (encrypted cloud config) differs CN vs global and is not decodable — it may carry region switches.
* **The capture-side UI may itself be partly server/SDK-gated.** CN camera references
  `com.android.camera.legend.fragment.FragmentLegendaryIntroduction/FragmentLegendarySelected/
  LegendarySelectedAdapter` which are not defined in any CN APK we have; they likely ship with
  the runtime-downloaded `legend_mode` SDK. The local look resources are in the CN APK, but the
  full Leica-Edition capture UI might require a download the server may refuse.
* **Camera replacement side effects are untested:** CN camera declares 3 permissions the global
  APK does not (`android.permission.START_TASKS_FROM_RECENTS`,
  `com.android.camera.permission.MIPUSH_RECEIVE`, `com.miui.permission.HANG_UP_CHANGED`);
  privileged-permission allowlists / MIUI privacy checks on the global ROM could log or deny
  them. CN camera may also be CN-localised (some new UI strings are zh-CN first) and may talk to
  CN services for non-Leica features.
* **No end-to-end on-device test was possible here.** Everything was validated statically
  (ROM dumps + APK analysis) and structurally (official Magisk module rules, see BUILD_INFO.md).

**Realistic expectation:** the editor CTA (徕卡一瞬 / 二次增强 entry) *should become visible* on
the Full variant (and, for the editor predicate alone, on PropsOnly) once the props are active.
Whether the cloud re-render **completes** is a server entitlement question and may still fail.
The capture-side Leica looks should become available in the camera only if the CN APK's
Leica-Edition resources are enough on this ROM/hardware; the SDK part may remain gated.

---

## 4. What the module actually does

### 4.1 Property layer (`post-fs-data.sh`, every boot)

Applied with `resetprop -n` (writes the property area directly, bypassing
`property_service`; `setprop` would deadlock the boot process in this stage — see
[Magisk tools: resetprop](https://topjohnwu.github.io/Magisk/tools.html) and
[Magisk guides: boot scripts](https://topjohnwu.github.io/Magisk/guides.html)).

| Property | Value | Controlled by | Why |
|---|---|---|---|
| `ro.theme_customize` | `LCC` | `LEICA_SKU_PROPS=1` | Editor predicate `method_is_legend_available`; also read by the camera settings/watermark classes. |
| `ro.theme_leica` | `true` | `LEICA_SKU_PROPS=1` | Leica-SKU flag used by MIUI/camera theme paths. |
| `ro.boot.product.theme_customize` | `P1_Leica` | `LEICA_SKU_PROPS=1` | Best-effort; read by camera `Lcb/c`, `Lag/c$a` and the watermark code. Harmless if ignored. |
| `ro.special_edition` | `true` | `LEICA_SKU_PROPS=1` | Leica-Edition SKU flag (from `/odm/etc/nezha_5.x.prop`); MIUI/camera theme paths may read it. |
| `camera.debug.safe.check.disable` | `true` | Full variant only | Camera debug switch read by the MiuiCamera settings class. |
| `ro.miui.build.region` | `cn` | `REGION_SPOOF=1` (default) | **Required** by the editor CTA predicate; also used by camera watermark region logic. |

Explicitly **not** set: `ro.product.model*`, `ro.product.odm.model/cert`,
`ro.product.model_for_attestation`, `ro.product.odm.marketname`,
`ro.product.odm.support_cai`, satellite props (`ro.bdsms`, `ro.tiantong`) — model/cert/
attestation spoofing would break Play Integrity/attestation, the satellite props describe
hardware the device may not have, and none of these are required by the editor predicate.
(`ro.product.odm.marketname` / `ro.product.odm.support_cai` are Leica-SKU extras that
advanced users can add to the script manually, at their own risk.)

No `system.prop` is shipped on purpose: every property is conditional on
`/data/adb/leica_moment/config.env`, which a static `system.prop` cannot honour.

### 4.2 Camera payload layer (Full variant)

* `system/product/priv-app/MiuiCamera/MiuiCamera.apk` = CN MiuiCamera 6.7.000280.0
  (200,627,029 B, sha256 `4637b77d…08f63`). Magisk magic-mounts it over the real
  `/product/priv-app/MiuiCamera/MiuiCamera.apk`; **the partition is not modified**.
* `customize.sh` declares `REMOVE="/system/product/priv-app/MiuiCamera/oat"`. Magisk's installer
  turns each `REMOVE` entry into a dummy character device (`mknod $MODPATH$TARGET c 0 0`;
  `util_functions.sh` → `install_module()`), which hides the stale
  `/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.{odex,vdex}` compiled for the old APK and
  forces ART to recompile the new one. Note the `/system/` prefix: Magisk prepends `$MODPATH`
  to each entry, so `/system/product/…` is the module-internal payload path for a `/product`
  file — not the on-device `/system` partition.
* Rationale/trade-off: keeping stale oat is the classic source of "replaced system app crashes
  or misbehaves" reports (ART may reject the artifacts and fall back to JIT); removing it costs
  a one-off recompile (first camera start slower, background dex2oat) and is the safer choice
  for a *replaced* APK. This is the only "destructive-looking" part and it only affects the
  module's mount layer, never the real partition.

### 4.3 Data hygiene (`service.sh`, late_start service)

After the APK swap the camera app would still see app data written by the global build, so the
module runs **once per CN camera version**:

1. waits for `sys.boot_completed` (max 120 s),
2. verifies the replacement is actually active — on-device APK size
   `= 200627029` and `dumpsys package com.android.camera` versionName `= 6.7.000280.0`,
3. `am force-stop com.android.camera`, `pm clear com.android.camera` (logs the result), then
   force-stops again,
4. writes the guard file `/data/adb/leica_moment/.camera_cleared_6.7.000280.0`.

If the size/version check fails (module not mounted, mi_ext/overlay shadowing, OTA changed the
camera), it logs a warning and **does not** touch camera data. `CLEAR_CAMERA_DATA=0` disables
this entirely. mediaeditor/gallery data is never cleared (that would reset the CTA state the
cloud feature depends on).

### 4.4 What it does NOT do

* No Xposed/Zygisk hooks, no APK patching/re-signing, no CN gallery/editor replacement
  (the global APKs already contain the code — see §2).
* No server/entitlement bypass, no spoofing of device model/cert/attestation, no account tricks.
* No `/odm` or `/mi_ext` modification (Magisk cannot magic-mount them anyway).


### 4.5 Diagnostics (Magisk Action button)

Both variants ship `action.sh` (Action button entry point) and `diag.sh` (collector). Magisk
shows an **Action** button on the module card in the Modules tab; tapping it appends a
snapshot to `/data/adb/leica_moment/diag.log` and prints the tail in the console. The same
snapshot can be produced from a shell:

```sh
adb shell su -c 'sh /data/adb/modules/nezha_leica_moment/diag.sh'
adb pull /data/adb/leica_moment/diag.log
```

The snapshot contains: date, module id/version, ROM incremental + region, `ro.product.device` /
`ro.product.mod_device`, the Leica/region props (`ro.theme_customize`, `ro.theme_leica`,
`ro.boot.product.theme_customize`, `ro.miui.build.region`, `ro.special_edition`,
`camera.debug.safe.check.disable`), the `config.env` values, module camera payload
presence/size, on-device `/product/priv-app/MiuiCamera/MiuiCamera.apk` and `oat` type/size,
`versionName`/`versionCode`/`codePath` for `com.android.camera` and `com.miui.mediaeditor`, the
last 40 lines of `module.log`, and ready-to-paste logcat/mount/`uninstall-system-updates`
follow-up commands. It is read-only apart from appending `diag.log`, takes well under 5 s and
uses only `/system/bin/sh` + stock Android commands (no Magisk installer functions).

---

## 5. Requirements

* Xiaomi 17 Ultra (`nezha`), global HyperOS 4 ROM `OS4.0.0.8.XPAMIXM` (analysis baseline).
  Other builds / CN ROM / future OTAs are untested; the camera payload is a CN-ROM APK.
* Unlocked bootloader + **Magisk** (module installer requires Magisk v20.4+; a current Magisk
  release is recommended). KernelSU/APatch are **untested** (the REMOVE/dummy-device and
  props semantics are Magisk-specific).
* Space: the Full zip is ~118 MiB (~124 MB) compressed; installed payload ~192 MB in
  `/data/adb/modules/nezha_leica_moment/` (PropsOnly is ~10 KB).
* A way to disable modules if something goes wrong (see §8), and a Xiaomi account for the
  cloud feature (server-side).

---

## 6. Install

1. Copy the chosen zip to the phone.
2. Magisk app → **Modules** → **Install from storage** → pick the zip → reboot.
   (Recovery flashing also works; `META-INF/com/google/android/update-binary` is the official
   Magisk `module_installer.sh`.) If the camera app has been updated from GetApps/Play, the
   `/data/app` update takes precedence over the mounted system APK — remove the update once
   and reboot: `su -c 'cmd package uninstall-system-updates com.android.camera'`.
3. First boot: post-fs-data applies the props; on the Full variant `service.sh` waits for boot
   completed, verifies the APK, and clears camera data once (the camera may be killed).
4. Verify (root shell):

```sh
su
getprop ro.theme_customize                 # LCC
getprop ro.theme_leica                     # true   (if LEICA_SKU_PROPS=1)
getprop ro.miui.build.region               # cn     (if REGION_SPOOF=1)
getprop camera.debug.safe.check.disable    # true   (Full variant only)
stat -c '%s' /product/priv-app/MiuiCamera/MiuiCamera.apk   # Full: 200627029
stat -c '%F' /product/priv-app/MiuiCamera/oat              # Full: character special file
dumpsys package com.android.camera | grep -m1 versionName  # Full: 6.7.000280.0
cat /data/adb/leica_moment/module.log
```

5. Open the Gallery → edit a photo → look for the Leica Moment / 二次增强 entry. Accept the
   CTA/privacy prompt if shown, and be logged into a Xiaomi account. Watch logcat while
   triggering the cloud job:

```sh
adb logcat | grep -Ei 'LegendCloudManager|legendary|mediaeditor|hardwareAuthToken'
```

### 6.1 Troubleshooting checklist

| Symptom | Check / fix |
|---|---|
| Props not applied | `getprop ro.theme_customize` / `ro.miui.build.region`; `cat /data/adb/leica_moment/module.log` (post-fs-data logs every `set` and failure). Reboot after editing `config.env`. |
| Full variant: camera still the old version | `stat -c '%s' /product/priv-app/MiuiCamera/MiuiCamera.apk` must be `200627029`; if not, the module is disabled/not mounted, or a `/data/app` camera update is active → `cmd package uninstall-system-updates com.android.camera` + reboot. `service.sh` logs `on device : version=… codePath=…` and a warning in this case. |
| Camera crashes / behaves oddly | Remove the module and reboot (`/data/adb/modules/nezha_leica_moment` or app toggle); the stock camera returns. Try `LEICA_SKU_PROPS=0` first if it is prop-related. |
| Editor CTA (徕卡一瞬 / 二次增强) not visible | All three conditions must hold: device `nezha` (yes), `ro.theme_customize=LCC`, `ro.miui.build.region=cn`; force-stop Gallery/plugin/mediaeditor or reboot so the provider process re-reads props; check you are in a photo-edit entry that calls `method_request_function_list_with_cta`. |
| CTA visible but cloud job fails / queues forever / 4xx | Expected residual risk — server-side entitlement/`hardwareAuthToken`/account/CTA/CloudConfig. Check logcat for `LegendCloudManager`; there is no client-side fix. |
| Artifacts / slow first camera start (Full) | Expected: `oat` is hidden and ART recompiles after the APK swap; subsequent starts are normal. |
| MIUI overlay shadowing | `stat -c '%F' /product/priv-app/MiuiCamera/oat` should be `character special file`; `mount | grep -E 'mi_ext|overlay'`. |
| Need a snapshot for a bug report | Tap the module's **Action** button in the Magisk app, or run `diag.sh` (see §4.5), then share `/data/adb/leica_moment/diag.log`. |

---

## 7. Configuration — `/data/adb/leica_moment/config.env`

Created with defaults on first boot; edit it and **reboot** (post-fs-data reads it once per
boot). Missing lines fall back to the default.

```sh
# 1 = spoof ro.miui.build.region=cn; 0 = leave the ROM region untouched
REGION_SPOOF=1

# 1 = set ro.theme_customize=LCC + ro.theme_leica=true + ro.boot.product.theme_customize=P1_Leica
LEICA_SKU_PROPS=1

# 1 = one-time `pm clear com.android.camera` after the camera APK swap (Full variant only)
CLEAR_CAMERA_DATA=1
```

> **Region-spoof warning (default ON).** `REGION_SPOOF=1` changes
> `ro.miui.build.region` from `global` to `cn` **for the whole ROM** — every app and framework
> component that reads this property sees a China-region device. Possible consequences:
> OTA/update channel and eligibility behaviour, region-locked or region-dependent features in
> MIUI app store/theme/cloud services, ads/telemetry routing, some apps that enable/disable
> features by region. This is *required* for the editor CTA predicate, but it is the riskiest
> default in the module. Set `REGION_SPOOF=0` + reboot to restore the stock behaviour (the
> editor CTA will then not appear; the camera props can stay enabled).
> Only `ro.miui.build.region` is changed — not `ro.miui.region`, not
> `ro.miui.customized.region`, not the device model/region market name.

If the camera misbehaves with the SKU props (e.g. an unexpected SKU-dependent path on
non-Leica hardware), first try `LEICA_SKU_PROPS=0` + reboot before uninstalling.

---

## 8. Uninstall, disable, bootloop recovery

**Uninstall / revert (props + APK revert automatically):**

1. Magisk app → Modules → `Leica Moment Port (nezha)` → remove → reboot, **or**
   `su -c 'touch /data/adb/modules/nezha_leica_moment/remove'` and reboot.
2. After reboot the real `/product` camera APK, its oat/vdex and all stock props are back
   (the module only ever changed the mount layer and runtime props).
3. Optional cleanup: `su -c 'pm clear com.android.camera'` (remove CN-camera app data so the
   global camera starts clean) and `rm -rf /data/adb/leica_moment` if it was left behind.

**Disable without uninstalling:** Magisk app toggle, or
`su -c 'touch /data/adb/modules/nezha_leica_moment/disable'` → reboot. The module is not
mounted and no props are applied; camera data is kept.

**Bootloop / boot problems.** The module does not modify any real partition, so a true bootloop
is unlikely (camera-only crashes are more likely and only affect the camera app), but keep these
escape hatches: Magisk **Safe Mode** (hold the device's safe-mode key/Volume Down while booting —
Magisk then disables all modules for that boot; check current Magisk docs for your device), or
boot TWRP/recovery and delete `/data/adb/modules/nezha_leica_moment` (or create a file named
`disable` inside it), or use `adb shell magisk --remove-modules` if adb and root are available.
If you cannot get a shell/recovery, re-flash the stock boot image / Magisk-patched boot of your
ROM to recover (data is not touched by this module).

---

## 9. Risks

| Risk | Level | Notes / mitigation |
|---|---|---|
| Region spoof side effects (`ro.miui.build.region=cn`) | Medium–High | Whole-ROM region change; OTA/region features/apps/theme/cloud behaviour may change. `REGION_SPOOF=0` to disable. |
| Cloud job refused server-side (entitlement, quota, `hardwareAuthToken`, CN account, CTA) | High | Unfixable client-side; the CTA may show but the job may fail. Not bypassed by this module. |
| Capture UI only partially available (runtime `legend_mode` SDK / server gating) | Medium | CN APK resources are shipped, SDK downloads are not. |
| Camera APK replacement side effects | Medium | One-time data clear (settings/history lost), CN-localised UI/telemetry, 3 CN-only permissions, version differs from global. Remove module to revert. |
| Stale-oat removal / ART recompile | Low–Medium | First camera start slower; background dex2oat. Remove module to revert to stock oat. |
| MIUI `/mi_ext` overlay shadowing the `/product` payload | Low | Verified absent in the OS4.0.0.8 image dump; check `stat` output in §6. |
| OTA / future ROM updates | Medium | OTA may replace camera/editor; module keeps overriding with the older CN camera APK. Re-evaluate/disable before OTA; no OTA guarantee of any kind. |
| Play Integrity / attestation | Low by design | Module sets no model/cert/attestation props; Magisk itself remains the usual factor. |
| Data/privacy | Medium | CN camera APK may contact CN services; cloud feature requires a Xiaomi account + CTA acceptance. |
| Brick/bootloop | Low | No partition writes; recovery paths in §8. |

**No warranty. This is an experimental research build; you are responsible for your device,
your account and your data.**

---

## 10. Repository layout

```
work/leica/module/
├── README.md            <- this file
├── BUILD_INFO.md        <- hashes, file lists, build commands, validation output
├── build.sh             <- rebuilds both variants (assemble src/ -> validate -> dist/)
├── smoke_test.sh        <- offline script-logic tests (stubbed environment, no device needed)
├── common/              <- source of truth for the shared module files
│   ├── module.prop.tmpl customize.sh post-fs-data.sh service.sh uninstall.sh
│   ├── action.sh diag.sh README.md
├── src/PropsOnly/       <- complete Magisk module root (generated)
├── src/Full/            <- complete Magisk module root incl. the 192 MB CN APK (generated)
└── dist/                <- flashable zips + SHA256SUMS.txt
```

Rebuild: `cd work/leica/module && ./build.sh` (`all` | `propsonly` | `full`). It pins the CN
APK sha256, copies the official `update-binary`/`updater-script` from
`work/leica/module_skel/`, and runs `work/leica/scripts/build_module.sh` which validates each
zip with `work/leica/scripts/check_module.py`. `./smoke_test.sh` executes the real boot scripts
against stubbed Android commands and asserts the control flow (props, toggles, REMOVE, one-time
`pm clear`, guard file, app-store-update warning).

## 11. Technical references

* Magisk developer guides (module layout, `REMOVE`/`REPLACE`, boot scripts, `setprop` deadlock):
  <https://topjohnwu.github.io/Magisk/guides.html>
* Magisk tools (`resetprop -n` = bypass property_service):
  <https://topjohnwu.github.io/Magisk/tools.html>
* Magisk `SECONDARY_READ_ONLY_PARTITIONS` (`/vendor`, `/product`, `/system_ext`):
  <https://github.com/topjohnwu/Magisk/blob/master/native/src/core/module.rs>
* Magisk official `module_installer.sh` (`REMOVE` → `mknod $MODPATH$TARGET c 0 0`):
  <https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh>
