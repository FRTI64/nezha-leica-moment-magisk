#!/usr/bin/env bash
# build.sh -- assemble + build the Leica Moment Port (nezha) Magisk module variants.
#
# Outputs (in ./dist):
#   LeicaMoment_nezha_v1.2.0_CameraOnly.zip  RECOMMENDED (no-props): CN MiuiCamera APK only
#   LeicaMoment_nezha_v1.0.0_PropsOnly.zip   DEPRECATED: property layer only (prop spoofing)
#   LeicaMoment_nezha_v1.0.0_Full.zip        DEPRECATED: property layer + CN camera APK
#   SHA256SUMS.txt                           sha256 of all three zips
#
# CameraOnly respects the user requirement "do not use property faking": it makes NO system
# property changes and contains no property names / property-setting calls. This is enforced
# at build time by verify_no_props(): the build fails if any non-APK entry of the CameraOnly
# zip contains a forbidden property string.
#
# Each variant gets a complete Magisk module root at ./src/<Variant>/ (module.prop,
# META-INF/, scripts, and for Full/CameraOnly the APK under
# system/product/priv-app/MiuiCamera/), which is then packaged + validated by
# work/leica/scripts/build_module.sh (which in turn runs check_module.py).
#
# Usage: ./build.sh [all|propsonly|full|cameraonly]     (default: all)
#
# Inputs (read-only):
#   ../cn/apps2/MiuiCamera.apk              CN camera payload (sha256 pinned below)
#   ../module_skel/META-INF/...             official update-binary + updater-script
#   ../scripts/build_module.sh              packaging + validation tool
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEICA="$(cd "$HERE/.." && pwd)"
COMMON="$HERE/common"
SRC="$HERE/src"
DIST="$HERE/dist"

BUILD_TOOL="$LEICA/scripts/build_module.sh"
SKEL="$LEICA/module_skel"
APK_SRC="$LEICA/cn/apps2/MiuiCamera.apk"

# Deprecated, property-injection based variants.
VERSION_PROPS="1.0.0"
VERSION_CODE_PROPS=10000
# Current, no-props variant.
VERSION_CAMERAONLY="1.2.0"
VERSION_CODE_CAMERAONLY=12000

MODULE_NAME_DEFAULT="Leica Moment Port (nezha)"
MODULE_DESC_DEFAULT="DEPRECATED property-injection variant: sets Leica/region system properties via Magisk resetprop. Use the CameraOnly variant if you do not want property spoofing."
MODULE_NAME_CAMERAONLY="Leica Moment Port (nezha) - CameraOnly"
MODULE_DESC_CAMERAONLY="No-props camera payload: replaces the stock MiuiCamera APK with the CN 6.7.000280.0 build only. NO system properties are changed by this module; gating is left to the LSPosed module. Recommended."

# Pinned CN MiuiCamera.apk (extracted from CN ROM OS4.0.5.0.XPACNXM):
#   package=com.android.camera versionName=6.7.000280.0 versionCode=670002800
APK_SHA256="4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63"
APK_SIZE=200627029

# Forbidden in the no-props CameraOnly artifact: property-setting tool and the two properties
# that the deprecated variants used to fake. (Keep this list minimal and literal.)
CAMERAONLY_FORBIDDEN_RE='resetprop|ro\.theme_customize|ro\.miui\.build\.region'

info() { echo "build: $*" >&2; }
die() { echo "build: error: $*" >&2; exit 1; }
sha256_of() { sha256sum "$1" | cut -d' ' -f1; }

require_inputs() {
  [ -f "$BUILD_TOOL" ] || die "missing build tool: $BUILD_TOOL"
  [ -f "$LEICA/scripts/check_module.py" ] || die "missing validator: $LEICA/scripts/check_module.py"
  [ -f "$SKEL/META-INF/com/google/android/update-binary" ] || die "missing skeleton update-binary"
  [ -f "$SKEL/META-INF/com/google/android/updater-script" ] || die "missing skeleton updater-script"
  for f in module.prop.tmpl customize.sh post-fs-data.sh service.sh uninstall.sh action.sh diag.sh README.md; do
    [ -f "$COMMON/$f" ] || die "missing common asset: $COMMON/$f"
  done
  for f in customize.sh post-fs-data.sh diag.sh README.md; do
    [ -f "$COMMON/cameraonly/$f" ] || die "missing CameraOnly asset: $COMMON/cameraonly/$f"
  done
}

