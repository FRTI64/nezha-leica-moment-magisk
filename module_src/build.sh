#!/usr/bin/env bash
# build.sh -- assemble + build the Leica Moment Port (nezha) Magisk module variants.
#
# Outputs (in ./dist):
#   LeicaMoment_nezha_v1.0.0_PropsOnly.zip   properties only, no APK payload
#   LeicaMoment_nezha_v1.0.0_Full.zip        properties + CN MiuiCamera.apk payload
#   SHA256SUMS.txt                           sha256 of both zips
#
# Each variant gets a complete Magisk module root at ./src/<Variant>/ (module.prop,
# META-INF/, scripts, and for Full the APK under system/product/priv-app/MiuiCamera/),
# which is then packaged + validated by work/leica/scripts/build_module.sh (which in
# turn runs work/leica/scripts/check_module.py).
#
# Usage: ./build.sh [all|propsonly|full]     (default: all)
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

VERSION="1.0.0"
VERSION_CODE=10000

# Pinned CN MiuiCamera.apk (extracted from CN ROM OS4.0.5.0.XPACNXM):
#   package=com.android.camera versionName=6.7.000280.0 versionCode=670002800
APK_SHA256="4637b77d5b365260f8089318179206d42d0ba842fb08109f203f1ea9d3908f63"
APK_SIZE=200627029

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
}

assemble() { # $1=dir name, $2=version suffix, $3=props|full
  local name="$1" vsuffix="$2" kind="$3"
  local dir="$SRC/$name"

  info "assembling $name ($kind) -> $dir"
  rm -rf "$dir"
  mkdir -p "$dir/META-INF/com/google/android"

  cp "$COMMON/customize.sh" "$COMMON/post-fs-data.sh" "$COMMON/service.sh" \
     "$COMMON/uninstall.sh" "$COMMON/action.sh" "$COMMON/diag.sh" \
     "$COMMON/README.md" "$dir/"
  cp "$SKEL/META-INF/com/google/android/update-binary" \
     "$SKEL/META-INF/com/google/android/updater-script" \
     "$dir/META-INF/com/google/android/"

  # Expand the variant version into module.prop (LF endings, no comments).
  sed -e "s/__VERSION__/${VERSION}-${vsuffix}/" \
      -e "s/__VERSION_CODE__/${VERSION_CODE}/" \
      "$COMMON/module.prop.tmpl" > "$dir/module.prop"

  if [ "$kind" = "full" ]; then
    [ -f "$APK_SRC" ] || die "missing CN camera APK: $APK_SRC"
    local src_size
    src_size=$(stat -c %s "$APK_SRC")
    [ "$src_size" = "$APK_SIZE" ] || die "CN camera APK size mismatch: got $src_size, expected $APK_SIZE"

    local apk_dir="$dir/system/product/priv-app/MiuiCamera"
    mkdir -p "$apk_dir"
    info "copying CN MiuiCamera.apk (200 MB; slow on DrvFs, please wait) ..."
    cp "$APK_SRC" "$apk_dir/MiuiCamera.apk"

    local got
    got=$(sha256_of "$apk_dir/MiuiCamera.apk")
    [ "$got" = "$APK_SHA256" ] || die "copied CN camera APK hash mismatch: got $got, expected $APK_SHA256"
    info "CN camera APK verified: size=$APK_SIZE sha256=$APK_SHA256"
    sync   # flush the 200 MB copy to DrvFs before zip reads it back
  fi

  # Make scripts executable in the source tree too (the packager forces 0755 for *.sh).
  chmod 0755 "$dir"/*.sh

  info "variant tree: $(find "$dir" -type f | wc -l) files, $(du -sh "$dir" | cut -f1)"
}

build_variant() { # $1=dir name, $2=zip base name, $3=props|full
  local dir="$SRC/$1" out="$DIST/$2.zip" kind="$3" attempt=1 max_attempts=2
  local apk_entry="system/product/priv-app/MiuiCamera/MiuiCamera.apk"
  while :; do
    info "packaging + validating $out (attempt $attempt)"
    "$BUILD_TOOL" "$dir" "$out"

    if [ "$kind" = "full" ]; then
      # DrvFs has been observed to hand a transiently-truncated 200 MB file to the
      # packager; never publish a zip whose camera payload does not match the input.
      local got
      got=$(unzip -p "$out" "$apk_entry" | sha256sum | cut -d' ' -f1)
      if [ "$got" != "$APK_SHA256" ]; then
        info "WARN: camera payload INSIDE the built zip is corrupted (sha256=$got) -- retry $attempt/$max_attempts"
        rm -f "$out"
        [ "$attempt" -lt "$max_attempts" ] || die "camera payload still corrupted after $max_attempts packaging attempts"
        attempt=$((attempt + 1))
        continue
      fi
      info "camera payload inside zip verified: sha256=$APK_SHA256"
    fi

    info "built $out  size=$(stat -c %s "$out")  sha256=$(sha256_of "$out")"
    break
  done
}

main() {
  local what="${1:-all}"
  case "$what" in
    all|propsonly|full) ;;
    *) die "usage: $0 [all|propsonly|full]" ;;
  esac

  require_inputs
  mkdir -p "$DIST"

  if [ "$what" = "all" ] || [ "$what" = "propsonly" ]; then
    assemble "PropsOnly" "propsonly" "props"
    build_variant "PropsOnly" "LeicaMoment_nezha_v${VERSION}_PropsOnly" "props"
  fi
  if [ "$what" = "all" ] || [ "$what" = "full" ]; then
    assemble "Full" "full" "full"
    build_variant "Full" "LeicaMoment_nezha_v${VERSION}_Full" "full"
  fi

  # Write SHA256SUMS.txt (retry: DrvFs/large-file hashing has been seen to fail transiently
  # under memory pressure right after the 200 MB rezip; never publish an empty sums file).
  sums_ok=0
  for attempt in 1 2 3; do
    if ( cd "$DIST" && sha256sum LeicaMoment_nezha_v"${VERSION}"_*.zip > SHA256SUMS.txt ) 2>/dev/null; then
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
