# 小米 17 Ultra（nezha）国行徕卡版「徕卡一瞬 / 云端二次增强」代码分析与国际版 Magisk 移植

> 分析对象：
> - 国行（CN）：`nezha_images_OS4.0.5.0.XPACNXM_20261021.0000.00_17.0_cn`（HyperOS 4，Android 17 / SDK 37）
> - 国际版（Global）：`nezha_global-ota_full-OS4.0.0.8.XPAMIXM-user-17.0` + 官方 `OS3.0.337.0.XPAMIXM` 线刷包骨架（同机型 nezha）
> - 功能：相机「徕卡一瞬」拍摄（端侧 M9 / M3+MONOPAN 50 等徕卡风格），以及相册编辑（`com.miui.mediaeditor`，相册-编辑）中的「二次增强」云端处理（“二瞬”，云端图像大模型）
>
> 结论级别说明：本文所有结论均给出 ROM 内的文件名 / 类名 / 方法 / 字符串 / 资源证据；**云端服务端授权为黑盒，无法离线验证**，已单列风险。

---

## 0. 结论摘要（TL;DR）

| 问题 | 结论 |
|---|---|
| 国行「徕卡一瞬」由谁实现？ | 相机端（拍摄）：`com.android.camera`（MiuiCamera），国行 6.7.000280.0 独有完整徕卡版 UI/资源；相册编辑端（云端二次增强）：`com.miui.mediaeditor` 内的 `legendary.*` + `aigc.cloud.internal.legend.LegendCloudManager` 云端任务栈 |
| 国际版缺代码吗？ | **几乎不缺**。国际版 `MiuiCamera 6.6.000570.5` 已有基础 `LegendaryModule/LegendaryEnter/LegendarySelectedActivity`；国际版 `com.miui.mediaeditor 2.10.40.4.8-global` **完整包含** `LegendaryActivity/ViewModel/JobManager`、`LegendCloudManager`、`MonopanAlgorithm/Jni`、`LegendModeSdkLoader`、以及 `api.open.ai.xiaomi.com/aiPhotoCloud/api/legendV2/{create,getResult,list}` 等云处理代码与完全相同的中文 UI 字符串（一瞬×21、二次增强×1、云端×5、徕卡×7）。 |
| 那国际版为什么没有该功能？ | **门禁（gating）**：相册编辑的「二次增强」入口由 `MediaEditorProviderForGallery` 的判定硬性要求 `Build.DEVICE=="nezha" && ro.theme_customize=="LCC" && ro.miui.build.region=="cn"`；而徕卡版 SKU 属性（`ro.theme_customize=LCC`、`ro.theme_leica=true` 等）来自 `/odm/etc/nezha_5.x.prop`，由 bootloader 的 `ro.boot.product.hardware_sku`+`ro.boot.hwversion` 在开机时选择导入，普通机不导入；国际版 `ro.miui.build.region=global` 使 region 判定必然为假。 |
| 相机端能否只靠属性打开？ | **不能完整实现**。国行相机 6.7 独有徕卡版采集 UI 资源（`legend_ccd/cmos/bw`、`legend_35mm/75mm`、`legendary_leica_m3/m9/m10r_*`、`legendary_summicron_35mm`、`legendary_summilux_75mm` 等，国际版 `resources.arsc` 中为 0），因此需要替换国行 MiuiCamera APK。 |
| APK 替换是否可行？ | **签名兼容**。CN/Global 对应 APK 均为同一张小米证书（SHA-256 `c9009d01ebf9f5d0302bc71b2fe9aa9a47a432bba17308a3111b75d7b2149025`，`CN=MIUI,O=Xiaomi`），可直接作为系统 APK 替换/同签名升级。 |
| 云端那半边能移植成功吗？ | **取决于服务端**。云端任务请求包含 `Build.DEVICE`、`isLCC`、小米账号 cookie、以及由 `api.open.ai.xiaomi.com/auth/v1/hardwareAuthToken` 下发的**硬件认证 token**；返回含 `deductType/points/counts`（服务端计费/授权）。设备白名单 `leica_support_devices / lcc_support_devices / mist_support_devices` 来自云端 CloudConfig（`mediaeditor_filter_config_v2`），不在 ROM 里。客户端模块只能把“入口/开关”打开，**无法授予服务端权益**；预期可能出现“按钮出现但任务失败/排队失败”。 |
| 交付物 | `work/leica/module/dist/` 下两个 Magisk 模块：`LeicaMoment_nezha_v1.0.0_PropsOnly.zip`（仅属性/门禁层，10,621 B，sha256 `e17ccc6c…3ff7a1`）与 `LeicaMoment_nezha_v1.0.0_Full.zip`（属性 + 国行相机 APK 替换，123,764,641 B，sha256 `5b65908f…d34c1`）；另有本报告、`cn_analysis.md`、`global_analysis.md`、`research_web.md`。经 `check_module.py` 校验两个 zip 均 PASS（0 error / 0 warning），`unzip -tq` 无错误，Full 内嵌国行相机 APK sha256 与源文件一致（`4637b77d…08f63`）。 |

---

## 1. 分析方法与数据来源

