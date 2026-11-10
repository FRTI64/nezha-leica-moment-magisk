# Global ROM analysis — 徕卡一瞬 (Leica Moment) / 二次增强 cloud feature
**Scope:** global `OS4.0.0.8.XPAMIXM` (nezha_global, 2512BPNDAG) vs CN `OS4.0.5.0.XPACNXM` (nezha, 2512BPNDAC/25128PNA1C)
**Author:** global-analyst (task-4). **Status:** final. Evidence files live under `work/leica/global/analysis/`; extracted ROM configs under `work/leica/global/configs/`.

---

## 0. TL;DR verdict

| Question | Answer |
|---|---|
| Does global ROM contain the Leica Moment code? | **Yes, nearly all of it.** Global `com.miui.mediaeditor` 2.10.40.4.8-global ships the complete Legendary / cloud re-render stack (`LegendaryActivity`, `LegendaryViewModel`, `LegendaryJobManager`, `aigc.cloud.internal.legend.LegendCloudManager`, `EdgeCloudLegendAlgorithm`, `MonopanJni`/`MonopanSdkLoader`, `LegendModeSdkLoader`) and identical Chinese UI resources. Global `com.android.camera` 6.6.000570.5 ships `LegendaryModule`/`LegendaryEnter`/`LegendarySelectedActivity` + base `legendary_m3`/`legendary_m9` resources. Global `com.miui.gallery` Flutter assets contain the same `一瞬`/`徕卡` strings and identical `app_tools.json`/`app_functions_v2.xml`. |
| What does global lack? | **(1) Capture-side Leica-Edition UI/resources** that only exist in CN camera 6.7.000280.0 (`legend_leica`, `legend_ccd/cmos/bw`, 35 mm/75 mm lens modes, M3/M9/M10R Leica templates, watermarks). **(2) The gating state**: `ro.miui.build.region=global` (CN build has `cn`) and `ro.theme_customize=LCC`/`ro.theme_leica=true` which on both ROMs are *not* in any build.prop — they come from `/odm/etc/nezha_5.x.prop` Leica-SKU overrides selected by init (`ro.boot.product.hardware_sku`/`ro.boot.hwversion`). **(3) Xiaomi-account/region cloud entitlement** (server-side; cannot be shipped). |
| Is the editor 二次增强 client entry gated? | **Yes, by an exact, runtime-read predicate**: `Build.DEVICE=="nezha" && SystemProperties.get("ro.theme_customize","")=="LCC" && SystemProperties.get("ro.miui.build.region","cn").equals("cn")` — see §4. It reads props dynamically per call, so a Magisk `resetprop` can flip it. |
| Can CN APKs replace global ones? | **Signature-compatible.** CN and global counterparts are signed by the *same* Xiaomi cert (sha256 `c9009d01ebf9f5d0…`, subject `CN=MIUI,O=Xiaomi`) in every pair checked → no signature mismatch for system-app replacement. |
| Cloud half feasible offline? | **No.** Even with client gates flipped, the create-task request carries `Build.DEVICE` + `isLCC` + Xiaomi account, is authenticated with a device-attestation `hardwareAuthToken` from `api.open.ai.xiaomi.com`, and quota/points are returned by the server (`deductType`/`points`). Expect server-side refusal for non-CN account/SKU; local refine SDKs are cloud-downloaded. |

---

## 1. Method / tooling

Pure-python (no androguard) tool-chain written for this task (`analysis/scripts/`):

