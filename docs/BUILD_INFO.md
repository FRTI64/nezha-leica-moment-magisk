# BUILD_INFO — Leica Moment Port (nezha) Magisk modules

Build provenance, input hashes, per-variant file lists, commands and validation output for the
three flashable zips in `dist/`, including the **no-property-spoofing** CameraOnly variant
requested by the user (「不想通过伪装属性的方式使用」).

* Build date: **2026-11-11 00:17–00:20 (Asia/Singapore)**
* Workspace: `/mnt/d/Users/FRTI64/Downloads/nezha` (WSL2, DrvFs `/mnt/d`)
* **No Android device attached**: host-side build; validation is structural + static, not
  on-device (see README §4/§11).
* Companion documents: `README.md` (usage/risks), `../docs/ANALYSIS.md`,
  `../docs/LSPOSED_MODULE.md` (no-props gating module),
  `../docs/global_analysis.md` (detailed evidence).

---

## 1. Artifacts

| Variant | Path | Size (bytes) | SHA-256 | Prop spoofing | Entries |
|---|---|---|---|---|---|
| **CameraOnly (RECOMMENDED)** | `dist/LeicaMoment_nezha_v1.2.0_CameraOnly.zip` | 123,763,526 | `c480b5bfeec5f47ee623f48ee91a68bcbcbfb9dc1fb84f1751dd728616a6d8a3` | **none** | 19 (11 files) |
| PropsOnly (DEPRECATED) | `dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip` | 10,804 | `52da6460fadca65b55bc68b484a21777240289a1e1a57a84bd086bd0e14f8910` | yes (`resetprop`) | 14 (10 files) |
| Full (DEPRECATED) | `dist/LeicaMoment_nezha_v1.0.0_Full.zip` | 123,764,824 | `c6a58d2a51fe5f7c3ca8a4854017019327aa74177779f243aea5f49480ef1303` | yes (`resetprop`) | 19 (11 files) |

`dist/SHA256SUMS.txt`:

```
c6a58d2a51fe5f7c3ca8a4854017019327aa74177779f243aea5f49480ef1303  LeicaMoment_nezha_v1.0.0_Full.zip
52da6460fadca65b55bc68b484a21777240289a1e1a57a84bd086bd0e14f8910  LeicaMoment_nezha_v1.0.0_PropsOnly.zip
c480b5bfeec5f47ee623f48ee91a68bcbcbfb9dc1fb84f1751dd728616a6d8a3  LeicaMoment_nezha_v1.2.0_CameraOnly.zip
```

All three zips: `sha256sum -c SHA256SUMS.txt` OK and `unzip -tq` "No errors detected".
`check_module.py` → **PASS, 0 errors, 0 warnings** for every zip (§6). Total dist size
~247.5 MB (budget: <600 MB total). The module directory (3 generated variant trees + zips) is
~619 MB.

Module identity (all variants share module id `nezha_leica_moment`; flash one — another variant
replaces it):

| Variant | name | version | versionCode | note |
|---|---|---|---|---|
| CameraOnly | `Leica Moment Port (nezha) - CameraOnly` | `1.2.0-cameraonly` | 12000 | no property changes |
| PropsOnly | `Leica Moment Port (nezha)` | `1.0.0-propsonly` | 10000 | DEPRECATED (property injection) |
| Full | `Leica Moment Port (nezha)` | `1.0.0-full` | 10000 | DEPRECATED (property injection) |

---

## 2. No-props contract (CameraOnly) — enforcement and evidence

CameraOnly changes exactly one thing on the device: it magic-mounts the CN `MiuiCamera.apk`
over `/product/priv-app/MiuiCamera/MiuiCamera.apk`, hides the stale ART `oat` artifacts, and
clears camera app data once after verifying the swap. It makes **no system-property changes**.

* `post-fs-data.sh` (in the zip) is a no-op: it only appends one boot-marker line to
  `/data/adb/leica_moment/module.log`; it does not create the deprecated variants'
  `config.env` property layer.
* There is no `resetprop`/`setprop`/`SystemProperties` usage in any script, and no property
  name of the deprecated variants appears in any non-APK zip entry.