### 1.1 镜像提取（无设备、纯离线）
1. 国行 `super.img`（Android sparse，12.8 GB）→ `simg2img` 转 raw（15.3 GB）→ `lpdump` 读取动态分区表。
2. 用 `dump.erofs --offset=<分区字节偏移> --path=/... --ls/--cat` **直接按分区偏移读取 EROFS**，用 `fsck.erofs --offset=... --extract` 定点导出 APK/配置，避免低效的全分区 lpunpack。
   - 国行分区偏移在 `work/leica/tmp/cn_offsets.json`（如 product_a=5085593600、system_a=10234101760、system_ext_a=11230248960、odm_a=1048576、mi_ext_a=12698255360）。
3. 国际版 OS4.0.0.8：官方全量 OTA `payload.bin` 解出的分区镜像位于 `work/dump/{system,product,system_ext,mi_ext,odm,vendor}.img`（EROFS，可直接 `dump.erofs`/`fsck.erofs` 读取）。
4. 工具链：`dump.erofs/fsck.erofs/lpdump/simg2img`、`baksmali/smali`（自建 fat jar）、`jadx 1.5.6`、`apktool 2.11.1`、自研纯 Python AXML/dex 扫描器（见 `work/leica/global/analysis/scripts/`）。

### 1.2 关键 APK 清单（本次分析对象）
| 角色 | 国行 APK（路径） | 国际版 APK |
|---|---|---|
| 相机 | `work/leica/cn/apps2/MiuiCamera.apk`（product/priv-app，200.6 MB） | `work/leica/global/apps/MiuiCamera.apk`（196.8 MB） |
| 相册编辑（云端二次增强） | `work/leica/cn/data_apps/MiMediaEditor.apk`（product/data-app，222.7 MB） | `work/leica/global/apps/MIMediaEditorGlobal.apk`（256.8 MB） |
| 相册 | `work/leica/cn/data_apps/MIUIGallery.apk`（Flutter） | `work/leica/global/apps/MIUIGalleryGlobal.apk`（Flutter） |
| 相册插件 | `work/leica/cn/data_apps/HyperGalleryPluginCn.apk` | `work/leica/global/apps/HyperGalleryPluginGlobal.apk` |
| 相机扩展 | `work/leica/cn/apps2/MiuiExtraPhoto.apk` | `work/leica/global/apps/MiuiExtraPhoto.apk` |
| 相机 AI | `CameraMind` / `MIUIAICR` / `AIService` / `AiasstVision` | 同名对应 |

> 注意：HyperOS 4 的 `com.miui.gallery` 国行放在 `product/data-app/MIUIGallery/MIUIGallery.apk`（首次开机安装到 /data 的可卸载预装），国际版放在 `product/priv-app/MIUIGalleryGlobal`（特权系统应用）；`com.miui.mediaeditor` 两国都是 `product/data-app`（CN `MiMediaEditor` / Global `MIMediaEditorGlobal`）。

---

## 2. 功能代码定位（证据）

### 2.1 相机端：「徕卡一瞬」拍摄（端侧部分）

**国行 MiuiCamera 6.7.000280.0 的徕卡相关代码（dex 字符串/类与资源）：**
- Manifest：`<meta-data android:name="camera.support_legendary_mode" android:value="true"/>`（`cn/decomp/camera_res/AndroidManifest.xml:151`）。
- 类：`com.android.camera.features.mode.legendary.LegendaryModule`、`LegendaryEnter`（`getModuleId()` = **0x100**，`getModeUI()`→`LU3/b`；smali 在 `cn/decomp/camera_smali_d1/com/android/camera/features/mode/legendary/`）、`com.android.camera.legend.fragment.FragmentLegendaryIntroduction`、`FragmentLegendarySelected`、`LegendarySelectedAdapter`、`LegendaryModeUI`、`LegendaryNativeCaptureBridge`、`LegendaryProcessingProvider`、`LegendM9Container`（后若干项在国行 APK 中是**引用**，定义不在任何已解出的 CN APK 内 → 见 §6 风险：疑似运行时下载的 `legend_mode` SDK/插件或 native）。
- 资源/字符串名：`legend_leica`、`legend_ccd`、`legend_cmos`、`legend_bw`、`legend_bw_alias`、`legend_ccd_alias`、`legend_cmos_alias`、`legend_35mm/75mm`、`legend_camera_selection`、`legend_effect_selection`、`legend_pickers_ccd/cmos/bw`、`legend_selection_introduction`、`legendary_leica_m3_icon/template/text_icon`、`legendary_leica_m9_*`、`legendary_leica_m10r_*`、`legendary_leica_bokeh_on/off`、`legendary_summicron_35mm`、`legendary_summilux_75mm`、`legendary_m3/m9/m10r_leica`、`legendApertureListMax`、`legendFocalLength`、`isLeicaCustomize`、`isLeicaMode`、`com.xiaomi.legendMode.capsInfo`、`getLegendBokehCapsInfo` 等。
- 相机 dex 中出现 `"17 ultra by leica"`、`M3_monopan`、`leica_name/leica_classical/leica_default/leica_mechanical/leica_advanced` 等取证。

