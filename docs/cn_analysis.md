# CN ROM 徕卡一瞬 (Leica Moment) — camera local + gallery/editor cloud second-pass ("二次增强")

Status: first-pass RE done; evidence below is from CN OS4.0.5.0.XPACNXM (nezha) only, all paths relative to `work/leica/`.
Decompiled artifacts: `cn/decomp/{editor_smali_d1,editor_smali_d2,editor_res,camera_smali_d1,camera_smali_d4,camera_res,hypergalleryplugin_res}`, raw dex: `cn/analysis/cam_dex/`, `cn/analysis/dex_miui_editor/`, dex string dumps: `cn/analysis/dexstrings/*.txt`.

## 0. Bottom line for module design

1. **The feature is split across 3 code bases** (all present in CN ROM; global ROM has same editor code):
   - Capture side: **CN MiuiCamera.apk 6.7.000280.0** (`com.android.camera`, versionCode 670002800) — `LegendaryModule`/`LegendaryEnter` mode id **0x100**, all CN-only Leica/legend resources. Global camera 6.6.000570.5 lacks them (global-analyst).
   - Cloud second pass ("二次增强"/cloud upscale+refine): **CN MiMediaEditor.apk 2.10.43.0.6** (`com.miui.mediaeditor`, versionCode 210994306) — class pkg `com.miui.mediaeditor.legendary.*` + `com.miui.mediaeditor.aigc.cloud.*`.
   - Gallery UI: **MIUIGallery.apk is now Flutter** (NO classes.dex; `lib/arm64-v8a/libapp.so` 22 MB Dart AOT + `libapp_gallery.so` 39 MB Rust/hyper). It references `com.miui.mediaeditor.legendary.Legacy...LegendaryActivity` and probes capability keys `is_legend_available` / `is_xm_legend_available`.
2. **Editor gating predicate CONFIRMED in CN smali** (no cloud config involved):
   - `method_is_legend_available` = `rt.a.g() && ah0.b.g()` → **`Build.DEVICE=="nezha"` && `SystemProperties.get("ro.theme_customize","")=="LCC"` && region `ro.miui.build.region` default `cn` equalsIgnoreCase `cn`**.
   - `method_is_xm_legend_available` (the Xiaomi-branded variant 传奇一瞬/Essential Moment) = `ft.s.a()` → **DEVICE ∈ {madrid,hongkong,nezha} && !(rt.a.g()) && region=="cn"**.
   → On a global ROM both are false unless **resetprop `ro.theme_customize=LCC` + `ro.miui.build.region=cn`** (device is already nezha). ODM SKU prop files with exactly these values are already in CN odm: `work/leica/cn/configs/odm_etc/nezha_5.9.9.prop` etc. (11 files: 5.0.6/5.0.8/5.1.6/5.1.8/5.2.5/5.2.7/5.9.7/5.9.9/5.11.6/5.12.6/5.19.9): `ro.boot.product.theme_customize =P1_Leica`, `ro.theme_customize=LCC`, `ro.theme_leica=true`, `ro.product.odm.marketname=Xiaomi 17 Ultra by Leica`, `ro.special_edition=true`.
3. Camera-side mode visibility uses the same theme props; the exact visibility consumer method is **NOT fully confirmed** (see §1 open items). `camera.support_legendary_mode=true` meta-data is in CN camera manifest.
4. **Photo→editor handoff is metadata driven, not prop driven.** The editor contains a legend metadata model `com.miui.mediaeditor.legendary.meta.LegendMetaProto$M9Msg` (protobuf: AISP_ISO/AWBGAIN/CCM/LSC/FACTOR/FACERECT/ALGOVERSION/… raw M9 pipeline data) used for cloud refine. The writer was NOT found in any extracted CN APK dex (see open items) — likely native/plugin side.

## 1. CN camera — 徕卡一瞬 mode (capture side)

APK: `cn/apps2/MiuiCamera.apk`, versionCode 670002800, versionName 6.7.000280.0, signer subject `C=CN,ST=Beijing,L=Beijing,O=Xiaomi,OU=MIUI,CN=MIUI,emailAddress=miui@xiaomi.com` (same release cert as all CN apps; independent of global APK signer check TBD).

- Manifest (`cn/decomp/camera_res/AndroidManifest.xml:151`):
  `<meta-data android:name="camera.support_legendary_mode" android:value="true"/>`