* **Enforced at build time** (`build.sh` → `verify_no_props()`): after packaging, every
  non-APK entry of the CameraOnly zip is grepped for `resetprop`, `ro.theme_customize` and
  `ro.miui.build.region`; the build aborts if any match. Build log line:

  ```
  build: no-props verification PASS: no 'resetprop' and no spoofed property names in any non-APK entry
  ```

* Independent post-build evidence (extract zip, grep all non-APK files; also `setprop` /
  `SystemProperties` as an extra check) — **no matches**:

  ```
  $ unzip -q LeicaMoment_nezha_v1.2.0_CameraOnly.zip -d .audit
  $ grep -rnE 'resetprop|ro\.theme_customize|ro\.miui\.build\.region' .audit --exclude='*.apk'
  RESULT: no matches -- PASS
  $ grep -rnE 'setprop|SystemProperties' .audit --exclude='*.apk'
  RESULT: no matches -- PASS
  ```

The only runtime package-manager actions are the data hygiene calls required after an APK swap
(`am force-stop com.android.camera`, `pm clear com.android.camera`, once, guarded), which do not
touch properties.

---

## 3. Inputs

### 3.1 ROM baselines

| ROM | Version | Device | Role |
|---|---|---|---|
| Global (port target) | `OS4.0.0.8.XPAMIXM` (Android 17) | `nezha_global` / `ro.product.mod_device=nezha_global` | partition dumps in `work/dump/`; gating analysis |
| CN (feature source) | `OS4.0.5.0.XPACNXM` | `nezha` | CN `MiuiCamera.apk` payload extracted from `product` partition |

### 3.2 Camera APKs

| Input | Path | Size (bytes) | SHA-256 | Package / version |
|---|---|---|---|---|
| **CN MiuiCamera (payload)** | `work/leica/cn/apps2/MiuiCamera.apk` | 200,627,029 | `4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63` | `com.android.camera` 6.7.000280.0 / vc 670002800, minSdk 29 / targetSdk 36, signed v2+v3 |
| Global MiuiCamera (replaced, reference) | `work/leica/global/apps/MiuiCamera.apk` | 196,825,964 | `7344e25d2578450344822c02ed336d1d6cbdddd1a1782fd1d4eeb257f87eae7a` | `com.android.camera` 6.6.000570.5 / vc 660005705, same signer |

Signer certificate (both APKs, verified from `META-INF/CERT.RSA` + androguard):
`sha256 c9009d01ebf9f5d0302bc71b2fe9aa9a47a432bba17308a3111b75d7b2149025`
(`CN=MIUI, O=Xiaomi, OU=MIUI, C=CN`, serial `E552A8ECB9011B7C`) ⇒ same-signer system-APK
replacement is valid.

Old ART artifacts hidden by the payload variants (`REMOVE`), from the global
`work/dump/product.img`: `/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.odex` 295,768 B,
`/product/priv-app/MiuiCamera/oat/arm64/MiuiCamera.vdex` 47,645,728 B (compiled for the global
6.6 APK). `/product/priv-app/MiuiCamera/MiuiCamera.apk` in the global image: 196,825,964 B.

### 3.3 Magisk module tooling inputs (read-only)

| Input | Path | Size | SHA-256 |
|---|---|---|---|
| Official `update-binary` (`module_installer.sh`) | `work/leica/module_skel/META-INF/com/google/android/update-binary` | 612 | `bcf4b1d9913f3af17755569c853e0b5a75b8005f6a18eb3f86dadcc0e968c29d` |
| `updater-script` (`#MAGISK`) | `work/leica/module_skel/META-INF/com/google/android/updater-script` | 8 | `d2b8203193a083e43ad076fde01b9c7821e0aa521e1f8077b8628fb1cdb70c60` |

---

## 4. Source tree / build tooling

```
work/leica/module/
├── build.sh                          # assembles + builds + verifies + validates all variants
├── smoke_test.sh                     # offline script-logic tests (stubbed Android commands)
├── common/                           # shared module files (deprecated props variants)
│   ├── module.prop.tmpl              #   metadata template (name/version/description substituted)
│   ├── customize.sh post-fs-data.sh service.sh uninstall.sh action.sh diag.sh README.md
│   └── cameraonly/                   # CameraOnly-specific no-props scripts + README
├── src/CameraOnly/                   # generated complete Magisk module root (no props)
├── src/PropsOnly/                    # generated complete Magisk module root (deprecated props)
├── src/Full/                         # generated complete Magisk module root (deprecated props+APK)
└── dist/                             # flashable zips + SHA256SUMS.txt
```

