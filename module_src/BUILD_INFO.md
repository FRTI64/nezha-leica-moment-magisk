# BUILD_INFO — Leica Moment Port (nezha) Magisk module

Build provenance, input hashes, per-variant file lists, commands and validation output for the
two flashable zips in `dist/`. Companion documents: `README.md` (usage/risks),
`../docs/ANALYSIS.md` (§5 cloud limits, §6 module design), `../docs/global_analysis.md`
(§4 gating predicates, §6 minimal payload).

* Build date: **2026-11-10 18:28–18:31 (Asia/Singapore)**
* Workspace: `/mnt/d/Users/FRTI64/Downloads/nezha` (WSL2, DrvFs `/mnt/d`)
* **No Android device attached**: this is a host-side build; validation is structural +
  static, not on-device (see README §3 / §6).

---

## 1. Artifacts

| Variant | Path | Size (bytes) | SHA-256 |
|---|---|---|---|
| PropsOnly | `dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | 10,621 | `e17ccc6cb9ef1d49d61f9902728a381910837ced978060300d8cfab1a63ff7a1` |
| Full | `dist/LeicaMoment_nezha_v1.0.0_Full.zip` | 123,764,641 | `5b65908f66a9c9d2649624fdc6180624c8b04fd3b41b4fe35d734c02813d34c1` |

`dist/SHA256SUMS.txt`:

```
5b65908f66a9c9d2649624fdc6180624c8b04fd3b41b4fe35d734c02813d34c1  LeicaMoment_nezha_v1.0.0_Full.zip
e17ccc6cb9ef1d49d61f9902728a381910837ced978060300d8cfab1a63ff7a1  LeicaMoment_nezha_v1.0.0_PropsOnly.zip
```

Both zips: `unzip -tq` → "No errors detected"; `check_module.py` → **PASS, 0 errors,
0 warnings**. Dist total ~124 MB (budget: <600 MB for the two zips); full workspace module
directory (sources + payload + zips) is ~310 MB.

Module identity (same id for both variants — flash one):

```
id=nezha_leica_moment
name=Leica Moment Port (nezha)
version=1.0.0-propsonly   (PropsOnly)  |  1.0.0-full   (Full)
versionCode=10000
author=nezha-re
```

---

## 2. Inputs

### 2.1 ROM baselines

| ROM | Version | Device | Role |
|---|---|---|---|
| Global (port target) | `OS4.0.0.8.XPAMIXM` (Android 17) | `nezha_global` / `ro.product.mod_device=nezha_global` | partition dumps in `work/dump/`; gating analysis |
| CN (feature source) | `OS4.0.5.0.XPACNXM` | `nezha` | CN `MiuiCamera.apk` payload extracted from `product` partition |

### 2.2 Camera APKs

| Input | Path | Size (bytes) | SHA-256 | Package / version |
|---|---|---|---|---|
| **CN MiuiCamera (payload)** | `work/leica/cn/apps2/MiuiCamera.apk` | 200,627,029 | `4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63` | `com.android.camera` 6.7.000280.0 / vc 670002800, minSdk 29 / targetSdk 36, signed v2+v3 |
| Global MiuiCamera (replaced, reference) | `work/leica/global/apps/MiuiCamera.apk` | 196,825,964 | `7344e25d2578450344822c02ed336d1d6cbdddd1a1782fd1d4eeb257f87eae7a` | `com.android.camera` 6.6.000570.5 / vc 660005705, same signer |

Signer certificate (both APKs, verified from `META-INF/CERT.RSA` + androguard):
`sha256 c9009d01ebf9f5d0302bc71b2fe9aa9a47a432bba17308a3111b75d7b2149025`
(`CN=MIUI, O=Xiaomi, OU=MIUI, C=CN`, serial `E552A8ECB9011B7C`) ⇒ same-signer system-APK
replacement is valid.

Old ART artifacts hidden by the Full variant (`REMOVE`), from the global
`work/dump/product.img`: `/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.odex` 295,768 B,
`/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.vdex` 47,645,728 B (compiled for the global
6.6 APK). `/product/priv-app/MiuiCamera/MiuiCamera.apk` in the global image: 196,825,964 B.

The CN camera APK contains its native libraries in `lib/arm64-v8a/` (49 entries, e.g.
`libCameraToolJNI.so`, `libMiFilterSDK.so`, `libcamera_yuv_jni.so`) and 11 `classes*.dex`;
it is self-contained for the capture-side code.

### 2.3 Magisk module tooling inputs (read-only)

| Input | Path | Size | SHA-256 |
|---|---|---|---|
| Official `update-binary` (`module_installer.sh`) | `work/leica/module_skel/META-INF/com/google/android/update-binary` | 612 | `bcf4b1d9913f3af17755569c853e0b5a75b8005f6a18eb3f86dadcc0e968c29d` |
| `updater-script` (`#MAGISK`) | `work/leica/module_skel/META-INF/com/google/android/updater-script` | 8 | `d2b8203193a083e43ad076fde01b9c7821e0aa521e1f8077b8628fb1cdb70c60` |