**国际版 MiuiCamera 6.6.000570.5 的差异：**
- 有基础 Legendary 框架（`LegendaryModule / LegendaryEnter / LegendarySelectedActivity`，`legendary_m3`×1、`legendary_m9`×1、`legendary_leica`×1、`custom_shutter_legendary`×1）。
- **没有**国行独有资源：`resources.arsc` 中 `legendary_summicron_35mm`、`legendary_summilux_75mm`、`legendary_m3_leica`、`legendary_m9_leica`、`legendary_m10r_leica` 均为 0 次；`legend_ccd/cmos/bw`、35/75mm 镜头档、M3/M9/M10R 徕卡模板/水印等也不存在（CN-only dex 字符串 87 条，其中 85 条为 Leica 相关）。
- 结论：**仅靠 resetprop 无法补齐国行徕卡版采集 UI，必须替换为国行 MiuiCamera APK**。

**属性门禁（两台机相机代码同构）：**
- 相机设置类在 `<clinit>` 静态初始化时缓存：`ro.theme_customize`、`ro.boot.product.theme_customize`、`ro.product.mod_device`，并读取调试属性 `camera.debug.theme_customize.disabled`；水印主题类还会回退读取 `ro.boot.product.theme_customize`。
- 因此：**属性必须在相机进程启动前设置好**（post-fs-data resetprop + force-stop 相机），否则需重启相机/重启设备。

### 2.2 相册编辑端：「二次增强」云端处理（二瞬）

**国行与国际版 `com.miui.mediaeditor` 都完整包含以下栈（类名以国际版 2.10.40 反编译为准，CN 2.10.43 为同一套代码的另一个 R8 混淆名）：**
- `com.miui.mediaeditor.legendary.*`：`LegendaryActivity`、`LegendaryViewModel`、`LegendaryForegroundService`、`LegendaryJobManager`、`legendary.algorithm.LegendModeSdkLoader`、`LegendaryVersionResolver`。
- `com.miui.mediaeditor.aigc.cloud.internal.legend.LegendCloudManager` + 请求实体：`CreateLegendV2TaskParams`、`CloudLegendUploadParam`、`CloudLegendV2Param`、`Query/Retry`、`TaskStatus`。
- `aigc.cloud.legend.{EdgeCloudLegendAlgorithm, EdgeCloudLegendV2Algorithm, LegendCloudConfig, CloudLegendM9Processor, CloudLegendV2Processor}`。
- `algo.monopan.{MonopanAlgorithm, MonopanJni, MonopanSdkLoader, MonopanApiManager}`。
- 端点常量：`https://api.open.ai.xiaomi.com` + `/aiPhotoCloud/api/legend/create|getResult`、`/aiPhotoCloud/api/legendV2/create|getResult|list`；插件侧 `HardwareAuthTokenManager` → `/auth/v1/hardwareAuthToken`、`/auth/v1/hardwareNonce`。
- 云端配置键：`leica_support_devices`、`lcc_support_devices`、`mist_support_devices`，云端模块 `mediaeditor_filter_config_v2`（camerainfra CloudConfig）。
- UI 字符串（两国 `resources.arsc` 完全一致）：`「徕卡一瞬」拍摄的照片支持二次增强，利用云端图像大模型，提升画面清晰度，画质直达5000万…`、`「徕卡一瞬」处理中… / 排队中… / 失败`、`「M3 + Monopan 50」…`、`云端大模型，进一步拉开明暗层次、还原浓郁的银…` 等。
- `com.miui.gallery`（Flutter）：`assets/app_tools.json`、`assets/app_functions_v2.xml` 两国**逐字节相同**，均含 `一瞬`/`徕卡`/`photo_essential(传奇模式/徕卡一瞬)`；`libapp.so` UTF-16 字符串 `一瞬`×4、`云端`×31、`徕卡`×1 两国均有。

**云端任务请求（job-time，非仅入口）**：`LegendCloudManager` 构造 `CreateLegendV2TaskParams(imgUrl, 账号id, Build.DEVICE, isLCC, aperture, focusX, focusY, …)` 后 POST 到 `legendV2/create`；返回含 `deductType/points/counts/legendaryVersion/serverId/taskId/status/errorCode`，即**配额/计费/权益在服务端**。401 时刷新小米账号 cookie 重试。

**国行侧 smali 逐行确认（`cn_analysis.md` §2）**：
- 门禁判定在国行 2.10.43.0.6 中为 `rt.a.g() && ah0.b.g()`（`MediaEditorProviderForGallery.smali` 分派 ~L2531），语义与国际版完全一致；字符串用 XOR key `0x3091bc58` 混淆（`bw/b.a()` 解码），`ah0/b.smali:185` = `SystemProperties.get("ro.miui.build.region","cn").equalsIgnoreCase("cn")`。**判定中不含云控/账号/IP 检查** → resetprop 即可打开。
- 云端 Retrofit 接口 `pn/a.smali`：`POST /aiPhotoCloud/api/legendV2/create`（headers `Content-Type: application/json`，query `signature`+`timeStamp`，body JSON）、`/legendV2/list`、`/legendV2/getResult`、旧版 `/legend/create|getResult`、`/task/changeStatus`；图片先上传 `/aiPhotoCloud/api/file/upload`（或 `/batchUploadByByte`），create 里只带 `imgUrl`。
- `CreateLegendV2TaskParams` JSON 字段：`androidId, aperture, deviceName, deviceType, focusX, focusY, imgUrl, oaid, requestId`；`CreateLegendV2TaskResult`：`counts, taskId, deductType, points`（另有 `/billing/preCheck`、`/billing/confirm`）；HTTP UA = `MiuiGallery/<versionCode>`，cookie 鉴权（401 刷新重试）。
- 二次增强的**照片元数据**：编辑器解析 `com.miui.mediaeditor.legendary.meta.LegendMetaProto$M9Msg`（protobuf：AISP_ISO/AWBGAIN/CCM/LSC/FACTOR/FACERECT/ALGOVERSION 等 M9 管线原始数据）用于云端 refine。**该元数据的写入方不在已解出的任何 CN APK dex 中**（相机/ExtraPhoto 均无）→ 位于 native 或运行时下载的 legend 采集插件中（见 §7 风险）。
- 品牌名对照（重要）：CN 资源 ` legendary_info_title = 徕卡一瞬`，同一资源 id 的**英文默认值 = “Leica Essential”**；`legendary_mi_info_title = 传奇一瞬 / Essential Moment`。即国际版内部把该能力称作 **Leica Essential**。