| Tooling file | Size | SHA-256 |
|---|---|---|
| `build.sh` | 10,087 | `2e91bf8a59d5c8d3526a0740b3083c0d4538887f959e6e1634674459ae9b8471` |
| `smoke_test.sh` | 12,876 | `b02745cb9c491b12e343aad3523ed2dbddf3d2034f38bac33e2c0fcfccdd06a1` |
| `common/module.prop.tmpl` | 129 | `d1fa94a31b088e8cc43789c592367801bf9e9343ffdc186c912b8e7cdb6ed927` |
| `common/customize.sh` | 2,228 | `db5fab833b61eeb3a0b1c20122e88c8fd1984e9f4a01b1e9ac1dc2d7b4e2ac9f` |
| `common/post-fs-data.sh` | 5,216 | `0e9b2e4814298e0dda4800ec119d3247ca10ab7d3cac3b5560563802dff12571` |
| `common/service.sh` | 4,309 | `b699b10577c276d4e79073236c56b0b1cea008ac8cb9ec7fad86bc43a8890584` |
| `common/uninstall.sh` | 613 | `59702867a12e6ad6dee64f6c0c600e95e29c01d985c0e9346bac2bafcaa3258b` |
| `common/action.sh` | 783 | `f928dd3bd88a173a707c79c8c5b9f029620a9bde49b81fccdc8acdbb860df96c` |
| `common/diag.sh` | 3,756 | `38f0edd73a779d0390763a69f670872225d01afb084a9225fede30f326989a31` |
| `common/README.md` | 2,534 | `b466ad8593fc8fd2a19a68c6ba11b9a08abac8aed9b7390abcd22ac89ab58614` |
| `common/cameraonly/customize.sh` | 2,311 | `2b14e3ac4fbf0f544afbe24d64b91c9df841bfaf9bf7b5c5710815d5bb3785c3` |
| `common/cameraonly/post-fs-data.sh` | 834 | `4355163d0a37f3ca9486ea9e587564b0dee32b44585f66c8f216e31c622b3b47` |
| `common/cameraonly/diag.sh` | 3,740 | `9fea86fff705b24ea796c2dc4bae215721bc6297aed9bdd9c5c1505e16965178` |
| `common/cameraonly/README.md` | 2,939 | `3db91b358ae97f55a817f3ade0965b631e08463e8238181cbe80613d237700a9` |

Build environment: WSL2 (Linux `6.18.58.1-microsoft-standard-WSL2`, x86_64), GNU bash 5.3.20,
Info-ZIP `zip` 3.0 / `unzip` 6.00, Python 3.14.9, workspace on DrvFs (`/mnt/d`, uid 1000,
no root). No device, no adb target.

---

## 5. Per-variant file lists

### 5.1 `LeicaMoment_nezha_v1.2.0_CameraOnly.zip` — 19 entries / 11 files (RECOMMENDED, no-props)

| Entry | Size (bytes) | SHA-256 |
|---|---|---|
| `META-INF/com/google/android/update-binary` | 612 | `bcf4b1d9913f3af17755569c853e0b5a75b8005f6a18eb3f86dadcc0e968c29d` |
| `META-INF/com/google/android/updater-script` | 8 | `d2b8203193a083e43ad076fde01b9c7821e0aa521e1f8077b8628fb1cdb70c60` |
| `README.md` | 2,939 | `3db91b358ae97f55a817f3ade0965b631e08463e8238181cbe80613d237700a9` |
| `action.sh` | 783 | `f928dd3bd88a173a707c79c8c5b9f029620a9bde49b81fccdc8acdbb860df96c` |
| `customize.sh` | 2,311 | `2b14e3ac4fbf0f544afbe24d64b91c9df841bfaf9bf7b5c5710815d5bb3785c3` |
| `diag.sh` | 3,740 | `9fea86fff705b24ea796c2dc4bae215721bc6297aed9bdd9c5c1505e16965178` |
| `module.prop` | 333 | `79b47317a95caf5b8b9d2b789863d6f97b718d65a40089a5504da7b802735a4f` |
| `post-fs-data.sh` | 834 | `4355163d0a37f3ca9486ea9e587564b0dee32b44585f66c8f216e31c622b3b47` |
| `service.sh` | 4,309 | `b699b10577c276d4e79073236c56b0b1cea008ac8cb9ec7fad86bc43a8890584` |
| `uninstall.sh` | 613 | `59702867a12e6ad6dee64f6c0c600e95e29c01d985c0e9346bac2bafcaa3258b` |
| `system/product/priv-app/MiuiCamera/MiuiCamera.apk` | 200,627,029 | `4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63` |

