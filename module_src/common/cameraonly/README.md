# Leica Moment Port (nezha) — CameraOnly variant (NO property spoofing)

This file is inside the flashable zip. Magisk deletes `README.md` from the installed
module directory after installation; keep a copy of the zip if you need it later.

Full documentation, evidence, risks and troubleshooting: the `README.md` shipped next
to the built zips (`work/leica/module/README.md` in the research workspace).

## What this variant is

**No property faking.** This module changes exactly one thing: it magic-mounts the CN
`MiuiCamera.apk` (6.7.000280.0) over `/product/priv-app/MiuiCamera/MiuiCamera.apk` and hides
the stale ART oat/vdex of the old global APK so ART recompiles. It does **not** set, spoof or
modify any system property, at boot or at runtime. (`post-fs-data.sh` is a no-op that only
writes a boot line to the module log.)

Feature gating is intentionally left to the separate **LSPosed module** (direct method hooks,
no property changes). Without it the stock gating stays in force and the Leica UI/entry will
not appear.
- Camera capture-side Leica UI: needs the LSPosed camera hooks (research task, not yet final).
- Gallery editor 二次增强 entry: needs the LSPosed module (v2.0.0 no-props mode).
- If you only care about the *editor* feature and not the camera APK, you do **not** need any
  Magisk module at all — use only the LSPosed module.

## Quick facts

* Module id: `nezha_leica_moment` (same id as the deprecated props variants: flashing this
  replaces them, and vice versa — only one variant is installed at a time)
* Name: `Leica Moment Port (nezha) - CameraOnly`
* Version: `1.2.0-cameraonly`
* Contents: `system/product/priv-app/MiuiCamera/MiuiCamera.apk` + boot/install scripts only
* Runtime data/log dir: `/data/adb/leica_moment/`
* One-time data clear: after the APK swap, `service.sh` runs `am force-stop` +
  `pm clear com.android.camera` once (verified against the expected APK size/version, guard
  file `.../.camera_cleared_6.7.000280.0`); camera settings/history are lost once.
* Diagnostics: tap the module's **Action** button in the Magisk app (runs `action.sh`), or
  `adb shell su -c 'sh <module-dir>/diag.sh'`; the snapshot is appended to
  `/data/adb/leica_moment/diag.log` and printed to the console.
* Uninstall: remove the module in the Magisk app and reboot. The real partition was never
  modified, so the stock camera APK and its oat/vdex return automatically. Camera data cleared
  once is not restored.

## Tested environment

No on-device test was possible for this build (no device attached). The module was built and
structurally validated against the official Magisk module rules. ROM baselines:

* global ROM: OS4.0.0.8.XPAMIXM for Xiaomi 17 Ultra (`nezha`), Android 17
* CN ROM source APK: MiuiCamera 6.7.000280.0 (OS4.0.5.0.XPACNXM)

Flash at your own risk; keep a way to disable Magisk modules (Magisk safe mode or
`adb shell magisk --remove-modules`) before flashing.