### 2.3 相册/插件端
- `com.hyper.gallery.plugin`：国行/国际版都有 `徕卡人像/徕卡生动/徕卡经典` 等字符串与 `api.open.ai.xiaomi.com/vision/...`；国行独有 `PHOTO_LEICA_STYLE_NATURAL[_PORTRAIT]`。
- 插件通过 `HardwareAuthTokenManager` 调用 `/auth/v1/hardwareAuthToken|hardwareNonce`，说明云处理链路与**硬件认证设备 token** 绑定。

---

## 3. 启用条件（门禁）逆向 —— 本项目的核心

### 3.1 徕卡版 SKU 属性机制（关键发现）

ROM 中 `/odm/etc/build.prop` 有动态 import：
```
import /odm/etc/${ro.boot.product.hardware.sku}_${ro.boot.hwversion}.prop
import /odm/etc/${ro.boot.product.hardware.sku}_${ro.boot.ptcountrycode}_build.prop
```
国行与国际版 `/odm/etc/` 下都存在 23 个 `nezha_5.x.prop`（硬件版本属性），其中 **11 个是徕卡版 SKU**：`nezha_5.0.6 / 5.0.8 / 5.1.6 / 5.1.8 / 5.11.6 / 5.12.6 / 5.19.9 / 5.2.5 / 5.2.7 / 5.9.7 / 5.9.9`。这些文件**国行与国际版逐字节相同**，内容（以 `nezha_5.0.6.prop` 为例）：
```properties
# theme customize
ro.boot.product.theme_customize =P1_Leica
# Camera customize
ro.theme_customize=LCC
ro.product.odm.model=25128PNA1C
ro.product.odm.cert=25128PNA1C
ro.product.odm.marketname=Xiaomi 17 Ultra by Leica
ro.product.model_for_attestation=25128PNA1C
ro.special_edition=true
ro.product.odm.support_cai=true
# leica customize
ro.theme_leica=true
ro.bdsms=true
ro.tiantong=true
```
- 只有当设备 bootloader 上报的 `ro.boot.product.hardware_sku`=`nezha` 且 `ro.boot.hwversion` 命中上述版本（即**徕卡版硬件**）时才会导入。
- **所有可刷写的 build.prop（system/product/system_ext/vendor/odm/mi_ext）中都没有 `ro.theme_customize`** —— 普通机必须靠模块 resetprop 注入。
- 国际版同样带这些徕卡 SKU 文件 → 徕卡版硬件刷国际版 ROM 时属性仍会自动生效（相机基础徕卡 UI 会出现），但相机 APK 缺国行版本、且 region 为 global，云端入口仍被门禁挡住。

### 3.2 相册编辑「二次增强」入口判定（精确条件）

`com.miui.mediaeditor` 对外提供 `MediaEditorProviderForGallery.call("method_request_function_list_with_cta")`，其判定（国际版 2.10.40.4.8-global 反编译，CN 2.10.43 语义相同）：
```
method_is_legend_available（徕卡一瞬/LCC）
    = (Build.DEVICE == "nezha" && SystemProperties.get("ro.theme_customize","") == "LCC")
      && SystemProperties.get("ro.miui.build.region","cn").equalsIgnoreCase("cn")

method_is_xm_legend_available（传奇一瞬，去徕卡版）
    = Build.DEVICE ∈ {"madrid","hongkong","nezha"}
      && !(Build.DEVICE=="nezha" && ro.theme_customize=="LCC")
      && ro.miui.build.region == "cn"
```
- `ro.miui.build.region`：国际版 build.prop = `global`，国行 = `cn` → **这段判定必须 region=="cn" 才会为真**。
- 该判定**每次调用都重新读属性**（无静态缓存），因此 Magisk `resetprop ro.miui.build.region=cn` 可在下次调用生效。
- 相机 APK 的属性是 `<clinit>` 静态缓存 → 属性必须在相机进程启动前设置（post-fs-data 注入 + force-stop）。
- 另外，任务真正执行时还会校验：**CTA 隐私协议**（`CloudConfig.initialize` “CTA not permitted yet”）、**小米账号登录**（cookie）、**硬件认证 token**、**云端 CloudConfig 设备白名单**、服务端配额/点数。