copy_meta() { # $1 = module root
  cp "$SKEL/META-INF/com/google/android/update-binary" \
     "$SKEL/META-INF/com/google/android/updater-script" \
     "$1/META-INF/com/google/android/"
}

copy_payload() { # $1 = module root
  [ -f "$APK_SRC" ] || die "missing CN camera APK: $APK_SRC"
  local src_size
  src_size=$(stat -c %s "$APK_SRC")
  [ "$src_size" = "$APK_SIZE" ] || die "CN camera APK size mismatch: got $src_size, expected $APK_SIZE"

  local apk_dir="$1/system/product/priv-app/MiuiCamera"
  mkdir -p "$apk_dir"
  info "copying CN MiuiCamera.apk (200 MB; slow on DrvFs, please wait) ..."
  cp "$APK_SRC" "$apk_dir/MiuiCamera.apk"

  local got
  got=$(sha256_of "$apk_dir/MiuiCamera.apk")
  [ "$got" = "$APK_SHA256" ] || die "copied CN camera APK hash mismatch: got $got, expected $APK_SHA256"
  info "CN camera APK verified: size=$APK_SIZE sha256=$APK_SHA256"
  sync   # flush the 200 MB copy to DrvFs before zip reads it back
}

assemble() { # $1 = dir name, $2 = version suffix, $3 = props|full|cameraonly
  local name="$1" vsuffix="$2" kind="$3"
  local dir="$SRC/$name" version version_code module_name module_desc

  info "assembling $name ($kind) -> $dir"
  rm -rf "$dir"
  mkdir -p "$dir/META-INF/com/google/android"

  case "$kind" in
    props|full)
      version="$VERSION_PROPS"; version_code="$VERSION_CODE_PROPS"
      module_name="$MODULE_NAME_DEFAULT"; module_desc="$MODULE_DESC_DEFAULT"
      cp "$COMMON/customize.sh" "$COMMON/post-fs-data.sh" "$COMMON/service.sh" \
         "$COMMON/uninstall.sh" "$COMMON/action.sh" "$COMMON/diag.sh" \
         "$COMMON/README.md" "$dir/"
      ;;
    cameraonly)
      version="$VERSION_CAMERAONLY"; version_code="$VERSION_CODE_CAMERAONLY"
      module_name="$MODULE_NAME_CAMERAONLY"; module_desc="$MODULE_DESC_CAMERAONLY"
      # Variant-specific scripts + shared service/uninstall/action (none of them touch props).
      cp "$COMMON/cameraonly/customize.sh" "$COMMON/cameraonly/post-fs-data.sh" \
         "$COMMON/cameraonly/diag.sh" "$COMMON/cameraonly/README.md" "$dir/"
      cp "$COMMON/service.sh" "$COMMON/uninstall.sh" "$COMMON/action.sh" "$dir/"
      ;;
    *) die "assemble: unknown kind $kind" ;;
  esac

  copy_meta "$dir"

  # Expand the variant metadata into module.prop (LF endings, no comments).
  # '|' as sed delimiter: descriptions contain '/' (e.g. "Leica/region").
  sed -e "s|__NAME__|${module_name}|" \
      -e "s|__VERSION__|${version}-${vsuffix}|" \
      -e "s|__VERSION_CODE__|${version_code}|" \
      -e "s|__DESCRIPTION__|${module_desc}|" \
      "$COMMON/module.prop.tmpl" > "$dir/module.prop"

  case "$kind" in
    full|cameraonly) copy_payload "$dir" ;;
  esac

  # Make scripts executable in the source tree too (the packager forces 0755 for *.sh).
  chmod 0755 "$dir"/*.sh

  info "variant tree: $(find "$dir" -type f | wc -l) files, $(du -sh "$dir" | cut -f1)"
}

verify_payload_in_zip() { # $1 = zip
  local apk_entry="system/product/priv-app/MiuiCamera/MiuiCamera.apk" got
  got=$(unzip -p "$1" "$apk_entry" | sha256sum | cut -d' ' -f1)
  [ "$got" = "$APK_SHA256" ] || return 1
  info "camera payload inside zip verified: sha256=$APK_SHA256"
}

verify_no_props() { # $1 = zip; enforces the "no property spoofing" contract for CameraOnly
  local zip="$1" entry bad=0
  while IFS= read -r entry; do
    case "$entry" in
      */|*.apk) continue ;;
    esac
    if unzip -p "$zip" "$entry" 2>/dev/null | grep -qE "$CAMERAONLY_FORBIDDEN_RE"; then
      echo "  FORBIDDEN property string found in zip entry: $entry" >&2
      bad=1
    fi
  done < <(unzip -Z1 "$zip")
  [ "$bad" -eq 0 ] || die "CameraOnly zip violates the no-props contract (see entries above)"
  info "no-props verification PASS: no 'resetprop' and no spoofed property names in any non-APK entry"
}