---

## 3. Source tree / build tooling

```
work/leica/module/
├── build.sh                          # assembles both variants, builds + verifies + validates
├── smoke_test.sh                     # offline script-logic tests (stubbed Android commands)
├── common/                           # source of truth for shared module files
│   ├── module.prop.tmpl              #   version/module.prop template (variant substituted)
│   ├── customize.sh post-fs-data.sh service.sh uninstall.sh action.sh diag.sh README.md
├── src/PropsOnly/                    # generated complete Magisk module root (props only)
├── src/Full/                         # generated complete Magisk module root (+ CN APK)
└── dist/                             # flashable zips + SHA256SUMS.txt
```

| Tooling file | Size | SHA-256 |
|---|---|---|
| `build.sh` | 6,348 | `08010e35fd682d0bb73383c079c47b819d499a836c3987419ac9f1386b86ad75` |
| `smoke_test.sh` | 9,827 | `d440ac0a8a1d4b4d7c869ad1a78629e8d12b61e1a2e67cf966207bfdf3d60a13` |
| `common/README.md` (module README, in zip) | 2,071 | `8560803f2c48f3a844afa19c7dd968952b06f64a99af6e1a7538a363c586957b` |
| `common/action.sh` | 783 | `f928dd3bd88a173a707c79c8c5b9f029620a9bde49b81fccdc8acdbb860df96c` |
| `common/customize.sh` | 2,228 | `db5fab833b61eeb3a0b1c20122e88c8fd1984e9f4a01b1e9ac1dc2d7b4e2ac9f` |
| `common/diag.sh` | 3,756 | `38f0edd73a779d0390763a69f670872225d01afb084a9225fede30f326989a31` |
| `common/module.prop.tmpl` | 295 | `e2b1d5cd9d4829c050c29d7eef6d0f10e2a2cbc9602d55c375d19490bd6fe837` |
| `common/post-fs-data.sh` | 5,216 | `0e9b2e4814298e0dda4800ec119d3247ca10ab7d3cac3b5560563802dff12571` |
| `common/service.sh` | 4,309 | `b699b10577c276d4e79073236c56b0b1cea008ac8cb9ec7fad86bc43a8890584` |
| `common/uninstall.sh` | 613 | `59702867a12e6ad6dee64f6c0c600e95e29c01d985c0e9346bac2bafcaa3258b` |

Build environment: WSL2 (Linux `6.18.58.1-microsoft-standard-WSL2`, x86_64), GNU bash 5.3.20,
Info-ZIP `zip` 3.0 / `unzip` 6.00, Python 3.14.9, workspace on DrvFs (`/mnt/d`, uid 1000,
no root). No device, no adb target.

---

## 4. Per-variant file lists

### 4.1 `LeicaMoment_nezha_v1.0.0_PropsOnly.zip` — 14 entries / 10 files

| Entry | Size (bytes) | SHA-256 (source file) |
|---|---|---|
| `META-INF/com/google/android/update-binary` | 612 | `bcf4b1d9913f3af17755569c853e0b5a75b8005f6a18eb3f86dadcc0e968c29d` |
| `META-INF/com/google/android/updater-script` | 8 | `d2b8203193a083e43ad076fde01b9c7821e0aa521e1f8077b8628fb1cdb70c60` |
| `README.md` | 2,071 | `8560803f2c48f3a844afa19c7dd968952b06f64a99af6e1a7538a363c586957b` |
| `action.sh` | 783 | `f928dd3bd88a173a707c79c8c5b9f029620a9bde49b81fccdc8acdbb860df96c` |
| `customize.sh` | 2,228 | `db5fab833b61eeb3a0b1c20122e88c8fd1984e9f4a01b1e9ac1dc2d7b4e2ac9f` |
| `diag.sh` | 3,756 | `38f0edd73a779d0390763a69f670872225d01afb084a9225fede30f326989a31` |
| `module.prop` | 288 | `27fe82b4fe824cfb6317bb3d38ccf0e1fd4c8ba57f59eb1b12aa7761347ca4c4` |
| `post-fs-data.sh` | 5,216 | `0e9b2e4814298e0dda4800ec119d3247ca10ab7d3cac3b5560563802dff12571` |
| `service.sh` | 4,309 | `b699b10577c276d4e79073236c56b0b1cea008ac8cb9ec7fad86bc43a8890584` |
| `uninstall.sh` | 613 | `59702867a12e6ad6dee64f6c0c600e95e29c01d985c0e9346bac2bafcaa3258b` |