### 3.3 为什么普通机/国际版默认都看不到入口
即使同一台普通 17 Ultra 硬件，`ro.theme_customize` 不存在、`ro.miui.build.region=global`，两条件之一即假；国际版 ROM 也不会主动下发 CN 的云端 CloudConfig。因此入口在“普通机 + 国际版”下必然隐藏。

---

## 4. 国行 vs 国际版 差异总表

| 项 | 国行 OS4.0.5.0 | 国际版 OS4.0.0.8 |
|---|---|---|
| region | `cn` | `global` |
| mod_device | `nezha` | `nezha_global` |
| 徕卡 SKU 属性文件 `/odm/etc/nezha_5.x.prop` | 有（11 个徕卡版，逐字节） | **有，逐字节相同** |
| MiuiCamera | 6.7.000280.0（含国行徕卡采集 UI/资源） | 6.6.000570.5（基础 Legendary，缺徕卡采集资源） |
| com.miui.mediaeditor | 2.10.43.0.6（云端栈完整） | 2.10.40.4.8-global（**云端栈完整，字符串一致**） |
| com.miui.gallery | 5.4.2.26-1008-cn（Flutter，资源一致） | 5.4.2.10-0907-global（Flutter，资源一致） |
| HyperGalleryPlugin | 5.4.2.6 | 5.4.2.4-global（leica 字符串略多） |
| 签名证书 | 均为小米 `c9009d01…`（MIUI）/`d45f076f…`（AI 应用） | 同左 |
| /product/etc/device_features、lut、aconfig | 与国际版**逐字节相同** | 同左 |
| /odm/etc/camera 徕卡滤镜参数 | `leica_filter_param{,_m3,_m9_preview,_m9_snapshot}.bin`、`mialgo_monopan_cl.bin` 均有 | **均有** |
| 相机 Native 库 | 有 `libperformance.so`，无 XMI 独有 | 多 crashlytics 等，无 `libperformance.so` |
| 云端 SDK | `legend_mode` / `algorithm_monopan` 运行时下载（d ex 引用的 `libmonopan_jni.so` 等不在 APK 内） | 同（下载服务端门禁） |
| 云端配置 `/odm/etc/default_cloud.json` | 424016 B（`encrypted_data` 加密块） | 441008 B（不同，未解密） |

---

## 5. 云端处理流程与限制（重要）

1. 相册（Flutter）→ 调 `MediaEditorProviderForGallery` 获取功能列表（含 CTA 状态）→ 显示「二次增强」入口。
2. 用户触发 → `LegendaryActivity/ViewModel` → `LegendaryJobManager` → `LegendCloudManager.createAITask(CreateLegendV2TaskParams)`：
   - 字段：`imgUrl`、账号 id、`Build.DEVICE`、`isLCC`、`aperture`、`focusX/focusY`、`oaid` 等。
   - 认证：小米账号 cookie + `HardwareAuthTokenManager` 的硬件认证 token。
   - 端点：`https://api.open.ai.xiaomi.com/aiPhotoCloud/api/legendV2/create`（旧版 `legend/create`），轮询 `getResult`、列表 `list`。
3. 服务端返回：`TaskStatus`、`deductType`、`points`、`counts`（配额/计费/权益）、`errorCode`。之后客户端下载 `legend_mode` / `algorithm_monopan` 等运行库并做本地渲染/回填。
4. **限制清单（客户端无法绕过）**：
   - 服务端设备白名单（`leica_support_devices/lcc_support_devices/mist_support_devices`，来自云端 CloudConfig，不在 ROM）。
   - 小米账号/地区权益与配额（点数、`deductType`）。
   - 硬件认证 token（设备/ROM/SKU 绑定，国际版 + 非徕卡机很可能被拒）。
   - CTA 隐私协议（需用户同意）。
   - `legend_mode` 等 SDK 下载（运行时、服务端门禁）。
   → 因此：**模块可把“入口/开关/相机能力”打开，但云端“二瞬”能否真正处理成功取决于小米服务端；本环境无设备，无法实测。**

---

## 6. 移植方案（Magisk 模块设计）

### 6.1 为什么选这个方案
| 方案 | 可行性 | 结论 |
|---|---|---|
| A. 仅 resetprop（属性层） | 相机基础徕卡 UI 可开；采集端徕卡版资源缺失；云端入口还需要 region=cn | 部分可行（作 PropsOnly 版） |
| B. 属性 + 国行 MiuiCamera APK 替换 | 同签名可替换；补齐采集端徕卡版 UI/资源 | **采用（Full 版）** |
| C. 替换国行 mediaeditor | 国际版已有完整云端栈；替换收益小，且 data-app 已安装到 /data，覆盖无效、卸载重装又会丢签名权限 | 不采用（保持国际版原 APK） |
| D. 打补丁改 mediaeditor 的 region 判定 | 需重签 APK → 与系统/data 已安装签名不匹配，且会丢签名级权限；有系统 App 数据失效风险 | 不采用；改用 region 属性（见下） |
| E. LSPosed hook | 可作为进阶方案，但用户要求 Magisk 模块；且需要额外安装 LSPosed | 不采用（报告保留为可选进阶） |