- Mode classes DEFINED in camera `classes.dex` (smali under `cn/decomp/camera_smali_d1/com/android/camera/features/mode/legendary/`):
  - `LegendaryEnter` extends `Lcom/android/camera/module/entry/BaseModuleEntry;` (142 lines): `getModuleId()` returns **0x100 (256)**; `getModeUI()` → `LU3/b`; `getModule()` → `LegendaryModule`; `getModuleDevice()` → `LF3/o`; `getModeItem()` uses `La7/i;->j0()/W0()/X0()` resource ids.
  - `LegendaryModule` (280 lines) + `LegendaryModule$a` (282 lines).
  - Other referenced-but-not-defined descriptors (only string refs in CN camera dex; not defined in any extracted CN APK): `com.android.camera.legend.fragment.FragmentLegendaryIntroduction`, `...FragmentLegendarySelected`, `...LegendarySelectedAdapter`, `...LegendaryModeUI`, `LegendaryModuleDevice`, `LegendaryNativeCaptureBridge`, `LegendaryProcessingProvider`, `LegendM9Container` → **open: dynamic/plugin dex or native** (see open items).
- Prop cache (CN camera settings class): **`cn/decomp/camera_smali_d4/Va/b.smali`** `<clinit>` (this is global-analyst's "LVa/b"):
  - `ro.boot.product.theme_customize` → static `LVa/b;->t`
  - `ro.theme_customize` → static `LVa/b;->u`
  - `ro.product.mod_device` → static `LVa/b;->v`
  - `camera.debug.theme_customize.disabled` → static `LVa/b;->w`
  - also `ro.miui.cust_variant`→`r`, `ro.product.odm.support_cai`→`x`, etc.
  A second reader: `cn/decomp/camera_smali_d4/W8/h.smali` (~line 491) reads `ro.theme_customize` with default `""` while building `LRg/s$a;` (theme config), and falls back when empty. `camera.debug.safe.check` usage was NOT located in baksmali'd dex1+dex4 (NOT DONE).
- CN-only resources (CN MiuiCamera resources.arsc; global camera lacks these per global-analyst):
  - dex strings: `legend_leica`, `legend_ccd`, `legend_cmos`, `legend_bw`, `legend_35mm`, `legend_75mm`, `legend_pickers_*`, `legend_bw_alias`, `legendary_{m3,m9,m10r}_leica(_state)`, `legendary_leica_m3/m9/m10r_{icon,template,text_icon}`, `legendary_summicron_35mm`, `legendary_summilux_75mm`, `legend_picker`, `legend_selector_leica_*`, `M3_monopan`, `com.xiaomi.sessionparams.legendMode`, `com.xiaomi.legendMode.capsInfo`, `getLegendBokehCapsInfo`, `module_name_xiaomi_legendary(_plan_b)`, `pref_legendary_mode_key`, `pref_legend_shutter_button_type_key`.
  - resources.arsc zh-rCN strings (camera resource names are obfuscated letters): `res/values-zh-rCN/strings.xml:592 g35="全新徕卡一瞬"`, `:629 g4k="EV生效模式：拍照、录像、专业、街拍和徕卡一瞬"`, `:1814 h5m="徕卡一瞬"`; English default values for the same ids say "All-new Leica Essential"/"Leica Essential" — i.e. **CN branding 徕卡一瞬 == global branding "Leica Essential"**.
  - Camera also ships `assets/watermarks/leica/*` and `assets/cloud_watermark_material/17_ultra_by_leica/*` (watermark only, not the mode).
- AndroidManifest has NO legendary activity declared; legendary UI is in-camera (module UI `LU3/b`).

## 2. CN MiMediaEditor — cloud second pass ("二次增强", backend legendV2)

APK: `cn/data_apps/MiMediaEditor.apk`, versionCode 210994306, versionName 2.10.43.0.6, dex classes.dex/2/3 ≈ 9.2/10.8/3.0 MB. Package `com.miui.mediaeditor`; `MIUIGallery` (com.miui.gallery) starts it.

### 2.1 UI strings & entry (decoded resources)
`cn/decomp/editor_res/res/values-zh-rCN/strings.xml` (English default in `res/values/strings.xml`):
- `legendary_info_title` = **徕卡一瞬** / EN "Leica Essential" (line 1186 / EN 1414)
- `legendary_mi_info_title` = **传奇一瞬** / EN "Essential Moment"
- `legendary_mi_notification_{channel_name,complete,failed,processing,queued}` = 传奇一瞬通知/处理完成/失败/处理中…/排队中…
- `legendary_notification_{...}` = 徕卡一瞬…  (queued = "排队中…")
- `legendary_desc_leica_m9` = 使用"徕卡一瞬"拍摄的照片支持二次增强，利用云端图像大模型技术，呈现5000万像素…
- `legendary_desc_leica_m3` = …通过底片迫冲技术…银盐颗粒质感;  `legendary_desc_leica_m10R` = …云端图像大模型…5000万像素…;  `_with_len` variants add 徕卡经典镜头虚化复刻 (bokeh re-render)
- `legendary_desc_mi_m9/m3/m10R` = 传奇一瞬/非 Leica 设备的 "借助云端大模型…" variants
- `legendary_image_not_support` = "Can't process edited images" (二次增强 rejects already-edited images)
- `tips_support_gallery_frame` = 仅支持小米徕卡联合研发手机拍摄的照片 (leica watermark tip)
Manifest `cn/decomp/editor_res/AndroidManifest.xml:260`: `<activity android:name="com.miui.mediaeditor.legendary.LegendaryActivity" android:exported="true" android:launchMode="singleTop" android:screenOrientation="portrait">`; `:263` `LegendaryForegroundService` (dataSync foreground service for queued cloud tasks). Editor side intent action string: `com.miui.mediaeditor.action.legendary`; internal route `/legendary/service`; channel `LegendaryStatusHigh`.

### 2.2 Gating predicate (exact)
`cn/decomp/editor_smali_d2/com/miui/mediaeditor/provider/MediaEditorProviderForGallery.smali`, method `call()` dispatch, legend branches at lines ~2531-2620:
```
"method_is_legend_available":  rt.a.g() && ah0.b.g()
"method_is_xm_legend_available": ft.s.a()
```
- `cn/decomp/editor_smali_d2/rt/a.smali:1243 g()Z` → `rt/a$j.b(null)`; `cn/decomp/editor_smali_d2/rt/a$j.smali`: compares `Build.DEVICE` with obfuscated string ("nezha") and `SystemProperties.get(decoded("ro.theme_customize"), "")` with decoded "LCC". Strings are XOR-obfuscated: decoder `cn/decomp/editor_smali_d2/bw/b.smali a()` = `char ^ 0x3091bc58` (verified: 0xbc36^0xbc58='n' … → "nezha"; "LCC"; "ro.theme_customize").
- `cn/decomp/editor_smali_d2/ah0/b.smali:185 g()Z` → `SystemProperties.get("ro.miui.build.region","cn").equalsIgnoreCase("cn")` (`Lfz0/a;->b`).
- `cn/decomp/editor_smali_d2/ft/s.smali`: `<clinit>` set = {"madrid","hongkong","nezha"}; `a()` = `set.contains(Build.DEVICE) && !rt.a.g() && ah0.b.g()`.
→ **exactly matches Lead's predicate.** No client-side cloud-control/config check, no account check, no `IS_INTERNATIONAL_BUILD` in this predicate. MIUIGallery Flutter caches these via unified capabilities provider (`libapp_gallery.so`: `method_is_legend_available`, `method_is_xm_legend_available`, `is_xm_legend_available`, `xm_legend_available`).
Legacy gates that also exist: `req.a.g()/ah0.b.g()` are only wired in `MediaEditorProviderForGallery`; `AiActionProvider.smali` has its own region read (`ro.miui.build.region` at line 213).

### 2.3 Cloud stack (base URL, endpoints, JSON, auth)
- Base URL / HTTP client: **`cn/decomp/editor_smali_d2/p50/e.smali`** `<clinit>`: `Lir/h$a` builder with baseUrl **`https://api.open.ai.xiaomi.com`**, header `"User-Agent" = "MiuiGallery/%s"` formatted with `com.miui.mediaeditor` version code. (Same URL string duplicated in `cn/decomp/editor_smali_d1/com/miui/gallery/editor_common/hardwareauth/c.smali`.)
- Retrofit interface: **`cn/decomp/editor_smali_d1/pn/a.smali`** (annotations `Lez0/o;` = @POST path, `Lez0/k;` = headers, `Lez0/i;` = @Query, `Lez0/a;` = @Body):
  - `POST /aiPhotoCloud/api/legendV2/create` — headers `Content-Type:application/json`, query params `signature` (String) + `timeStamp` (long), body `Lqx0/d0;`, returns `AiAvatarV2ResponseEntity<CreateLegendV2TaskResult>`
  - `POST /aiPhotoCloud/api/legendV2/list`, `POST /aiPhotoCloud/api/legendV2/getResult`
  - legacy: `POST /aiPhotoCloud/api/legend/create`, `/aiPhotoCloud/api/legend/getResult`; common `POST /aiPhotoCloud/api/task/changeStatus`
  - file upload endpoints in same cloud SDK: `/aiPhotoCloud/api/file/upload`, `/aiPhotoCloud/api/file/batchUploadByByte` (image is uploaded first; create carries `imgUrl`).
- Request JSON schemas (from generated Moshi adapters in `cn/decomp/editor_smali_d1/com/miui/mediaeditor/aigc/cloud/internal/legend/api/entity/*JsonAdapter.smali`):
  - `CreateLegendV2TaskParams` fields: `androidId, aperture(Float), deviceName, deviceType(int), focusX, focusY, imgUrl, oaid, requestId`
  - `CreateLegendV2TaskResult`: `counts, taskId, deductType, points` (points/deductType = billing/quota; `/billing/preCheck`, `/billing/confirm` endpoints also exist)
  - `QueryLegendV2ResultParams` / `RetryLegendTaskParams`: `oaid, requestId, taskId`
  - `QueryLegendV2ListParams`: `oaid, requestId, pageNum, pageSize`
  - `ChangeLegendTaskStatusParams`: `oaid, requestId, status, taskId`
  - `CloudLegendUploadParam(sourceUri=...)/CloudLegendV2UploadParam(sourceUri=...)`, `CloudLegendResultEntity/CloudLegendV2ResultEntity(resultBitmap=, imgUrl=)`
- Task manager: **`cn/decomp/editor_smali_d1/com/miui/mediaeditor/aigc/cloud/internal/legend/LegendCloudManager.smali`** (5421 lines): `createAITask`, `checkResult`, `queryLegendV2TaskList`, `retryTask`, `changeLegendTaskStatus`; JSON body logged (`请求的json :`); polling states `legend task processing，progress:`, `legend task complete , requestId:`, `legend task error status=`, `legend checkResult timeout/exception`, `Too many requests`, `请求失败`.
- Auth: **cookie based** — 401 handling string: `cookie 鉴权失败(401)，刷新 cookie 重试。Sign Info：` (4 occurrences in LegendCloudManager). Requests also carry `signature` + `timeStamp` query params. Hardware/device auth helper package: `com.miui.gallery.editor_common.hardwareauth` (`cn/decomp/editor_smali_d1/.../hardwareauth/c.smali`) — global-analyst reports `HardwareAuthTokenManager` + `/auth/v1/hardwareAuthToken` + `/hardwareNonce` endpoints (CN evidence: same base host class + hardwareauth package; token endpoint strings not yet extracted — NOT DONE exact path on CN).
- Cloud config: `com.miui.mediaeditor.aigc.cloud.legend.LegendCloudConfig` = `(int a, int b)` (constructed from `LegendCloudConfig(timeOut=` JSON via `LegendCloudConfigJsonAdapter`) — client-side timeouts/polling config only; not an enablement flag.
- Cloud algorithms: `com.miui.mediaeditor.aigc.cloud.legend.EdgeCloudLegendAlgorithm`, `EdgeCloudLegendV2Algorithm`, `CloudLegendUploadProcessor`, `CloudLegendV2UploadProcessor`, `CloudLegendM9Processor`, `CloudLegendV2Processor`; local: `com.miui.mediaeditor.algo.monopan.{MonopanAlgorithm,MonopanJni,MonopanProcessParam}`, `legendary.algorithm.LegendRefineJni` (`await LegendModeSdkLoader.awaitReady`, `start download algorithm_monopan`, `load monopan libraries success, moduleDir=`), so M3/MONOPAN has BOTH local (editor) and cloud paths; M9/M10R cloud path is the 5000万/5000MP upscale.

### 2.4 Photo metadata / second-pass trigger
- Editor smali pkg `cn/decomp/editor_smali_d2/com/miui/mediaeditor/legendary/`: `LegendaryActivity(.kt)`, `LegendaryForegroundService`, `entity/BizRenderResult{Reset,Queued,Loading,Success,Error,Cancel}` (matches UI 排队中/处理中/完成/失败), `entity/LegendHandleResult`, `entity/LegendSaveResult`, `LegendMetaProto$M9Msg` + nested `AwbGain`, `Rect`; log strings `legend cloud failed, requestId:`, `create cache failed legendTaskId=`, `render legend v2 success, imgUrl: `, `legendSaveResult=`, `cleanLegendZoomBytes: SOS marker not found` (tail-marker cleanup in saved JPEG), `handleExportTags: skip, not legend mode`, `tag_legendary_task_loading_dialog`, `tag_legendary_task_delete_dialog`.
- `LegendMetaProto$M9Msg` (protobuf, fields visible as `AISP_*_FIELD_NUMBER`): ISO(2), AWBGAIN(3), ADRCGAIN(4), ISPGAIN(5), ANCHORINDEX(6), FOV(7), DIRECTION(0xb), LSCROW/COL(0xc/0xd), LSC_GR/GB/R/B(0xe-0x11), CCM(0x12), CCT(0x13), INDOOR_FLAG(0x15), ALGO_RET(0x1a), ALGOVERSION(0x1c), FACERECT(0x1d), FACTOR(0x23) + `Rect`/`AwbGain` messages. This is the raw ISP metadata the cloud refine needs; the editor parses it out of the captured file's appended legend metadata.
- Writer in camera: **NOT FOUND in any extracted CN APK dex** (no `M9Msg`/`LegendMetaProto`/`LeiCaStyle` strings in `cn/analysis/cam_dex/*.dex`, MiuiExtraPhoto, MIUIAICR, AICR, etc.) → the metadata is written by native code / dynamically-downloaded legend capture plugin. NOT DONE: exact on-disk metadata container/tag (candidate: XMP `ns.xiaomi.com/photos/1.0/camera/reedit`+`xmend` namespaces present in editor; gallery Rust has `LeiCaStyle` / `hasLeicaContentCredential`).
- 二次增强 entry gating: editor UI resource implies generic flow; the capability flag `legend_available` gate lives in provider (§2.2), and image eligibility comes from the legend metadata + `legendary_image_not_support` ("Can't process edited images"). **Answer: entry visibility = legend_available capability (props/region) AND photo carries legend metadata; it is NOT prop-only.**

## 3. Gallery / plugin (display side)

- `cn/data_apps/MIUIGallery.apk` = Flutter: no dex; `libapp.so` (22 MB Dart) references `com.miui.mediaeditor.legendary.LegendaryActivity` and assets `assets/images/legend_icon.webp`, `assets/images/type_indicator_legend_icon.webp`, `assets/images_dark/legend_icon.webp`; `libapp_gallery.so` (39 MB Rust) has capability probe (`method_is_legend_available`, `method_is_xm_legend_available`, `is_legend_available`, `is_xm_legend_available`, `legend_available`), and Rust string `is_legend_available`/`is_xm_legend_available` in `media_editor_api_helper.rs`; not region-gated itself (delegates to editor provider). Gallery cloud network base URLs (Rust): `galleryapi.micloud.xiaomi.net`, `g-api`... i.e. gallery's own cloud is unrelated to legendV2.
- `cn/data_apps/HyperGalleryPluginCn.apk` (`com.miui.gallery` plugin, 24.8 MB, classes.dex 8.6 MB): Leica display support: `SpecialTypeConstant$PhotoLeicaStyle`, `PhotoLeicaStyle` enum values `PHOTO_LEICA_STYLE_{NATURAL,AUTHENTIC,VIBRANT,MASTER,PORTRAIT}`, `INDEX_LEICA_STYLE`, `leiCaStyle`, **`CR_LEICA_MOMENT_LINE`**, `hasLeicaContentCredential`, `getLeicaStyle/getLeicaStyleTip/isHaveLeicaStyle`, `tip_leica_{authentic,master_portrait,portrait,vibrant}`. → this plugin provides the "徕卡一瞬" badge/style info in gallery; NOT found in MiuiExtraPhoto/MediaViewer dex.

## 4. taiyi model package (CN image `cn/apps2/{config,lib,model,plugin}`)

NOT Leica-related. Contents are the Mi AI-service (AIService) taiyi model packages:
- `model/`: icon_isr_model_qcom_8850, ner_model_travel_cpu, nlu_intent_ime_model, nlu_intent_model_cpu, ocr_model_qnn_minn, segment_model_qcom_qnn, video_segment_model_qcom_8850 (each vN/*.taiyi.model) — 82 MB total.
- `plugin/`: framework_compat, icon_isr, lac, ner, ner_travel_pligin_cpu, nlu_intent_cpu, nlu_intent_ime_plugin, ocr_qnn, qcom_qnn_v2_36_0_v81, schedule, segment_v3_npu, video_segment_qcom, wechat_privacy, wps (*.taiyi) — 77 MB.
- `config/`: framework_compat.json, lac.json, ner*.json, nlu_intent*.json, ocr*.json, segment*.json, video_segment*.json, wechat_privacy*.json, wps.json.
- `lib/arm64/` empty in extraction. No M9/MONOPAN/Leica model here; Monopan/M9 assets are downloaded by editor (`start download algorithm_monopan`) or camera plugin.

## 5. Versions / signing / CN-vs-global replacement notes

| component | package | CN version | signer |
|---|---|---|---|
| MiuiCamera.apk | com.android.camera | 6.7.000280.0 (670002800) | CN Xiaomi MIUI cert (C=CN,…,CN=MIUI) |
| MiMediaEditor.apk | com.miui.mediaeditor | 2.10.43.0.6 (210994306) | CN Xiaomi MIUI cert |
| MIUIGallery.apk | com.miui.gallery | Flutter (no dex) | CN Xiaomi MIUI cert |
| HyperGalleryPluginCn.apk | com.miui.gallery plugin | — | CN Xiaomi MIUI cert |

All four CN apps share the standard Xiaomi MIUI release certificate (identical `subject=`/`issuer=`); replacing CN APKs on a global ROM must satisfy whatever signer pairing the OS enforces (global apps are normally signed with the same MIUI key family, verify global copies' certs before flashing).
CN camera manifest extra meta-data `camera.support_legendary_mode=true` and camera version 6.7 vs global 6.6 is the main capture-side delta. Camera epic: no legend assets in `assets/`, no extra native libs named *legend*/*leica*/*mono*/m9 (checked `unzip -l`), so the swap is APK (+ likely ODM prop resetprop) centric; unknown dynamic legend SDK must be checked at runtime (see open items).

## 6. CN config files with Leica content (`work/leica/cn/configs/`)

- `odm_etc/*.prop` — 11 SKU files contain `ro.boot.product.theme_customize =P1_Leica`, `ro.theme_customize=LCC`, `ro.theme_leica=true`, `ro.product.odm.marketname=Xiaomi 17 Ultra by Leica`, `ro.special_edition=true`. These are boot-selected from `ro.boot.product.hardware.sku` + `ro.boot.hwversion` (lead). **These are the props the camera/editor predicates read; resetprop equivalents are enough for the editor path; camera may read at process start only (clinit).**
- `product_etc2/` (device_features, lut, precust_theme, pipeline_infos, aconfig) contains 468 `leica` string hits (mostly precust_theme/device-feature entries); no legendV2/aiPhotoCloud config found; `/product/etc/lut` has no Leica LUT file. Cloud enablement is NOT in local config.
- `product_etc/theme/.data/**` mrc theme blobs contain Leica hits (theme content).

## 7. Open items / NOT DONE

1. NOT DONE: exact CN camera method that consumes cached `LVa/b.u` to make `LegendaryEnter` visible in the mode list (the mode entries are registered by `BaseModuleEntry` subclasses; the filter reading `camera.support_legendary_mode`/`isSupportLegendaryMode` is in a dex we didn't baksmali). Evidence it exists: camera dex strings `isSupportLegendaryMode`, `camera.support_legendary_mode` meta-data, `getLegendBokehCapsInfo`, `com.xiaomi.legendMode.capsInfo`, `pref_legendary_mode_key`. Ready to finish in ~10 min if needed (baksmali camera classes2/3/5 and grep).
2. NOT DONE: definitions of `FragmentLegendaryIntroduction/FragmentLegendarySelected/LegendarySelectedAdapter/LegendaryNativeCaptureBridge/LegendaryProcessingProvider/LegendM9Container` — not in any CN APK dex we scanned (only descriptor refs in camera `classes.dex`), so they are loaded dynamically or live in an APK not extracted. No legend-mode downloader class/URL/prop found yet in camera dex1/dex4 smali. Candidate markers: `M_legend_`, `module_name_xiaomi_legendary_plan_b`, `M3_monopan`.
3. NOT DONE: writer of legend metadata (`LegendMetaProto.M9Msg` / XMP `LeiCaStyle`, `reedit`/`xmend` namespaces) on capture side; readers confirmed editor side only.
4. NOT DONE: hardwareAuthToken exact CN path (global analyst has `/auth/v1/hardwareAuthToken`,`/hardwareNonce`); CN evidence: 401 cookie refresh, `signature`+`timeStamp` query params, `com.miui.gallery.editor_common.hardwareauth` package using same base host.
5. NOT DONE: global APK signer comparison (global APK paths owned by other teammates).
