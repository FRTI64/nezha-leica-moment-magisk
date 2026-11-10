# Xiaomi 17 Ultra（nezha）国行「徕卡一瞬 / 二次增强」→ 国际版移植：Magisk 模块文档与源码

本仓库是 **Xiaomi 17 Ultra（codename `nezha`）** 上「徕卡一瞬（Leica Moment）／相册编辑·二次增强（云端处理）」功能的**静态逆向分析文档**，以及对应的 **Magisk 模块（属性层 + 国行相机 APK 载荷）源码**。

> 分析对象
> - 国行：`nezha_images_OS4.0.5.0.XPACNXM`（HyperOS 4 / Android 17）
> - 国际版：`nezha_global-ota_full-OS4.0.0.8.XPAMIXM` + 官方 `OS3.0.337.0.XPAMIXM` 线刷包骨架
>
> ⚠️ 本项目**仅供个人设备上的本地逆向研究与自用修改**，不包含任何官方 ROM/APK 二进制；不得用于绕过计费/服务端权益。Xiaomi / Leica / HyperOS 等商标与资源版权归权利人所有。**未在真机上测试**，刷机风险自负。

---

## 1. 结论摘要

| 问题 | 结论 |
|---|---|
| 功能是什么 | 相机端「徕卡一瞬」拍摄（端侧 M9 / M3+MONOPAN 50 等徕卡风格）+ 相册编辑（`com.miui.mediaeditor`）「二次增强」云端处理（云端图像大模型，5000 万像素级重处理）。 |
| 国际版缺代码吗 | **几乎不缺**。国际版 `com.miui.mediaeditor 2.10.40.4.8-global` 已包含完整 `LegendaryActivity/LegendaryViewModel/LegendaryJobManager`、`aigc.cloud.internal.legend.LegendCloudManager`、`Monopan*`、`LegendModeSdkLoader` 及 `api.open.ai.xiaomi.com/aiPhotoCloud/api/legendV2/{create,getResult,list}` 等云端代码与相同中文文案。 |
| 为什么默认看不到功能 | **门禁**：编辑器入口判定 `method_is_legend_available = (Build.DEVICE=="nezha" && ro.theme_customize=="LCC") && ro.miui.build.region=="cn"`；而徕卡 SKU 属性来自 `/odm/etc/nezha_5.x.prop`（由 bootloader `ro.boot.product.hardware_sku`+`ro.boot.hwversion` 在开机时选择导入），普通机不导入；国际版 `ro.miui.build.region=global`。 |
| 相机端能否只靠属性 | **不能完整实现**。国行 MiuiCamera 6.7.000280.0 独有徕卡版采集 UI/资源（`legend_ccd/cmos/bw`、35/75mm、M3/M9/M10R 模板/水印等），国际版 `resources.arsc` 中为 0 → 需替换国行相机 APK。 |
| APK 替换可行吗 | 可行：两国对应 APK 同一小米 MIUI 证书（SHA-256 `c9009d01…`），同签名可替换。 |
| 云端能移植成功吗 | **取决于服务端**：请求带小米账号 cookie、`Build.DEVICE`、`isLCC`、硬件认证 token；配额/点数/设备白名单在服务端。客户端模块只能打开入口，**无法授予服务端权益**，预期可能"入口出现但任务失败"。 |

---

## 2. 仓库结构

```
.
├── README.md                 本文件
├── docs/
│   ├── ANALYSIS.md           ★ 主分析报告（功能定位 / 门禁逆向 / 云端协议 / 移植方案与风险）
│   ├── cn_analysis.md        国行侧逆向报告（类/方法/smali/资源证据）
│   ├── global_analysis.md    国际版侧逆向 + CN/Global 差异 + 可行性判定
│   ├── research_web.md       公开资料/社区先例/Magisk 规范调研（含 21 条来源）
│   ├── MODULE_README.md      Magisk 模块完整说明书（原理/安装/卸载/配置/诊断/风险）
│   └── BUILD_INFO.md         构建与校验信息（输入 APK 哈希、模块文件清单、校验输出）
└── module_src/               Magisk 模块源码（不含 200MB 国行相机 APK 载荷）
    ├── build.sh              构建脚本（两个变体：PropsOnly / Full）
    ├── common/               模块公共文件（module.prop 模板、customize.sh、post-fs-data.sh、
    │                          service.sh、uninstall.sh、action.sh、diag.sh）
    └── BUILD_INFO.md         同 docs/BUILD_INFO.md
```

