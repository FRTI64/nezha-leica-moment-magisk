# Magisk 模块源码（不含 APK 载荷）

本目录是 Magisk 模块的构建源码，**不包含**约 200MB 的国行 `MiuiCamera.apk` 载荷（商业 APK，不适合分发；请从你自己的国行 ROM 中提取）。

结构：

```
build.sh          构建两个变体：LeicaMoment_<ver>_PropsOnly.zip / LeicaMoment_<ver>_Full.zip
common/           模块公共文件（构建时复制进两个变体）
  module.prop.tmpl  模块描述模板（__VERSION__/__VERSION_CODE__ 由 build.sh 替换）
  customize.sh      安装时脚本：Full 变体 REMOVE 旧相机 oat；权限设置
  post-fs-data.sh   resetprop -n 属性层（LEICA_SKU_PROPS / REGION_SPOOF 开关）
  service.sh        late_start：一次性 pm clear com.android.camera + force-stop（带守卫文件）
  uninstall.sh      卸载清理
  action.sh/diag.sh Magisk 动作按钮 → /data/adb/leica_moment/diag.log 诊断
  README.md         模块说明
BUILD_INFO.md     输入 APK SHA-256、模块文件清单、校验输出
```

构建前提（工具链与本项目无关，可用官方 Magisk 模块模板工具）：

- 将国行相机 APK 放到 `work/leica/cn/apps2/MiuiCamera.apk`（按 `build.sh` 中的 `APK_SRC` 路径调整），SHA-256 必须等于 `BUILD_INFO.md` 中记录的 `4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63`（build.sh 会强制校验）。
- `build.sh` 依赖同项目 `scripts/build_module.sh`（aapt2/d8 之外无外部依赖；META-INF 的官方 update-binary 来自 Magisk 官方模板）。

用法：`./build.sh all`（或 `propsonly` / `full`），产物在 `dist/`。

模块运行时配置：`/data/adb/leica_moment/config.env`（`REGION_SPOOF` / `LEICA_SKU_PROPS` / `CLEAR_CAMERA_DATA`），日志在 `/data/adb/leica_moment/module.log`。

风险与限制见 `../docs/MODULE_README.md`（= 模块 README）与 `../docs/ANALYSIS.md`。