Directory entries: `META-INF/`, `META-INF/com/`, `META-INF/com/google/`,
`META-INF/com/google/android/`, `system/`, `system/product/`, `system/product/priv-app/`,
`system/product/priv-app/MiuiCamera/`.

`unzip -p ... system/product/priv-app/MiuiCamera/MiuiCamera.apk | sha256sum` on the built zip
**matches the pinned CN APK hash**; verified by `build.sh` at build time and re-checked
manually after the build.

### 5.2 `LeicaMoment_nezha_v1.0.0_PropsOnly.zip` — 14 entries / 10 files (DEPRECATED, props)

No `system/` payload. Shared files are identical to §5.1 except:

| Entry | Size (bytes) | SHA-256 |
|---|---|---|
| `README.md` | 2,534 | `b466ad8593fc8fd2a19a68c6ba11b9a08abac8aed9b7390abcd22ac89ab58614` |
| `customize.sh` | 2,228 | `db5fab833b61eeb3a0b1c20122e88c8fd1984e9f4a01b1e9ac1dc2d7b4e2ac9f` |
| `diag.sh` | 3,756 | `38f0edd73a779d0390763a69f670872225d01afb084a9225fede30f326989a31` |
| `module.prop` | 285 | `23cf1137d771b7b762c35c249bdb87c987f8432abdeaae4abe1948423f24b0a8` |
| `post-fs-data.sh` | 5,216 | `0e9b2e4814298e0dda4800ec119d3247ca10ab7d3cac3b5560563802dff12571` |

(plus `META-INF/...` update-binary/updater-script, `action.sh`, `service.sh`,
`uninstall.sh` as in §5.1)

### 5.3 `LeicaMoment_nezha_v1.0.0_Full.zip` — 19 entries / 11 files (DEPRECATED, props + APK)

Same files as PropsOnly except `module.prop` (280 B,
sha256 `6cc9bd37c7e9311a42a2736fcac8f5d40e17850a4ed6507bc14ff51db8a84200`,
`version=1.0.0-full`), plus the same CN APK payload as §5.1
(200,627,029 B, sha256 `4637b77d…`). Payload-in-zip hash verified by `build.sh` (log line
`camera payload inside zip verified: sha256=4637b77d…`).

---

## 6. How the zips were built

```sh
cd /mnt/d/Users/FRTI64/Downloads/nezha/work/leica/module

./build.sh all          # all three variants (default; CameraOnly is built first)
./build.sh cameraonly   # only the no-props CameraOnly variant
./build.sh propsonly    # only the deprecated props layer
./build.sh full         # only the deprecated props + APK variant
```

`build.sh` per variant:

1. `rm -rf src/<Variant>` and assemble a complete Magisk module root from `common/`
   (CameraOnly uses `common/cameraonly/` for its no-props scripts; **shared**
   `service.sh`/`uninstall.sh`/`action.sh` are reused) plus the official `META-INF/` files
   copied from `work/leica/module_skel/`. `module.prop` is generated from
   `common/module.prop.tmpl` with the variant name/version/versionCode/description.
2. Payload variants (Full, CameraOnly): copy `work/leica/cn/apps2/MiuiCamera.apk` to
   `src/<Variant>/system/product/priv-app/MiuiCamera/MiuiCamera.apk`, verify size
   (200,627,029) and SHA-256 against the pinned value, then `sync` (DrvFs write flush).