### Magisk 模块（两个变体）
| 变体 | 内容 | 用途 |
|---|---|---|
| `LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | 仅属性层（`resetprop -n` 注入 `ro.theme_customize=LCC`、`ro.theme_leica=true`、`ro.special_edition=true`，可选 `REGION_SPOOF=1` 将 `ro.miui.build.region` 伪装为 `cn`） | 先小步验证编辑器入口判定 |
| `LeicaMoment_nezha_v1.0.0_Full.zip` | 属性层 + 国行 `MiuiCamera.apk 6.7.000280.0`（magic mount 替换 `/product/priv-app/MiuiCamera/`，隐藏旧 oat，一次性 `pm clear com.android.camera`） | 补齐国行徕卡版采集 UI |

> 两个 zip 未在仓库内提供（Full 含约 200MB 商业 APK，不适合直接分发）：请在你自己的国行 ROM 解包目录下用 `module_src/build.sh` 重新构建；`module_src/BUILD_INFO.md` 记录了输入 APK 的 SHA-256 校验。模块源码中的 `README.md`（= `docs/MODULE_README.md`）说明了安装、开关（`/data/adb/leica_moment/config.env`）与回退方法。

---

## 3. 主要证据（详见 docs/）

- 门禁判定类（国际版）：`MediaEditorProviderForGallery` → `mx.a.g() && r21.e.b()`（`Build.DEVICE=="nezha"`、`ro.theme_customize=="LCC"`、`ro.miui.build.region=="cn"`），国行 2.10.43.0.6 语义相同（`rt.a.g() && ah0.b.g()`）。
- 云端协议：`https://api.open.ai.xiaomi.com/aiPhotoCloud/api/legendV2/{create,getResult,list}`、`/aiPhotoCloud/api/file/upload`、`/billing/*`、`/auth/v1/{hardwareAuthToken,hardwareNonce}`；请求 JSON 字段 `androidId/aperture/deviceName/deviceType/focusX/focusY/imgUrl/oaid/requestId`；返回 `taskId/deductType/points/counts`。
- 相机：国行 6.7.000280.0 独有 dex/资源清单；`/odm/etc/camera/leica_filter_param{,_m3,_m9_preview,_m9_snapshot}.bin`、`mialgo_monopan_cl.bin` 两国相同。
- 属性：`/odm/etc/nezha_5.x.prop`（11 个徕卡硬件版本，两国逐字节相同）→ `ro.theme_customize=LCC`、`ro.theme_leica=true`、`ro.special_edition=true`、`ro.product.odm.marketname=Xiaomi 17 Ultra by Leica` 等。

---

## 4. 特别注意：HyperOS 4 的 Rust 组件

HyperOS 4 有大量组件由 Rust 重写（`/system_ext/lib64` 中 102 个 `libhyper_os_*` 库、`libhyper_os_flutter.so`；`hyperos.rustruntime.jar` 只是 612 B 桩，真实运行时在 native）。本仓库的 `docs/ANALYSIS.md §10` 有实测证据与影响分析，关键结论：

- **属性类门禁（`ro.theme_customize` / `ro.miui.build.region`）优先用 Magisk resetprop 属性层**：它修改真实属性区，Rust/native 读取也能看到；Xposed Java hook 只能覆盖 Java 读取路径。
- 相册（`com.miui.gallery`）是 **Flutter + Rust**（`libapp.so` + 36.5 MB `libapp_gallery.so`，无 classes.dex）；其能力探测调用 mediaeditor Provider（Java，hook 有效），但结果会缓存在 SharedPreferences → 开启属性伪装后需**清除一次相册缓存/数据**。
- 相机/相册编辑的「徕卡一瞬」云端路径在当前版本仍是 Java（已逐行确认），不受 Rust 化影响。

## 5. 相关项目

- 同功能的 **LSPosed 模块源码**（进程级门禁伪装 + 小米账号 Cookie 登录/注入）：<https://github.com/FRTI64/nezha-leica-moment-lsposed>
- 两者可二选一或组合使用：Magisk 模块管相机 APK/属性；LSPosed 模块管编辑器进程门禁 + Cookie。

---

## 6. 免责声明

- 本仓库内容为**本地 ROM 静态分析结果**，所有类名/字符串/端点均来自用户自有 ROM 解包与反编译；不提供、不分发任何官方 ROM/APK/商业资源。
- 不提供任何服务端权益、计费、设备白名单或硬件认证的绕过；云端功能是否可用由 Xiaomi 服务端决定。
- 刷机/改机可能导致设备异常、数据丢失、保修失效；请自行评估风险。
- Xiaomi、Leica、HyperOS、MIUI 等名称与相关资源版权归其各自权利人所有；本项目与 Xiaomi/Leica 无任何关联。