Directory entries: `META-INF/`, `META-INF/com/`, `META-INF/com/google/`,
`META-INF/com/google/android/`. No `system/` payload (props-only variant).

### 4.2 `LeicaMoment_nezha_v1.0.0_Full.zip` — 19 entries / 11 files

Same files as PropsOnly except `module.prop` (283 B,
sha256 `fcd952cab6b7a856fc664215a4ded876c361afdd983a2ef107b0eed461f798d5`,
`version=1.0.0-full`), plus the payload:

| Entry | Size (bytes) | SHA-256 |
|---|---|---|
| `system/product/priv-app/MiuiCamera/MiuiCamera.apk` | 200,627,029 | `4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63` |

Directory entries: `META-INF/...`, `system/`, `system/product/`, `system/product/priv-app/`,
`system/product/priv-app/MiuiCamera/`.

`unzip -p ... system/product/priv-app/MiuiCamera/MiuiCamera.apk | sha256sum` on the built zip
**matches the pinned CN APK hash** (verified automatically by `build.sh` on every build).
Script modes in both zips: `-rwxr-xr-x` for `update-binary` and all `*.sh`, `-rw-r--r--` for
payload/module.prop, `drwxr-xr-x` for directories.

---

## 5. How the zips were built

```sh
cd /mnt/d/Users/FRTI64/Downloads/nezha/work/leica/module

./build.sh all         # both variants (default)
./build.sh propsonly   # only the props layer
./build.sh full        # only the Full variant (copies the 200 MB CN APK)
```

`build.sh` per variant:

1. `rm -rf src/<Variant>` and assemble a complete Magisk module root from `common/` plus the
   official `META-INF/` files copied from `work/leica/module_skel/`; `module.prop` is generated
   from `common/module.prop.tmpl` with `version=1.0.0-<variant>` / `versionCode=10000`.
2. Full only: copy `work/leica/cn/apps2/MiuiCamera.apk` to
   `src/Full/system/product/priv-app/MiuiCamera/MiuiCamera.apk`, verify size (200,627,029) and
   SHA-256 against the pinned value, then `sync` (DrvFs write flush).
3. Package + validate with the pre-existing tooling
   `work/leica/scripts/build_module.sh src/<Variant> dist/<name>.zip`
   (META-INF first, no wrapper dir, unix modes normalized, `unzip -t` integrity test, and
   `check_module.py` structural validation).
4. Full only: verify the payload **inside the produced zip** (`unzip -p ... | sha256sum`
   against `4637b77d…`); on mismatch, retry the packaging once (DrvFs transient-short-read
   guard, see §7) and fail the build if it persists.
5. Regenerate `dist/SHA256SUMS.txt` (with retries) and print final sizes/hashes.

The zips are not byte-reproducible (zip timestamps/ordering may vary); provenance is pinned by
the CN APK SHA-256, the tooling file hashes in §3 and the artifact hashes in §1.

---

## 6. Validation output

### 6.1 `check_module.py` — PropsOnly

```
  INFO  input: .../dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip (zip)
  INFO  entries: 14 (10 files)
  INFO  top-level entries: META-INF, README.md, action.sh, customize.sh, diag.sh, module.prop, post-fs-data.sh, service.sh, uninstall.sh
  INFO  no payload files under system/ (empty skeleton / test module)
  INFO  update-binary is byte-identical to Magisk's official module_installer.sh
  INFO  both post-fs-data.sh and service.sh present: only use post-fs-data if needed
  INFO  zip: 14 entries, 0.02 MiB uncompressed
check_module: PASS -- 0 error(s), 0 warning(s) -- .../dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip
```

### 6.2 `check_module.py` — Full

```
  INFO  input: .../dist/LeicaMoment_nezha_v1.0.0_Full.zip (zip)
  INFO  entries: 19 (11 files)
  INFO  top-level entries: META-INF, README.md, action.sh, customize.sh, diag.sh, module.prop, post-fs-data.sh, service.sh, system, uninstall.sh
  INFO  update-binary is byte-identical to Magisk's official module_installer.sh
  INFO  both post-fs-data.sh and service.sh present: only use post-fs-data if needed
  INFO  zip: 19 entries, 191.35 MiB uncompressed
check_module: PASS -- 0 error(s), 0 warning(s) -- .../dist/LeicaMoment_nezha_v1.0.0_Full.zip
```