### 6.2 模块结构（`work/leica/module/`）
```
module.prop                      # id=nezha_leica_moment, 名称/版本
customize.sh                     # 安装时：REMOVE 系统相机旧 oat/vdex；设置权限；初始化配置
post-fs-data.sh                  # resetprop -n：LEICA_SKU_PROPS + 可选 REGION_SPOOF + camera.debug 等
service.sh                       # late_start：一次性 pm clear com.android.camera + force-stop + 日志
uninstall.sh                     # 清理 /data/adb/leica_moment 配置
META-INF/com/google/android/{update-binary,updater-script}
system/product/priv-app/MiuiCamera/MiuiCamera.apk   # （Full 版）国行 MiuiCamera 6.7.000280.0
system.prop                      # 可选兜底
README.md / BUILD_INFO.md
```
属性（`post-fs-data.sh` 用 `resetprop -n`，可配置开关 `/data/adb/leica_moment/config.env`）：
```properties
# LEICA_SKU_PROPS=1（默认开）
ro.boot.product.theme_customize=P1_Leica
ro.theme_customize=LCC
ro.theme_leica=true
ro.special_edition=true
camera.debug.safe.check.disable=true
# REGION_SPOOF=1（默认开；云端入口判定必需）
ro.miui.build.region=cn
```
- 两个构建变体：
  - `LeicaMoment_nezha_v1.0.0_PropsOnly.zip`：只装属性/门禁层（轻量；不含相机 APK；采集端徕卡 UI 不完整）。
  - `LeicaMoment_nezha_v1.0.0_Full.zip`：属性 + 国行 MiuiCamera 6.7 APK 替换（较重，约 200 MB payload）。
- 相机 APK 替换细节：
  - 路径 `/product/priv-app/MiuiCamera/MiuiCamera.apk` → 模块内 `system/product/priv-app/MiuiCamera/MiuiCamera.apk`（Magisk 支持 system/product 挂载）。
  - 旧 OAT：`REMOVE="/system/product/priv-app/MiuiCamera/oat"` 强制 ART 重新编译（Magisk 安装器会把每项拼成 `mknod $MODPATH$TARGET c 0 0`，所以**即使目标是 /product 也必须以 `/system/` 前缀书写**；写成 `/product/...` 不会生效）。首次开机相机启动稍慢属正常。
  - 安装后 `pm clear com.android.camera`（持清除相机配置缓存），并 force-stop/重启相机使 `<clinit>` 重新读取属性；模块用守卫文件保证只清理一次。
  - 诊断：两个变体都带 Magisk 动作按钮 `action.sh` → 把属性/config/相机与编辑器版本/payload 状态/日志尾部写入 `/data/adb/leica_moment/diag.log`，便于用户回传排查。
- 若相机在应用商店被更新过：先 `cmd package uninstall-system-updates com.android.camera`（或卸载相机更新）再重启，系统才会使用模块挂载的国行 APK。

### 6.3 使用与回退
1. Magisk/KernelSU 刷入对应 zip → 重启。
2. 打开相机检查是否出现「徕卡一瞬」入口/徕卡滤镜；打开相册-编辑查看门口。
3. 云端「二次增强」：需登录小米账号、同意 CTA 隐私协议；能否成功取决于服务端。**如果只想要“看到入口”而不改 region**，可把 `config.env` 里 `REGION_SPOOF` 改为 0（入口会消失）。
4. 回退：Magisk 中禁用/删除模块 → 重启；属性自动恢复（resetprop 不持久化），相机恢复系统原 APK。
5. 风险提示：
   - `ro.miui.build.region=cn` 是全局属性，会影响 OTA/区域类服务/部分应用行为；建议先备份并了解后果，确认后再长期开启。
   - 相机 APK 替换属系统级改动：首次开机可能较慢；如遇无法开机，用 Magisk 安全模式（音量键）禁用模块或 `adb shell magisk --remove-modules`。
   - 不保证后续 OTA 兼容；升级系统前先禁用模块。
   - 云处理为小米服务端权益，模块不提供任何“破解/绕过计费”能力。

---

## 7. 验证与局限

- **已静态验证**：
  - 上述类名/方法/字符串/端点均来自实际 APK dex、resources.arsc、smali 反编译（证据文件见 `work/leica/global/analysis/`、`work/leica/cn/`）。
  - **国行侧独立复核**（`cn_analysis.md` §2.2）：国行 2.10.43.0.6 的 `method_is_legend_available = rt.a.g() && ah0.b.g()` 与国际版语义完全一致，判定中**无云控/账号/IP 检查**；`ah0/b.smali:185` 即 region 判定。云端请求字段/端点/签名/上传接口已在国行 smali 逐字段确认。
  - APK 签名、版本号、包名逐一核对（`work/leica/global/analysis/info/`）：CN/Global 对应 APK 同一小米 MIUI 证书。
  - 模块结构经 `check_module.py` 校验（两 zip 均 PASS，0 error/0 warning）、`unzip -tq` 无错误、脚本 `sh -n` 语法检查；Full 内嵌相机 APK 的 sha256 与国行源文件一致（`4637b77d…`）；模块 `build.sh` 对 payload 哈希做了强制校验。
