# nezha-leica-moment-magisk

**Xiaomi 17 Ultra（`nezha`）国行「徕卡一瞬 / 二次增强」→ 国际版移植：逆向分析文档 + Magisk 相机载荷（无属性伪装）**

> 用户要求：**不使用伪装系统属性的方式**。因此本项目推荐的 Magisk 产物是 **`CameraOnly`**（只挂载国行相机 APK，**不设置任何系统属性**）；功能门禁改由同组织仓库的 **LSPosed 模块**通过直接方法 hook 完成。旧 `PropsOnly`/`Full`（resetprop 属性层）仅作参考保留，**已弃用**。

- 分析对象：国行 `nezha_images_OS4.0.5.0.XPACNXM`（HyperOS 4 / Android 17）与国际版 `nezha_global-ota_full-OS4.0.0.8.XPAMIXM`。
- 免责声明：仅个人设备本地逆向研究与自用修改；**不包含/不分发**官方 ROM/APK 二进制；不提供计费/权益/硬件认证绕过；未真机验证；Xiaomi/Leica/HyperOS 商标与资源版权归权利人所有。

---

## 1. 结论摘要

| 问题 | 结论 |
|---|---|
| 神秘功能 | 相机端「徕卡一瞬」拍摄（端侧 M9/M3+MONOPAN 风格）+ 相册编辑 `com.miui.mediaeditor`「二次增强」云端处理（云端大模型重处理）。 |
| 国际版缺代码吗 | **几乎不缺**：国际版 mediaeditor 已含完整 `LegendaryActivity/ViewModel/JobManager`、`LegendCloudManager`、`Monopan*`、`LegendModeSdkLoader` 与 `api.open.ai.xiaomi.com/aiPhotoCloud/api/legendV2/*` 端点及相同中文文案。 |
| 为什么默认不可见 | **门禁**：编辑器 `method_is_legend_available = Build.DEVICE=="nezha" && ro.theme_customize=="LCC" && ro.miui.build.region=="cn"`；徕卡 SKU 属性来自 `/odm/etc/nezha_5.x.prop`（bootloader 选择导入），普通机/国际版不满足。 |
| 相机端差异 | 国行 MiuiCamera 6.7.000280.0 独有徕卡版采集 UI/资源；国际版 6.6 缺失 → 需替换国行相机 APK（**无需改属性**，UI 可见性由 LSPosed 直接 hook 相机判定方法完成）。 |
| 云端能成功吗 | **取决于服务端**：请求携带小米账号 cookie、`Build.DEVICE`、`isLCC`、硬件认证 token，配额/白名单在服务端；客户端只能打开入口。 |
| 属性伪装？ | **本项目 v2 起不使用**：LSPosed 直 hook 判定方法；Magisk CameraOnly 零属性改动。 |

---

## 2. 仓库结构

```
.
├── README.md
├── docs/
│   ├── ANALYSIS.md          ★ 主分析（含 §10 HyperOS 4 Rust 组件、§11 无属性伪装方案）
│   ├── cn_analysis.md       国行侧逆向（类/方法/smali/资源证据）
│   ├── global_analysis.md   国际版侧逆向 + CN/Global 差异 + 可行性
│   ├── research_web.md      公开资料/社区先例/Magisk 规范（21 条来源）
│   ├── MODULE_README.md     Magisk 模块说明（三个变体，CameraOnly 推荐）
│   ├── BUILD_INFO.md        构建与校验信息（含 no-props 强制校验证据）
│   └── camera_hook_targets.md 相机「无属性伪装」hook 逆向报告（CN MiuiCamera 6.7，11 dex）
└── module_src/              Magisk 模块源码（不含 200MB 商业 APK 载荷）
    ├── build.sh             构建三个变体（含 CameraOnly + no-props 强制校验）
    ├── common/              模块公共文件；common/cameraonly/ 为无属性变体脚本
    ├── README.md / BUILD_INFO.md
```

> Magisk 模块 zip 未入库（CameraOnly 含约 200MB 商业相机 APK）：请从你自己的国行 ROM 提取 `MiuiCamera.apk` 并用 `module_src/build.sh cameraonly` 重建。

---

## 3. 三个 Magisk 变体

| 变体 | 属性改动 | 内容 | 状态 |
|---|---|---|---|
| **`LeicaMoment_nezha_v1.2.0_CameraOnly.zip`** | **无（零 resetprop）** | 仅挂载国行 MiuiCamera 6.7 APK + 隐藏旧 oat + 一次性清相机数据；post-fs-data 为空操作 | ✅ **推荐**（配 LSPosed 相机 hook） |
| `LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | resetprop 属性层 | 只注入 `ro.theme_customize=LCC`、`ro.theme_leica=true` 等（可选 region） | ❌ 已弃用（属性伪装） |
| `LeicaMoment_nezha_v1.0.0_Full.zip` | resetprop + APK | 属性层 + 国行相机 APK | ❌ 已弃用（属性伪装） |

- CameraOnly 构建时由 `build.sh` 强制校验 zip 内非 APK 文件不含 `resetprop`/属性键，校验失败即中止构建。
- 相机 APK 载荷哈希固定校验：`4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63`。
- 编辑器路径**不需要 Magisk 模块**（仅 LSPosed 即可）。

---

## 4. 相关项目

- **LSPosed 模块源码（无属性伪装：编辑器官网门禁 + 小米账号 Cookie 登录/注入 + 相机模式 hook）**：<https://github.com/FRTI64/nezha-leica-moment-lsposed>
- 推荐组合：Magisk `CameraOnly`（只提供国行相机 APK）+ LSPosed v2.1+（直接方法 hook，scope `com.miui.mediaeditor` + `com.android.camera`）。

---

## 5. HyperOS 4 Rust 组件注意

`/system_ext/lib64` 有 102 个 `libhyper_os_*` Rust 库；`hyperos.rustruntime.jar` 是 612 B 桩；相册 `com.miui.gallery` 为 Flutter+Rust（`libapp.so` Dart AOT + 36.5 MB `libapp_gallery.so`，无 classes.dex）。详见 `docs/ANALYSIS.md §10`。

- LSPosed 无法 hook Dart/Rust/native；但本方案**不再依赖属性伪装**，因此 Rust native 属性读取不影响目标功能——判定点均在 Java（mediaeditor Provider / camera Java 判定方法），直接 hook 即可。
- 相册会把能力探测结果缓存到 SharedPreferences → 首次启用后需清除一次相册缓存/数据。

---

## 6. 免责声明

本仓库仅包含逆向分析文档与自研 shell/Java 脚本，不包含官方 ROM/APK/商业资源；不提供计费、权益、设备白名单或硬件认证绕过；与 Xiaomi/Leica 无关联；刷机风险自负。