* `apkinfo.py` — binary AndroidManifest (AXML) parser + APK Signing Block v2/v3 certificate extractor (falls back to PKCS#7 v1 `META-INF/*.RSA` via openssl). Output `analysis/info/{global,cn}/<apk>.info.txt`.
* `dexscan.py` — dex parser → class descriptors + *defined* method names + full string pool. Output `analysis/strings/{global,cn}/<apk>.{classes.tsv,strings.txt,matches.txt,meta.txt}`.
* `dexref.py` — const-string xref: reports `<dex> <class> <method> <string>` for every string literal referenced in code (this is how the gating classes were found).
* `extract_configs.sh`, `extract_listings.sh` — `dump.erofs --cat/--ls` on the global EROFS images and on the CN raw `super` (CN raw was later removed by Lead; preserved CN copies read from `work/leica/cn/configs/`).
* Targeted `baksmali --classes <descriptor,...>` for smali evidence (files kept in `analysis/smali_evidence/`).
* jadx/apktool were avoided for the 200 MB+ APKs; `baksmali --classes` disassembles a single class in <1 s.

Inputs: global APKs from `work/leica/global/apps/` (17 APKs), CN APKs from `work/leica/cn/{apps,apps2,data_apps}/`, partition images `work/dump/{system,product,system_ext,mi_ext,odm,vendor}.img`, CN config copies `work/leica/cn/configs/`.

---

## 2. Version + signer table (CN vs global counterparts)

Signer = SHA-256 of the DER signing certificate (v2/v3 block; v1 identical).
`c9009d01…` = Xiaomi "MIUI" platform cert; `d45f076f…` = second Xiaomi cert (AI apps); `3d7a12…`/`b7971c…` = Google/AICore.

| App (package) | CN version (vc) | Global version (vc) | Signer (both ROMs) |
|---|---|---|---|
| MiuiCamera `com.android.camera` | 6.7.000280.0 (670002800) | 6.6.000570.5 (660005705) | c9009d01ebf9f5d0… |
| MiMediaEditor `com.miui.mediaeditor` | 2.10.43.0.6 (210994306) | 2.10.40.4.8-global (210994048) | c9009d01… |
| MIUIGallery `com.miui.gallery` | 5.4.2.26-1008-cn (5040226) | 5.4.2.10-0907-global (5040210) | c9009d01… |
| HyperGalleryPlugin `com.hyper.gallery.plugin` | 5.4.2.6 (5040206) | 5.4.2.4-global (5040204) | d45f076fe23a1a5b… |
| MiuiExtraPhoto `com.miui.extraphoto` | 2.2.1.0.1 (202010001) | 2.2.1.0.1-global (202010001) | c9009d01… |
| CameraMind `com.xiaomi.cameramind` | 1.0.0 (1) | 1.0.0 (1) | c9009d01… |
| CameraTools_beta `com.xiaomi.cameratools` | 26.06.22.17.0 | identical file (same sha) | c9009d01… |
| MIUIAICR `com.xiaomi.aicr` | 4.12.26 (2030041226) | 4.12.19 (2030041219) | c9009d01… |
| AIService `com.xiaomi.aiservice` | 4.2.12_…_cn (402012) | 4.2.10_…_exp (402010) | d45f076fe23a1a5b… |
| AiasstVision `com.xiaomi.aiasst.vision` | 5.14.3.40 (540140340) | 5.12.10.60 (540121060) | c9009d01… |
| MIUICloudService `com.miui.cloudservice` | 1.12.0.10.25 | 1.12.0.10.22-global | c9009d01… |
| MIUIMiCloudSync `com.miui.micloudsync` | 1.12.0.2.00 | same (112000200) | c9009d01… |
| MiuixEditor `com.miuix.editor` | 37 / "17" | same | c9009d01… |
| RtMiCloudSDK `com.xiaomi.micloud.sdk` | 2.0.0.0 | same (byte-identical APK) | c9009d01… |

CN-only system apps (no global counterpart): `com.miui.contentextension` (MIUIContentExtension 5.1.5), `com.xiaomi.aiasst.service` (MIUIAiasstService 6.2.2), `com.miui.mediaviewer` (MediaViewer 2104260901; global counterpart is `MediaViewerGlobal` in /product/app), `com.mfashiongallery.emag` (MIGalleryLockscreen).
Global-only: Google Photos/GMS stack, `Photos.apk`, `MIUICloudBackupGlobal`, `AiAsstVision.apk` (global naming of AiasstVision), `AiCore` (stub).

---

## 3. Code / resource presence: CN vs global

### 3.1 `com.miui.mediaeditor` (the cloud 二次增强 client)
`analysis/strings/*/…matches.txt`, `analysis/delta/mediaeditor_*`.

| Evidence | CN 2.10.43 | Global 2.10.40 |
|---|---|---|
| `com.miui.mediaeditor.legendary.*` (LegendaryActivity/ViewModel/ForegroundService/JobManager/tasks/meta/process) | present | present |
| `aigc.cloud.internal.legend.LegendCloudManager` + api entities (CloudLegendUploadParam, CloudLegendV2Param, CreateLegendV2TaskParams, Query/Retry…, TaskStatus) | present | present |
| `aigc.cloud.legend.{EdgeCloudLegendAlgorithm,EdgeCloudLegendV2Algorithm,LegendCloudConfig,CloudLegendM9Processor,CloudLegendV2Processor}` | present | present |
| `algo.monopan.{MonopanAlgorithm,MonopanJni,MonopanSdkLoader,MonopanApiManager}` | present | present |
| `legendary.algorithm.LegendModeSdkLoader`, `LegendaryVersionResolver`, `LegendaryJobManager` | present | present |
| Endpoints `https://api.open.ai.xiaomi.com`, paths `/aiPhotoCloud/api/legend/create|getResult`, `/aiPhotoCloud/api/legendV2/create|getResult|list` | present | present |
| Keys `leica_support_devices`, `lcc_support_devices`, `mist_support_devices`, module `mediaeditor_filter_config_v2` | present | present |
| `resources.arsc` Chinese feature strings 一瞬×21, 二次增强×1, 云端×5, 徕卡×7 | 21/1/5/7 | **21/1/5/7 (identical)** |
| Obfuscated package renaming (`Ltp0/*` vs `Lct0/*`, `Lcc0/*` variants) | — | differs (same code, different R8 mapping) |
| `com.miui.camerainfra.cloudconfig.push.cn.MiPushInitializer` (+receiver) | present | **absent** — global uses `…push.global.FcmPushInitializer`/`GlobalPushInitializer` (both referenced in global `Lvg/e.register`) |

Filtered class delta (legend|leica|monopan|aigc|moment|camerainfra|cloudconfig): CN 666 / global 662 classes, **0 Leica/Legend classes missing in global**; only CN push infra + 3 obfuscated duplicates differ.

### 3.2 `com.android.camera`
String-level delta saved: `analysis/delta/camera_cn_only_strings.txt` (87 strings; 85 legend/leica-related) vs `camera_gl_only_strings.txt` (43, obfuscation helper classes).

* Global camera **defines** `features.mode.legendary.LegendaryModule`, `LegendaryEnter`, `legend.activity.LegendarySelectedActivity` (+`$a`); CN camera defines only `LegendaryModule`/`LegendaryEnter` and **references** `com.android.camera.legend.fragment.{FragmentLegendaryIntroduction,FragmentLegendarySelected,LegendarySelectedAdapter}` which are **not defined in any CN APK we have** → strongly suggests those UI classes come from the downloadable "legend_mode" SDK/plugin (see §6).
* Global camera has base resources: `legendary_m3`×1, `legendary_m9`×1, `legendary_leica`×1, `custom_shutter_legendary`×1 (both dex + arsc).
* CN camera 6.7 adds (dex only, absent in global): `isLeicaCustomize`, `isLeicaMode`, `legend_leica`, `legend_ccd`, `legend_cmos`, `legend_bw`, aliases + `legend_pickers_*`, `legend_35mm`/`legend_75mm` (`legend_35_split_mm`, `legend_75_split_mm`, `legend_camera_selection`), `legendary_summicron_35mm`, `legendary_summilux_75mm`, `legendary_leica_m3/m9/m10r_{icon,template,text_icon,logo}`, `legendary_m3/m9/m10r_leica`, `legendary_bokeh_on/off`, `legendary_mode_upgrade_*_intro`, `legendary_portrait_bokeh_35mm/75mm_intro`, `legendary_user_guide`, `newbie_guide_dialog_message_legendary`, `portrait_cv_type_popup_leica[_cn]`, `com.xiaomi.legendMode.capsInfo`, `getLegendBokehCapsInfo:*` (apertureListMax/legendFocalLength/EquivalentFocalLength/zoomStart/End, legend 35 mm & 75 mm bokeh caps).
* `resources.arsc` delta (decisive for "strictly CN APK"): CN camera arsc has `legendary_summicron_35mm`×1, `legendary_summilux_75mm`×1, `legendary_m3_leica`×1, `legendary_m9_leica`×1, `legendary_m10r_leica`×1; global camera arsc has **0** of these → the Leica-Edition capture UI assets are *not* in the global APK.

### 3.3 `com.miui.gallery` (Flutter; no dex at all — code in `lib/arm64-v8a/libapp*.so` + `resources.arsc`) and `com.hyper.gallery.plugin`
* `assets/app_tools.json` and `assets/app_functions_v2.xml` are **byte-identical** CN vs global (both contain `一瞬` and `徕卡`, and the doc text `photo_essential(传奇模式/徕卡一瞬)`).
* Flutter AOT strings (UTF-16LE) in `libapp.so`: `一瞬`×4, `云端`×31, `徕卡`×1 in **both** ROMs; `libapp_gallery.so`: `legend`×7, `moment`×7 in both.
* Plugin resources: global has *more* `moment` hits (9 vs 5) and `leica` 5 vs 4; CN-only plugin strings: `PHOTO_LEICA_STYLE_NATURAL`, `PHOTO_LEICA_STYLE_NATURAL_PORTRAIT`.

---

## 4. EXACT gating predicates (global mediaeditor 2.10.40.4.8-global)

### 4.1 Where the gallery asks "is 徕卡一瞬 / 二次增强 available?"
`MediaEditorProviderForGallery.call(method, …)` (`Lcom/miui/mediaeditor/provider/MediaEditorProviderForGallery;`). It dispatches on method name; the aggregate reply is `method_request_function_list_with_cta` (protected by `sparse-switch`). Decoded logic (analyse evidence: `analysis/smali_evidence/provider/`):

```
method_is_legend_available(徕卡一瞬 / LCC)         = Lmx/a.g() && Lr21/e.b()
method_is_xm_legend_available(传奇一瞬 / XM legend) = Lbx/t.a()
```
* `Lmx/a$i.b()` (decode of the `Lxz/b.a` string obfuscation, XOR key 0x02C5):
```
Build.DEVICE == "nezha"
&& SystemProperties.get("ro.theme_customize", "").equals("LCC")
```
* `Lr21/e.b()`:
```
SystemProperties.get("ro.miui.build.region","cn").equalsIgnoreCase("cn")
```
* `Lbx/t.a()`:
```
Build.DEVICE in {"madrid","hongkong","nezha"}
&& !Lmx/a.g()          // NOT (nezha && theme_customize==LCC)
&& Lr21/e.b()          // region == "cn"
```
* Related helper `Lbx/j.a()`: `Build.DEVICE in {"lhasa","madrid","venice","hongkong"} && !Lr21/c.b`, where `Lr21/c.b` = `SystemProperties.get("ro.product.mod_device","").contains("_global")` (cached in `<clinit>`; for our global ROM `nezha_global` → true).

**CN 2.10.43 has semantically identical gates** (different R8 names):
`method_is_legend_available = Lrt/a.g() && Lah0/b.g()` where `Lrt/a$j.b()` = same `"nezha" && ro.theme_customize=="LCC"` check and `Lah0/b.g()` = `ro.miui.build.region == "cn"`; `method_is_xm_legend_available = Lft/s.a()` = same `{madrid,hongkong,nezha} && !LCC && region cn` (`analysis/smali_evidence/avail_cn/`).

### 4.2 Region prop caching — **runtime read (Magisk-friendly)**
* `Lr21/e.b()` calls `SystemProperties.get` on every invocation (no static final cache) — `analysis/smali_evidence/legend_config/r21/e.smali`.
* `Build.DEVICE` is read at call time (static field of `android.os.Build`).
* `Lr21/c.b` (mod_device contains `_global`) *is* cached in `<clinit>`.
* In the camera APK, theme props are read once per process in `<clinit>` (`Lcb/c` static fields `t`=`ro.theme_customize`, `u`=`ro.boot.product.theme_customize`, `v`=`ro.product.mod_device`, plus `camera.debug.theme_customize.disabled`) → **props must be set before the camera process starts** (post-fs-data/resetprop + force-stop camera). Same pattern CN (`LVa/b`) vs global (`Lcb/c`) — see `analysis/smali_evidence/ag_c$a.smali`,`cb/c.smali`,`e9/h.smali`.

### 4.3 Cloud job-time gating (second pass, not just CTA)
`Lcom/miui/mediaeditor/aigc/cloud/internal/legend/LegendCloudManager;.b(…)` builds the create-task request (`analysis/smali_evidence/legend_cloud/LegendCloudManager.smali` ~line 2600):
```
new CreateLegendV2TaskParams(
    imgUrl,
    <user/account id from Ljq/f.b(context)>,
    Build.DEVICE,                 // "nezha"
    Lmx/a.g(),                    // isLCC boolean  ← same theme_customize=="LCC" check
    aperture, focusX, focusY, …)
```
`CreateLegendV2TaskParams` / `CloudLegendV2Param` JSON adapters carry fields incl. `oaid`, `imgUrl`, `aperture`, `focusX/focusY`, `device`, LCC flag; results carry `deductType`, `points`, `counts`, `legendaryVersion`, `serverId`, `taskId`, `status` (`TaskStatus`), `errorCode` — i.e. **metering/entitlement is server-side**. 401 cookie refresh retry ("cookie 鉴权失败(401)，刷新 cookie 重试") is implemented; cookies come from Xiaomi account.
Two additional hard prerequisites observed in code strings/classes:
1. **CTA** (privacy agreement): `Lid0/a` `CloudConfig.initialize` — "CTA not permitted yet, CloudConfig init deferred"; `Lhz/t.k0` "checkXmLegendCloudEntryIfNeeded: CTA agreed, check login" / "CTA not allowed"; `legendary/c` "CTA agreement already showing, skip".
2. **Cloud feature config (camerainfra CloudConfig)**: `Lkf/c` (getter `f(moduleKey, type, force)`), SQLite `cloudConfigCache` DB, requests via `Lnf/h`, push channel registration `Lvg/e.register` (MiPush CN / FCM Global), conditions (`Condition`) per rule. Module keys seen: `mediaeditor_filter_config_v2`; device allowlists parsed from JSON keys `leica_support_devices`, `lcc_support_devices`, `mist_support_devices` inside `supportDeviceList` (`Lri0/g.a`), plus `unSupportDeviceList`/`supportBiz`. → these lists are **server-delivered**, not in the ROM.

### 4.4 Hardware auth for cloud calls
* Editor: `Lcom/miui/gallery/editor_common/hardwareauth/c;` `<clinit>` references `https://api.open.ai.xiaomi.com`.
* Gallery plugin: `Lcom/miui/gallery/net/hardwareauth/HardwareAuthTokenManager$GetAuthTokenRequest` → `https://api.open.ai.xiaomi.com/auth/v1/hardwareAuthToken`; `$GetNonceRequest` → `…/auth/v1/hardwareNonce`. `analysis/smali_evidence/` (dexref run, see `analysis/delta/xref_*.tsv`).
→ Cloud calls are bound to a hardware-attested device token; a mismatched ROM/region/SKU can be rejected server-side.

---

## 5. Props / config delta

### 5.1 Leica-Edition SKU props exist in BOTH ROMs' `/odm/etc` (byte-identical)
`/odm/etc/nezha_5.0.6.prop` (and similar `nezha_5.9.9.prop`):
```
ro.boot.product.theme_customize =P1_Leica
ro.theme_customize=LCC
ro.theme_leica=true
ro.special_edition=true
ro.product.odm.support_cai=true
ro.product.odm.marketname=Xiaomi 17 Ultra by Leica
ro.product.odm.model / cert / model_for_attestation = 25128PNA1C (5.0.6) / 2512BPNDAC (5.9.9)
```
Import chain (both ROMs' `odm/etc/build.prop`):
```
import /odm/etc/${ro.boot.product.hardware.sku}_${ro.boot.hwversion}.prop
import /odm/etc/${ro.boot.product.hardware.sku}_${ro.boot.ptcountrycode}_build.prop
```
Region variants `nezha_{eea,in,ru,tr}_build.prop` differ between ROMs **only in fingerprint strings** (`OS4.0.0.10.XPAMI` vs `OS4.0.4.1.XPACN`); all `nezha_5.x.prop` Leica files identical.
⇒ On a unit whose bootloader SKU/hwversion is not the Leica one, these props are never imported; on all units `ro.theme_customize` is absent from every flashable build.prop (verified: system/product/system_ext/vendor/odm/mi_ext all searched).
### 5.2 ROM build.prop deltas (global vs CN)
| key | global | CN |
|---|---|---|
| `ro.mi.os.version.incremental` | OS4.0.0.8.XPAMIXM | OS4.0.5.0.XPACNXM |
| `ro.miui.build.region` | **global** | **cn** |
| `ro.product.mod_device` | nezha_global | nezha |
| `ro.product.model_for_attestation` | 2512BPNDAG | 2512BPNDAC |
| `ro.mi.os.version.beta` | true | false |
### 5.3 /product/etc (identical) and /odm/etc/camera
* `/product/etc/device_features/nezha.xml` — **identical** (39581 bytes, byte-for-byte).
* `/product/etc/lut/lutForPrimeShaderCache.txt` — identical (129319 B); `/product/etc/aconfig/{flag.info,flag.map,flag.val,package.map}` — identical; `/product/etc/precust_theme/theme` = only `.data` placeholders in both; `pipeline_infos/` per-app shader caches present both.
* `/odm/etc/camera/` leica filter params: `leica_filter_param.bin`, `leica_filter_param_m3.bin`, `leica_filter_param_m9_preview.bin`, `leica_filter_param_m9_snapshot.bin`, `mialgo_monopan_cl.bin` — **present in BOTH** (`configs/listings/global_odm__etc_camera.txt` == CN).
* `/system_ext/etc` camera configs mostly identical; `camdfx_spec_config.json` differs (CN has extra error-code/stats lists — DX, not feature). `cust_prop_white_keys_list` identical and does **not** contain `ro.theme_*` keys.
* `/odm/etc/default_cloud.json` **differs**: global 441008 B vs CN 424016 B, content begins `encrypted_data: …` (base64-looking blob, not plain JSON) → region/cloud config, not decodable without key. Flag as risk/open item.
* `/product/app` inventory: no camera/gallery plugin APK delta beyond naming (`MediaViewerGlobal` vs `MediaViewer`, `MiuixEditor_global` vs `MiuixEditor`, `HyperGalleryPluginGlobal`); CN-only: MIUIContentExtension, MIUIAiasstService.

### 5.4 Native libs
* Camera APK `lib/arm64-v8a` delta: global has extra crashlytics/datastore libs; CN has `libperformance.so`; **no Leica-specific native libs in either**.
* Mediaeditor: **neither** APK ships `libmialgo_monopan.so`, `libmonopan_jni.so`, `liblegend_refine_jni.so`, `liblegendrefine.so` although dex references them at `/lib…` paths → they are delivered by the runtime-downloaded SDKs `algorithm_monopan` / `legend_mode` (strings: "start download algorithm_monopan", "start download legend_mode", "load so failed: legend_mode 尚未下载").

---

## 6. Minimal Magisk module payload

### (a) Camera capture-side 徕卡一瞬 (local look, free layer)
| # | Payload | Necessity / notes |
|---|---|---|
| 1 | `system.prop`/resetprop at post-fs-data: `ro.boot.product.theme_customize=P1_Leica`, `ro.theme_customize=LCC`, `ro.theme_leica=true`, `ro.special_edition=true`, `ro.product.odm.support_cai=true`, (`ro.product.odm.marketname=Xiaomi 17 Ultra by Leica`, matching model/cert), then force-stop+restart camera | Both cameras' settings classes read these props; camera caches them in `<clinit>` so props must exist before camera starts. |
| 2 | Replace `MiuiCamera.apk` with **CN 6.7.000280.0** (same signer `c9009d01…`) + its `oat`/vdex (or use module to mount only APK and delete stale oat) | **Required for the Leica-Edition capture UI** (`legend_ccd/cmos/bw`, 35 mm/75 mm, M3/M9/M10R Leica templates/watermarks): those resources exist **only** in CN camera `resources.arsc`; global 6.6 has only base `legendary_m3/m9`. |
| 3 | Check for `legend_mode` / camera legend SDK availability (downloads at runtime, server-gated) | CN camera references `com.android.camera.legend.fragment.*` classes not inside any CN APK → likely part of the runtime-downloaded `legend_mode` SDK; if server refuses, capture UI may not fully work even with CN APK. |
| 4 | Metadata: camera writes `LegendInfo`/`LegendMeta` (`LegendM9Container` in 3rd-party research) into JPEG; the editor looks for it (`LegendInfoResolver`, `LegendM9MetaParser`, `LegendMetaProto`) | Without legend metadata the gallery/editor 一瞬 entry is not offered for a photo. |

### (b) Editor cloud 二次增强
| # | Payload | Necessity / notes |
|---|---|---|
| 1 | resetprop `ro.miui.build.region=cn` **and** `ro.theme_customize=LCC` (device `nezha` already passes) — read dynamically by `MediaEditorProviderForGallery` → predicates become true; restart Gallery/Plugin/MediaEditor processes | Minimal client-side unlock for the entry. NOTE: `method_is_legend_available` for a non-LCC device (regular 17U) still needs the LCC prop; `method_is_xm_legend_available` (传奇一瞬) needs `!=LCC` + region cn. |
| 2 | Keep global `MIMediaEditorGlobal` (code complete) or optionally swap CN `MiMediaEditor 2.10.43` (same signer) for newest logic/CTA path | Optional; global 2.10.40 already contains endpoints/entities/CTA logic. |
| 3 | Xiaomi account logged in + CTA privacy agreement accepted + reachable `api.open.ai.xiaomi.com` | Enforced in code (CTA deferred CloudConfig init; login checks). |
| 4 | camerainfra CloudConfig modules/subscription + push channel (MiPush CN / FCM global) + runtime SDK downloads (`legend_mode`, `algorithm_monopan`) | Server-delivered; cannot be shipped. FCM push channel on global may or may not receive the CN rule set. |
| 5 | Server entitlement for account/device SKU (quota/points) | **Hard blocker** — request sends `Build.DEVICE`, LCC flag, Xiaomi account cookie, hardwareAuthToken; results include `deductType/points`. Cannot be forced client-side. |

### Risk register
| Risk | Evidence | Impact |
|---|---|---|
| Server-side entitlement/quota (points, deductType, per-photo) | `CreateLegendV2TaskParams`/`TaskStatus`/`RecentTasksDatabase` (`points`,`deductType`,`counts`), 401 cookie refresh | **High** — cloud half may return 4xx even with predicates true; offline test impossible. |
| Hardware attestation (`hardwareAuthToken`/`hardwareNonce`) bound to device/ROM | plugin `HardwareAuthTokenManager`, editor `editor_common/hardwareauth` | High — global build/region mismatch may be rejected. |
| Region prop side effects of `ro.miui.build.region=cn` | whole-system MIUI region behavior (OTA/GMS/theme/account services) | Medium/High — recommend testing; per-process spoof may be safer if apps read again per call. |
| Signature | all pairs same cert c9009d01… | Low for APK replacement (but re-signing CN APK/repack would break) |
| Framework deps of CN APKs | CN mediaeditor defines CN-only push classes (MiPushInitializer); global ROM may lack CN push SDK/miui-services classes | Medium — test CN APK swap on global; keep global APK as fallback. |
| Camera SDK/UI classes not in CN APK | `com.android.camera.legend.fragment.*` referenced but undefined in all CN APKs; runtime-downloaded SDK | Medium — capture UI may require network/server. |
| `default_cloud.json` encrypted, differs CN vs global | `/odm/etc/default_cloud.json` 441008 vs 424016 B, `encrypted_data:` blob | Medium — may carry region cloud switches; undecoded. |
| Global camera 6.6 vs CN 6.7 | version + resource delta (§3.2) | Medium — props alone insufficient for full Leica-Edition capture UI. |

---

## 7. Evidence index (workspace paths)

* `work/leica/global/analysis/info/{global,cn}/*.info.txt` — manifest package/versionCode/versionName + v1/v2/v3 signer cert (subject, serial, sha256).
* `work/leica/global/analysis/strings/{global,cn}/*.{classes.tsv,strings.txt,matches.txt,meta.txt}` — dex class/method/string inventory + Leica/cloud matches.
* `work/leica/global/analysis/delta/` — `lcc_predicate_decoded.txt` (decoded Lmx/a$i, Lr21/e, Lbx/t, Lbx/j predicates), `camera_cn_only_strings.txt` (87), `camera_gl_only_strings.txt`, `mediaeditor_cn_only_classes.txt`, `mediaeditor_gl_only_classes.txt`, `{camera,mediaeditor,plugin,extraphoto}_{cn,gl}_only_strings.txt`, `xref_gl_classes*.tsv` (const-string xrefs incl. gating strings).
* `work/leica/global/analysis/smali_evidence/` — decisive smali: provider (GL+CN), availability helpers (`avail_gl/`, `avail_cn/`), `legend_cloud/` (LegendCloudManager, EdgeCloudLegendAlgorithm, LegendCloudConfig), `legend_config/` (r21/c-e, eq0/l, hz/t, id0/a, ri0/g, rp/k, cache/CTA helpers), `legendary/`, camera `LegendaryModule/Enter/SelectedActivity` smali + `camera_theme/` (global `Lcb/c` settings prop cache, `Le9/h` watermark theme fallback, `Lag/c$a`).
* `work/leica/global/configs/` — `global/`, `cn/` extracted build.props (all partitions), `odm_etc/` Leica SKU prop files + `default_cloud.json`(both), `listings/` (`dump.erofs --ls` of /etc, /odm/etc, /etc/camera, /etc/permissions …), `device_features/`, `system_ext_etc/` camera configs, `gallery_assets/` (identical CN/global app_tools.json + app_functions_v2.xml), `global/product_etc2/` lut+aconfig.
* Web/pricing/platform prior art: `work/leica/docs/research_web.md` (Lead).

## 8. Open items / recommended next steps
1. Decode `/odm/etc/default_cloud.json` `encrypted_data` (key likely in a Xiaomi framework service/`me_config.xml`; or compare with CN `/data` cloudconfig DB after boot) — may reveal region cloud switches.
2. Runtime test on device: Magisk resetprop pair (§6b-1) + accept CTA + CN account, observe provider result and `LegendCloudManager` logcat / server error codes; decide whether 401/403/4xx means region lock.
3. Determine whether gallery Flutter UI actually calls `method_request_function_list_with_cta` (rather than individual `method_is_legend_available`) — trace with logcat / content-provider call log; both are present in global.
4. Verify CN camera `legend.fragment.*` origin (SDK download path/URL in camera dexref for `legend_mode` / plugin manager) before promising capture-side parity by APK swap alone.