3. Package + validate with `work/leica/scripts/build_module.sh src/<Variant> dist/<name>.zip`
   (META-INF first, no wrapper dir, unix modes normalized, `unzip -t` integrity test,
   `check_module.py` structural validation).
4. Payload variants: verify the APK **inside** the produced zip
   (`unzip -p ... | sha256sum`); on mismatch, retry the packaging once (DrvFs transient
   short-read guard, §8) and fail the build if it persists.
5. CameraOnly: run `verify_no_props()` — fail the build if any non-APK entry contains
   `resetprop`, `ro.theme_customize` or `ro.miui.build.region`.
6. Regenerate `dist/SHA256SUMS.txt` over all `LeicaMoment_nezha_*.zip` (with retries) and
   print final sizes/hashes.

The zips are not byte-reproducible (zip timestamps/ordering may vary); provenance is pinned by
the CN APK SHA-256, the tooling file hashes in §4 and the artifact hashes in §1.

---

## 7. Validation output

### 7.1 `check_module.py` — CameraOnly

```
  INFO  input: .../dist/LeicaMoment_nezha_v1.2.0_CameraOnly.zip (zip)
  INFO  entries: 19 (11 files)
  INFO  top-level entries: META-INF, README.md, action.sh, customize.sh, diag.sh, module.prop, post-fs-data.sh, service.sh, system, uninstall.sh
  INFO  update-binary is byte-identical to Magisk's official module_installer.sh
  INFO  both post-fs-data.sh and service.sh present: only use post-fs-data if needed
  INFO  zip: 19 entries, 191.35 MiB uncompressed
check_module: PASS -- 0 error(s), 0 warning(s) -- .../dist/LeicaMoment_nezha_v1.2.0_CameraOnly.zip
```

### 7.2 `check_module.py` — PropsOnly

```
  INFO  entries: 14 (10 files)
  INFO  top-level entries: META-INF, README.md, action.sh, customize.sh, diag.sh, module.prop, post-fs-data.sh, service.sh, uninstall.sh
  INFO  no payload files under system/ (empty skeleton / test module)
  INFO  update-binary is byte-identical to Magisk's official module_installer.sh
  INFO  both post-fs-data.sh and service.sh present: only use post-fs-data if needed
  INFO  zip: 14 entries, 0.02 MiB uncompressed
check_module: PASS -- 0 error(s), 0 warning(s) -- .../dist/LeicaMoment_nezha_v1.0.0_PropsOnly.zip
```

### 7.3 `check_module.py` — Full

```
  INFO  entries: 19 (11 files)
  INFO  top-level entries: META-INF, README.md, action.sh, customize.sh, diag.sh, module.prop, post-fs-data.sh, service.sh, system, uninstall.sh
  INFO  update-binary is byte-identical to Magisk's official module_installer.sh
  INFO  both post-fs-data.sh and service.sh present: only use post-fs-data if needed
  INFO  zip: 19 entries, 191.35 MiB uncompressed
check_module: PASS -- 0 error(s), 0 warning(s) -- .../dist/LeicaMoment_nezha_v1.0.0_Full.zip
```

### 7.4 Additional host-side checks

* `sha256sum -c SHA256SUMS.txt` → all three OK; `unzip -tq` → "No errors detected" for all.
* Build-log confirmations:
  * `build: camera payload inside zip verified: sha256=4637b77d…08f63` (CameraOnly and Full)
  * `build: no-props verification PASS: no 'resetprop' and no spoofed property names in any non-APK entry` (CameraOnly)
* No-props independent grep evidence (extract zip, grep all non-APK files):
  * `grep -rnE 'resetprop|ro\.theme_customize|ro\.miui\.build\.region' .audit --exclude='*.apk'` → **no matches**
  * extra: `grep -rnE 'setprop|SystemProperties' .audit --exclude='*.apk'` → **no matches**
  * `find .audit -name '*.sh' -exec grep -lE 'resetprop|setprop' {} \;` → **none**
* `sh -n` on every script of all three generated variant trees → all OK; no CRLF; no
  `/data/adb/modules/...` module paths hard-coded in scripts (`MODDIR=${0%/*}`).
