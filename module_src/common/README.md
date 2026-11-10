# Leica Moment Port (nezha) -- module README

This file is inside the flashable zip. Magisk deletes `README.md` from the installed
module directory after installation, so keep a copy of the zip if you need it later.

Full documentation, evidence, risks and troubleshooting: the `README.md` shipped next
to the built zips (`work/leica/module/README.md` in the research workspace).

## Quick facts

* Module id: `nezha_leica_moment`
* Variants (mutually exclusive, same module id -- flash one):
  * `..._PropsOnly.zip` -- properties only, no APK payload. Smaller/safer.
  * `..._Full.zip` -- properties + CN `MiuiCamera.apk` (6.7.000280.0) replacing
    `/product/priv-app/MiuiCamera/MiuiCamera.apk`, stale ART oat/vdex hidden.
* Runtime config: `/data/adb/leica_moment/config.env` (created on first boot)
  * `REGION_SPOOF=1` -- spoof `ro.miui.build.region=cn` (needed by the editor CTA;
    changes ROM region behaviour, see the main README)
  * `LEICA_SKU_PROPS=1` -- set `ro.theme_customize=LCC`, `ro.theme_leica=true`,
    `ro.boot.product.theme_customize=P1_Leica`
  * `CLEAR_CAMERA_DATA=1` -- one-time `pm clear com.android.camera` after the APK swap
* Log: `/data/adb/leica_moment/module.log`
* Diagnostics: tap the module's **Action** button in the Magisk app (runs `action.sh`), or
  `adb shell su -c 'sh /data/adb/modules/nezha_leica_moment/diag.sh'`; the snapshot is appended
  to `/data/adb/leica_moment/diag.log` and printed to the console.
* Uninstall: remove the module in the Magisk app and reboot. Properties and the camera
  APK revert automatically. Camera app data cleared once is not restored.

## Tested environment

No on-device test was possible for this build (no device attached). The module was
built and structurally validated (official Magisk module rules) against:

* global ROM: OS4.0.0.8.XPAMIXM for Xiaomi 17 Ultra (`nezha`), Android 17
* CN ROM source APK: MiuiCamera 6.7.000280.0 (OS4.0.5.0.XPACNXM)

Flash at your own risk; keep a way to disable Magisk modules (Magisk safe mode or
`adb shell magisk --remove-modules`) before flashing.