### 6.3 Additional host-side checks

* `unzip -tq` both zips → `No errors detected in compressed data`.
* `sh -n` on every packaged script (both variants, 12 files) → all OK; no CRLF; no
  `/data/adb/modules/...` hard-coded module paths inside scripts (uses `MODDIR=${0%/*}`).
* Payload-in-zip SHA-256 verification (Full) → `4637b77d…` (matches input).
* `./smoke_test.sh` (offline logic test with stubbed `getprop`/`resetprop`/`stat`/`dumpsys`/
  `am`/`pm`/`sleep`) → **PASS**, 9 groups:
  1. `customize.sh` declares `REMOVE=/system/product/priv-app/MiuiCamera/oat` for Full only;
  2. post-fs-data applies the default props incl. `ro.special_edition`,
     `camera.debug.safe.check.disable` (Full) and `ro.miui.build.region=cn`;
  3. PropsOnly applies props without the camera debug prop;
  4. config toggles OFF (incl. CRLF config) disable theme/region props as expected;
  5. PropsOnly `service.sh` does nothing;
  6. Full `service.sh` runs `am force-stop` + `pm clear` once, writes the guard file, does not
     repeat on the next boot;
  7. Full `service.sh` does **not** clear data when the on-device APK size does not match
     (module payload inactive);
  8. app-store (`/data/app`) camera update is detected and a `cmd package uninstall-system-updates`
     hint is logged;
  9. `action.sh`/`diag.sh` produce `/data/adb/leica_moment/diag.log` with module/props/config/
     payload/package/version/log sections and print the diag path.

---

## 7. Known build-environment caveat (transparency)

During one intermediate rebuild the CN APK was transiently read short by the packaging chain on
DrvFs (`/mnt/d`): the zip entry recorded 131,170,304 B instead of 200,627,029 B even though the
source copy on disk had the correct size and SHA-256. This was caught by the payload-in-zip
verification and the artifact was rebuilt; it was not shipped. Mitigations now in `build.sh`:

* `sync` after the 200 MB copy, before packaging;
* mandatory SHA-256 verification of the payload **inside** the built Full zip;
* one automatic packaging retry, build failure if the hash still mismatches;
* retried `sha256sum` when writing `SHA256SUMS.txt` (the same transient I/O/memory pressure was
  once seen there).

The artifacts in §1 were built with these guards in place and their in-zip payload hash was
verified twice (build-time guard + manual re-check).

---

## 8. What was NOT verified (no device)

No on-device test was possible. The following remain unverified and are discussed in
`README.md` §3/§9: runtime compatibility of the CN MiuiCamera build on the global ROM
(camera framework/HAL), `resetprop` region side effects, server-side acceptance/entitlement of
the cloud re-render job (`hardwareAuthToken`, `lcc_support_devices`/`leica_support_devices`,
quota), the runtime `legend_mode`/`algorithm_monopan` SDK downloads, and privileged-permission
allowlist interactions for the CN camera APK.

---

## 9. Source references

* `../docs/ANALYSIS.md` — overall synthesis (§5 cloud flow/limits, §6 chosen module design and
  variants, §7 verification status).
* `../docs/global_analysis.md` — detailed evidence: §2 version/signer table, §3 CN-vs-global
  code/resource presence, §4 exact gating predicates + cloud job-time checks, §5 props/config
  delta, §6 minimal payload + risk register.
* `../docs/research_web.md` — public web prior art / community reports.
* `../tools/README_tooling.md` §4 — Magisk module rules, mountable partitions, official
  `update-binary`, skeleton/build/validate tooling.
* Official Magisk docs: guides <https://topjohnwu.github.io/Magisk/guides.html>, tools
  (`resetprop -n`) <https://topjohnwu.github.io/Magisk/tools.html>, module installer /
  `REMOVE` semantics
  <https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh>,
  mountable partitions
  <https://github.com/topjohnwu/Magisk/blob/master/native/src/core/module.rs>.
* Evidence files: `work/leica/global/analysis/` (APK info/signers, dex strings, smali evidence
  for `method_is_legend_available`, `LegendCloudManager`, CTA/hardware-auth references),
  `work/leica/cn/` (CN APKs + decompiled evidence), `work/dump/` (global partition images).