* `./smoke_test.sh` (offline logic test with stubbed `getprop`/`resetprop`/`stat`/`dumpsys`/
  `am`/`pm`/`sleep`) → **PASS**, 11 groups:
  1. `customize.sh` declares `REMOVE=/system/product/priv-app/MiuiCamera/oat` for Full and
     CameraOnly, none for PropsOnly;
  2–4. post-fs-data property layer behaviour of the deprecated variants (defaults, PropsOnly
     subset, config toggles OFF incl. CRLF config);
  5. PropsOnly `service.sh` does nothing;
  6. Full `service.sh` runs `am force-stop` + `pm clear` once, writes the guard file, does not
     repeat on the next boot;
  7. Full `service.sh` does **not** clear data when the on-device APK size does not match;
  8. app-store (`/data/app`) camera update is detected and
     `cmd package uninstall-system-updates` hint is logged;
  9. Action-button diagnostics snapshot content;
  10. **CameraOnly `post-fs-data.sh` makes no property-setting calls at all, creates no
     `config.env`, and its scripts contain no property-spoofing strings**;
  11. CameraOnly camera payload + one-time data clear + guard file + diagnostics (which
     identify the variant and contain no spoofed property names).

---

## 8. Known build-environment caveat (transparency)

During an earlier rebuild the CN APK was transiently read short by the packaging chain on DrvFs
(`/mnt/d`): the zip entry recorded 131,170,304 B instead of 200,627,029 B even though the source
copy on disk had the correct size and SHA-256. This was caught by the payload-in-zip
verification and the artifact was rebuilt; it was not shipped. Mitigations now in `build.sh`:

* `sync` after the 200 MB copy, before packaging;
* mandatory SHA-256 verification of the payload **inside** every payload zip;
* one automatic packaging retry, build failure if the hash still mismatches;
* retried `sha256sum` when writing `SHA256SUMS.txt` (the same transient I/O/memory pressure was
  once seen there).

The artifacts in §1 were built with these guards in place and their in-zip payload hash was
verified twice (build-time guard + manual re-check).

---

## 9. What was NOT verified (no device)

No on-device test was possible. Still unverified:

* Runtime compatibility of the CN MiuiCamera build on the global ROM (camera framework/HAL),
  app-store-update precedence, privileged-permission allowlists for the 3 CN-only camera
  permissions.
* The **no-props gating path**: the LSPosed module v2.0.0 (direct `mediaeditor` predicate hooks,
  task-10) and the LSPosed camera hook research (task-9, not finished when this module was
  built) are both unvalidated on hardware. With CameraOnly the stock camera gating is untouched,
  so the Leica capture UI is *not* expected to appear until those LSPosed camera hooks exist.
* Server-side acceptance/entitlement of the cloud re-render job (`hardwareAuthToken`,
  `lcc_support_devices`/`leica_support_devices`, quota) — unfixable client-side.
* The visual/behavioural side effects of the deprecated variants' region spoof (expected to be
  avoided by using CameraOnly).

---

## 10. Change log

* **v1.2.0 / 2026-11-11** — added `LeicaMoment_nezha_v1.2.0_CameraOnly.zip`: no-property-spoof
  camera-only variant (user requirement); build-time no-props enforcement + smoke tests;
  README/BUILD_INFO rewritten around three variants; props-based variants marked DEPRECATED;
  `module.prop` metadata parameterized per variant.
* **v1.0.0 / 2026-11-10** — initial two variants: `PropsOnly` (props layer) and `Full` (props +
  CN camera APK), with `action.sh`/`diag.sh` diagnostics, one-time camera data clear and ART
  oat hiding.

---

## 11. Source references

* `../docs/ANALYSIS.md` — overall synthesis (§5 cloud flow/limits, §6 module design, §9 LSPosed
  module; note: “no property faking” requirement is implemented by the CameraOnly variant +
  LSPosed no-props hooks).
* `../docs/LSPOSED_MODULE.md` — the separate LSPosed module that unlocks the editor entry via
  direct method hooks (v2.0.0 removes in-process `SystemProperties` masking; no system-property
  changes).
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
* Evidence files: `work/leica/global/analysis/` (APK info/signers, dex strings, smali evidence),
  `work/leica/cn/` (CN APKs + decompiled evidence), `work/dump/` (global partition images).