build_variant() { # $1 = dir name, $2 = zip base name, $3 = props|full|cameraonly
  local dir="$SRC/$1" out="$DIST/$2.zip" kind="$3" attempt=1 max_attempts=2
  while :; do
    info "packaging + validating $out (attempt $attempt)"
    "$BUILD_TOOL" "$dir" "$out"

    if [ "$kind" = "full" ] || [ "$kind" = "cameraonly" ]; then
      # DrvFs has been observed to hand a transiently-truncated 200 MB file to the
      # packager; never publish a zip whose camera payload does not match the input.
      if ! verify_payload_in_zip "$out"; then
        info "WARN: camera payload INSIDE the built zip is corrupted -- retry $attempt/$max_attempts"
        rm -f "$out"
        [ "$attempt" -lt "$max_attempts" ] || die "camera payload still corrupted after $max_attempts packaging attempts"
        attempt=$((attempt + 1))
        continue
      fi
    fi

    if [ "$kind" = "cameraonly" ]; then
      verify_no_props "$out"
    fi

    info "built $out  size=$(stat -c %s "$out")  sha256=$(sha256_of "$out")"
    break
  done
}

main() {
  local what="${1:-all}"
  case "$what" in
    all|propsonly|full|cameraonly) ;;
    *) die "usage: $0 [all|propsonly|full|cameraonly]" ;;
  esac

  require_inputs
  mkdir -p "$DIST"

  # Build the recommended CameraOnly variant first (so a failure there stops the build early).
  if [ "$what" = "all" ] || [ "$what" = "cameraonly" ]; then
    assemble "CameraOnly" "cameraonly" "cameraonly"
    build_variant "CameraOnly" "LeicaMoment_nezha_v${VERSION_CAMERAONLY}_CameraOnly" "cameraonly"
  fi
  if [ "$what" = "all" ] || [ "$what" = "propsonly" ]; then
    assemble "PropsOnly" "propsonly" "props"
    build_variant "PropsOnly" "LeicaMoment_nezha_v${VERSION_PROPS}_PropsOnly" "props"
  fi
  if [ "$what" = "all" ] || [ "$what" = "full" ]; then
    assemble "Full" "full" "full"
    build_variant "Full" "LeicaMoment_nezha_v${VERSION_PROPS}_Full" "full"
  fi

  # Write SHA256SUMS.txt (retry: DrvFs/large-file hashing has been seen to fail transiently
  # under memory pressure right after a 200 MB rezip; never publish an empty sums file).
  sums_ok=0
  for attempt in 1 2 3; do
    if ( cd "$DIST" && sha256sum LeicaMoment_nezha_*.zip > SHA256SUMS.txt ) 2>/dev/null; then
      sums_ok=1
      break
    fi
    info "WARN: sha256sum failed (attempt $attempt/3), retrying ..."
    sleep 2
  done
  [ "$sums_ok" -eq 1 ] || die "could not write $DIST/SHA256SUMS.txt"
  info "SHA256SUMS.txt:"
  sed 's/^/  /' "$DIST/SHA256SUMS.txt" >&2
  info "done. dist contents:"
  ( cd "$DIST" && ls -l )
}

main "$@"