- **未验证（无真机）**：
  - 国行 MiuiCamera 6.7 在全球版 OS4.0.0.8 框架上的运行时兼容性（同 OS 大版本、同机型 HAL，理论可行，但需实测；CN 相机多声明了 3 个权限：`START_TASKS_FROM_RECENTS`、`com.android.camera.permission.MIPUSH_RECEIVE`、`com.miui.permission.HANG_UP_CHANGED`，全球版权限白名单可能记录/拒绝）。
  - `resetprop ro.miui.build.region=cn` 对系统其他组件的副作用（OTA/区域类服务/应用商店等），模块文档已警示并可通过 config 关闭。
  - 云端任务的服务端响应（设备白名单/权益/硬件认证）——**最大不确定项**。
  - `legend_mode` / `algorithm_monopan` 运行时 SDK 能否在非 CN 环境下载/加载。
- **新增风险（CN 侧分析发现）**：二次增强所依赖的**照片元数据**（`LegendMetaProto$M9Msg`：AISP_ISO/AWBGAIN/CCM/LSC/FACTOR/FACERECT/ALGOVERSION…）的**写入方不在任何已解出的 CN APK dex 内**（相机/ExtraPhoto 均无），推断在 native 相机管线或运行时下载的 legend 采集插件中；若该写入依赖服务端下发的插件，则即使相机 APK 替换成功，编辑器也可能不出现「二次增强」入口。
- **品牌名对照**：国行「徕卡一瞬」的同一资源 id 英文默认值为 **“Leica Essential”**，「传奇一瞬」为 **“Essential Moment”** —— 即国际版内部把该能力称为 Leica Essential；这解释了为何全球版 APK 中会预置相关代码与英文文案。

---

## 8. 附录

- 证据/中间文件：
  - `work/leica/global/analysis/`：APK 信息、dex 类/字符串清单、CN/global 差异、smali 证据、门禁判定解码。
  - `work/leica/cn/`：国行 APK、反编译产物、配置、`analysis/`。
  - `work/leica/docs/global_analysis.md`（国际版详细报告，241 行，含逐条 smali 引用）。
  - `work/leica/docs/cn_analysis.md`（国行侧报告）。
  - `work/leica/docs/research_web.md`（公开资料/价格/权益/社区先例，21 条来源）。
- 关键文件哈希：见 `work/leica/module/BUILD_INFO.md`。

---

## 9. 补充交付：LSPosed 模块（小米账号 Cookie + 编辑器门禁解锁）

除 Magisk 模块外，本项目另交付一个 **LSPosed 模块 APK**，用于更"外科手术式"地处理编辑器侧门禁与账号 Cookie（不改系统全局 region 属性、不替换 APK）。详细文档见 `docs/LSPOSED_MODULE.md`，APK 位于 `work/leica/lsposed/dist/`。

- **门禁绕过（进程级）**：在 `com.miui.mediaeditor` 进程内 hook `android.os.SystemProperties.get/getBoolean/getInt`，伪装 `ro.miui.build.region=cn`、`ro.theme_customize=LCC`、`ro.theme_leica=true`、`ro.boot.product.theme_customize=P1_Leica`、`ro.special_edition=true` → 使 `method_is_legend_available`（CN `rt.a.g() && ah0.b.g()` / 国际版 `mx.a.g() && r21.e.b()`）为真，且**不影响系统其它进程**。
- **Cookie 注入**：hook App 原生 STS Cookie 提供者 `go.e.b()`（CN 2.10.43.0.6）/ `bs.e.b()`（国际版 2.10.40）：原始逻辑为 `AccountManager.getAccountsByType("com.xiaomi")` → `getAuthToken("hyperos_sec_common")` → Bundle `stsCookies`；hook 用用户 Cookie 替换返回值，并同步写回其进程内静态缓存字段（`setStaticObjectField(target,"b",cookie)`；拦截器 `nm/f`/`jq/g` 在缓存非空时直接使用该字段）。
- **登录支持**：模块 UI 提供 ① WebView 登录抓取 Cookie；② 一键调起系统小米账号登录（`AccountManager.addAccount("com.xiaomi","passportapi")`）；③ 已登录时 App 原生取到的 STS Cookie 自动回传并回填复用。
- **未登录兜底**：上传步骤有客户端硬检查 `uploadFile: failed, not login`（`AccountUtil`：CN `ga0.e.a(Context)` / 国际版 `be0.e.a(Context)`）；模块仅在该检查返回空且已配置 Cookie 时，返回从 Cookie 的 `userId/cUserId` 解析出的账号标识（否则 `demo`）。
- **不做的事**：不强制通过 CTA 隐私协议（正常弹窗用户自己同意即可）；不伪造硬件认证 token；不绕过服务端权益/计费/设备白名单；云端 `signature` 由客户端内置 appSecret 计算，与 Cookie 无关，故无需/不应 hook。
- **验证**：APK 可复现构建（两次 sha256 一致）、apksigner v1+v2+v3 通过、`aapt2 dump badging` 正常、dex 内不打包 `de.robv.android.xposed` API 类、hook 目标均有两版 smali 证据；**无真机运行验证**，云端最终是否被服务端接受无法离线验证。
- **与 Magisk 模块共存**：两者可同时使用（Magisk 管相机 APK/属性；LSPosed 管编辑器进程门禁与 Cookie）。若两者都启用了门禁层，建议只保留一个（例如用 Magisk 模块装相机、用 LSPosed 做编辑器 + Cookie，并把 Magisk 的 `REGION_SPOOF` 关闭）。

## 10. HyperOS 4 的 Rust 组件及其影响（重要）

> 用户提示：HyperOS 4 中部分组件由 Rust 重写。本节为实际 ROM 验证结果与对移植策略的影响。

### 10.1 实测发现

- **系统级 Rust 运行时（大量）**：`/system_ext/lib64` 中有 **102 个** Rust 组件库，命名规则 `libhyper_os_<domain>_{public,private}.so`（如 `libhyper_os_account_*`、`libhyper_os_network_*`、`libhyper_os_app_*`、`libhyper_os_binder_*`、`libhyper_os_axml_*`、`libhyper_os_backup_*`、`libhyper_os_flutter.so` 等）；`/system/lib64` 还有 `libhyper_os_sys_cc_bindgen.dylib.so`、`libhyper_spawner_cc_bindgen.dylib.so`、大量 `lib*_rust.dylib.so`。
- **`hyperos.rustruntime.jar` 只是桩**：`/system_ext/framework/hyperos.rustruntime.jar` 大小仅 898 B，dex 中唯一类是 `Lrust/core/runtime/Empty;`——真实 Rust 运行时在 native 库中。
- **MIUIGallery = Flutter + Rust**：`MIUIGallery.apk` 内**没有 classes.dex**，逻辑在 `lib/arm64-v8a/libapp.so`（Dart AOT）+ `libapp_gallery.so`（36.5 MB Rust，`flutter_rust_bridge`，crate `app_gallery`，内部使用 `hyper_api` 与 `hyper 1.7.0` HTTP 客户端）。其中：
  - **能力探测在 Rust 中实现**：`src/api/front_end/media_editor_capability.rs` 通过 ContentProvider（authority `com.miui.mediaeditor.api`）调用 `method_request_function_list` / `method_is_legend_available` / `method_is_xm_legend_available` 等——Provider 运行在 mediaeditor（Java）进程，因此 LSPosed 对 mediaeditor 的 Java hook 仍然作用在真正的判定点上。
  - **能力结果有 SharedPreferences 缓存**：Rust 字符串含 `capabilities SP schema mismatch` / `Device capabilities cache invalidated` / `invalidate_device_capabilities_cache` → **开启模块后旧的“不可用”缓存可能仍生效，需要一次性清除相册数据/缓存**。
  - Gallery Rust 自身还读取 `IS_INTERNATIONAL_BUILD`、`VERSION.RELEASE`、`MIUI_VERSION`、`CUSTOMIZED_REGION`、`ro.miui.build.region`、`ro.product.mod_device`（经 Rust/JNI/MethodChannel 桥，`SystemPropertyMethodChannel`，channel `com.android.os.system.properties.method.channel`），并带有自己的 Rust `cloud_control` 策略。
- **mediaeditor（本次核心）**：legend 门禁/云端/Cookie 路径均为 Java（smali 已逐行确认），APK dex 中未发现 Rust/hyper 引用 → Java hook 与 Cookie 注入有效。
- **相机**：MiuiCamera 6.6/6.7 的 dex 未发现 Rust/hyper 引用；`/odm/etc/camera` 的徕卡滤镜参数由 HAL/native 侧处理，不受属性 hook 影响。

### 10.2 对移植策略的影响与对策

| 影响 | 对策 |
|---|---|
| Java（LSPosed）hook 只能覆盖 Java 侧；**Rust/native 读取系统属性不会经过 Java `SystemProperties`**（可能直接 `__system_property_get`） | 属性类门禁（`ro.theme_customize`/`ro.miui.build.region` 等）优先用 **Magisk resetprop 全局属性层**（本项目已有 PropsOnly 变体），它修改真实属性区，Rust/native 也会看到；Java 侧 hook 作为补充 |
| Gallery 能力缓存可能保留旧结果 | 启用后一次性 `设置→应用→相册→存储→清除数据`（或 `adb shell pm clear com.miui.gallery`，会清相册本地设置）再打开相册 |
| Gallery 内部 Rust 逻辑无法被 Xposed 覆盖（Dart/Rust 非 ART 方法） | 目标功能（legend 入口判定/legendV2 云端）实际判定点在 mediaeditor Java Provider + Java OkHttp，已被覆盖；如未来版本把 legend 调用迁入 Gallery Rust，则需改用 Magisk 属性层（甚至 native hook） |
| Gallery Rust 内置 hyper HTTP 客户端 | 当前 legendV2 云端调用在 mediaeditor Java（已确认）；若迁移，Java Cookie 注入将失效，需要重新评估 |
| LSPosed 模块对 gallery 进程新增 SystemProperties 伪装（v1.2.0） | 覆盖 gallery 中通过 Java/JNI 桥读取属性的路径；native 直读仍以 Magisk 属性层为准 |

> 结论：在 Rust 组件较多的 HyperOS 4 上，**属性类门禁以 Magisk resetprop 为可靠底座，LSPosed 模块负责 Java 侧判定（editor provider）与 Cookie 注入**；两者组合使用最稳。

> 免责声明：本项目仅用于个人设备上的本地 ROM 分析与自用修改；所有 ROM/APK 版权归小米/徕卡等权利人所有；请勿分发提取的商业 APK/资源，请勿用于绕过计费或权益。
