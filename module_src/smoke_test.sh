#!/usr/bin/env bash
# smoke_test.sh -- offline logic test for the Leica Moment Port module scripts.
#
# There is no Android device in this workspace, so this test executes the real
# post-fs-data.sh / service.sh / customize.sh from common/ inside a fake environment
# (stub getprop/resetprop/stat/dumpsys/am/pm/sleep) and asserts the expected control flow:
#   * property layer applies exactly the configured props (and honours config.env toggles)
#   * Full variant also sets camera.debug.safe.check.disable, PropsOnly does not
#   * customize.sh declares REMOVE only when the camera payload is present
#   * service.sh skips everything for PropsOnly
#   * service.sh clears camera data exactly once when the payload is active (guard file),
#     and does NOT clear when the on-device APK size does not match the payload
#   * CameraOnly variant: post-fs-data.sh makes NO property-setting calls at all, no
#     config.env is created, camera data clear still works, diagnostics show the variant
#     and contain no property spoofing strings
#
# Not a substitute for an on-device test. Run: ./smoke_test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA="$HERE/.qa_smoke"
FAIL=0

rm -rf "$QA"
mkdir -p "$QA/bin" "$QA/data"

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; FAIL=$((FAIL + 1)); }
check() { # $1 description, $2 expected prefix, $3 file
  if grep -qF -- "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1 (missing '$2' in $3)"; fi
}
check_absent() { # $1 description, $2 needle, $3 file
  if grep -qF -- "$2" "$3" 2>/dev/null; then fail "$1 (unexpected '$2' in $3)"; else pass "$1"; fi
}

# ---------------------------------------------------------------- stubs ------
cat > "$QA/bin/resetprop" <<'EOF'
#!/bin/sh
[ "${1:-}" = "-n" ] && shift
echo "$1=$2" >> "$QA_LOG"
exit 0
EOF
cat > "$QA/bin/getprop" <<'EOF'
#!/bin/sh
case "$1" in
  sys.boot_completed) echo "${BOOT_COMPLETED:-1}" ;;
  ro.theme_customize) echo "${PROP_THEME:-}" ;;
  ro.theme_leica)     echo "${PROP_LEICA:-}" ;;
  ro.miui.build.region) echo "${PROP_REGION:-global}" ;;
  *) echo "" ;;
esac
EOF
cat > "$QA/bin/stat" <<'EOF'
#!/bin/sh
case "$*" in
  *MiuiCamera.apk) echo "${STAT_SIZE:-200627029}" ;;
  *) echo "character special file" ;;
esac
EOF
cat > "$QA/bin/dumpsys" <<'EOF'
#!/bin/sh
echo "Packages:"
echo "    codePath=${CODE_PATH:-/product/priv-app/MiuiCamera}"
echo "    versionName=${DUMPSYS_VERSION:-6.7.000280.0}"
EOF
cat > "$QA/bin/am" <<'EOF'
#!/bin/sh
echo "am $*" >> "$QA_LOG"
exit 0
EOF
cat > "$QA/bin/pm" <<'EOF'
#!/bin/sh
echo "pm $*" >> "$QA_LOG"
exit 0
EOF
cat > "$QA/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$QA/bin/"*

export PATH="$QA/bin:$PATH"
export QA="$QA"
QA_LOG="$QA/calls.log"

# ------------------------------------------------------- variant fixtures -----
make_variant() { # $1 name, $2 full|props|cameraonly
  local name="$1" kind="$2" dir="$QA/$1"
  mkdir -p "$dir"
  cp "$HERE/common/service.sh" "$HERE/common/uninstall.sh" "$HERE/common/action.sh" "$dir/"
  case "$kind" in
    full|props)
      cp "$HERE/common/post-fs-data.sh" "$HERE/common/customize.sh" "$HERE/common/diag.sh" "$dir/"
      ;;
    cameraonly)
      cp "$HERE/common/cameraonly/post-fs-data.sh" "$HERE/common/cameraonly/customize.sh" \
         "$HERE/common/cameraonly/diag.sh" "$HERE/common/cameraonly/README.md" "$dir/"
      ;;
    *) echo "make_variant: unknown kind $kind" >&2; return 1 ;;
  esac
  sed -i "s#/data/adb/leica_moment#$QA/data#g" "$dir"/*.sh
  printf 'id=nezha_leica_moment\nname=Leica Moment Port (nezha)\nversion=1.2.0-test\nversionCode=12000\nauthor=t\ndescription=d\n' > "$dir/module.prop"
  if [ "$kind" = "full" ] || [ "$kind" = "cameraonly" ]; then
    mkdir -p "$dir/system/product/priv-app/MiuiCamera"
    printf 'fake-apk\n' > "$dir/system/product/priv-app/MiuiCamera/MiuiCamera.apk"
  fi
}

run_postfs() { # $1 dir
  QA_LOG="$QA/calls.log" sh "$1/post-fs-data.sh"
}
run_service() { # $1 dir, extra KEY=VAL... (exported to the script and its children)
  local dir="$1"
  shift
  env QA_LOG="$QA/calls.log" "$@" sh "$dir/service.sh"
}
run_customize() { # $1 dir -- source it in a bash subshell with the installer functions stubbed
  (
    set -u
    ui_print() { :; }
    abort() { :; }
    set_perm() { :; }
    set_perm_recursive() { :; }
    MODPATH="$1"
    # shellcheck disable=SC1090
    . "$1/customize.sh"
    echo "${REMOVE:-}"
  )
}

make_variant full full
make_variant props props
make_variant cameraonly cameraonly

echo "== 1. customize.sh: REMOVE depends on the variant/payload"
out=$(run_customize "$QA/full"); [ "$out" = "/system/product/priv-app/MiuiCamera/oat" ] \
  && pass "Full variant declares REMOVE=/system/product/priv-app/MiuiCamera/oat" \
  || fail "Full variant REMOVE wrong: '$out'"
out=$(run_customize "$QA/props"); [ -z "$out" ] \
  && pass "PropsOnly variant declares no REMOVE" \
  || fail "PropsOnly variant unexpectedly declares REMOVE='$out'"
out=$(run_customize "$QA/cameraonly"); [ "$out" = "/system/product/priv-app/MiuiCamera/oat" ] \
  && pass "CameraOnly variant declares REMOVE=/system/product/priv-app/MiuiCamera/oat" \
  || fail "CameraOnly variant REMOVE wrong: '$out'"

echo "== 2. post-fs-data.sh: default props, Full variant"
make_variant full full
mkdir -p "$QA/data"; rm -f "$QA/data/config.env" "$QA/data/module.log" "$QA_LOG"
run_postfs "$QA/full"
check "config.env created" "REGION_SPOOF=1" "$QA/data/config.env"
check "LEICA_SKU_PROPS applied" "ro.theme_customize=LCC" "$QA_LOG"
check "ro.theme_leica applied" "ro.theme_leica=true" "$QA_LOG"
check "ro.boot.product.theme_customize applied" "ro.boot.product.theme_customize=P1_Leica" "$QA_LOG"
check "ro.special_edition applied" "ro.special_edition=true" "$QA_LOG"
check "camera debug prop applied (Full)" "camera.debug.safe.check.disable=true" "$QA_LOG"
check "region spoof applied" "ro.miui.build.region=cn" "$QA_LOG"
check "post-fs-data log written" "set ro.theme_customize=LCC" "$QA/data/module.log"

echo "== 3. post-fs-data.sh: default props, PropsOnly variant"
make_variant props props
rm -f "$QA/data/config.env" "$QA/data/module.log" "$QA_LOG"
run_postfs "$QA/props"
check "theme props applied (PropsOnly)" "ro.theme_customize=LCC" "$QA_LOG"
check_absent "no camera debug prop without payload" "camera.debug.safe.check.disable" "$QA_LOG"
check "region spoof applied (PropsOnly)" "ro.miui.build.region=cn" "$QA_LOG"

echo "== 4. post-fs-data.sh: config toggles OFF (CRLF config)"
make_variant full full
printf '# test\r\nREGION_SPOOF=0\r\nLEICA_SKU_PROPS=0\r\nCLEAR_CAMERA_DATA=0\r\n' > "$QA/data/config.env"
rm -f "$QA/data/module.log" "$QA_LOG"
run_postfs "$QA/full"
check_absent "no theme props when LEICA_SKU_PROPS=0" "ro.theme_customize=LCC" "$QA_LOG"
check_absent "no region spoof when REGION_SPOOF=0" "ro.miui.build.region=cn" "$QA_LOG"
check_absent "no ro.special_edition when LEICA_SKU_PROPS=0" "ro.special_edition=true" "$QA_LOG"
check "camera debug prop still applied (not tied to the SKU toggle)" "camera.debug.safe.check.disable=true" "$QA_LOG"
check "log explains disabled toggles" "LEICA_SKU_PROPS=0" "$QA/data/module.log"

echo "== 5. service.sh: PropsOnly variant does nothing"
make_variant props props
rm -f "$QA/data/module.log" "$QA_LOG" "$QA/data/.camera_cleared_6.7.000280.0"
run_service "$QA/props"
check "PropsOnly service log line" "props-only variant" "$QA/data/module.log"
if [ -f "$QA_LOG" ] && grep -qE '^(am|pm) ' "$QA_LOG"; then fail "service.sh ran am/pm for PropsOnly"; else pass "no am/pm calls for PropsOnly"; fi

echo "== 6. service.sh: Full, payload active -> one-time pm clear + guard"
make_variant full full
rm -f "$QA/data/module.log" "$QA_LOG" "$QA/data/.camera_cleared_6.7.000280.0"
printf 'REGION_SPOOF=1\nLEICA_SKU_PROPS=1\nCLEAR_CAMERA_DATA=1\n' > "$QA/data/config.env"
BOOT_COMPLETED=1 STAT_SIZE=200627029 DUMPSYS_VERSION=6.7.000280.0 run_service "$QA/full"
check "am force-stop called" "am force-stop com.android.camera" "$QA_LOG"
check "pm clear called" "pm clear com.android.camera" "$QA_LOG"
[ -f "$QA/data/.camera_cleared_6.7.000280.0" ] \
  && pass "guard file written" || fail "guard file missing"
rm -f "$QA_LOG"
BOOT_COMPLETED=1 STAT_SIZE=200627029 DUMPSYS_VERSION=6.7.000280.0 run_service "$QA/full"
if [ -f "$QA_LOG" ] && grep -qE '^pm ' "$QA_LOG"; then fail "pm clear repeated on second boot"; else pass "no repeated pm clear (guard honoured)"; fi
check "second boot logs already-cleared" "already cleared" "$QA/data/module.log"

echo "== 7. service.sh: Full, payload NOT active (size mismatch) -> no data clear"
make_variant full full
rm -f "$QA/data/module.log" "$QA_LOG" "$QA/data/.camera_cleared_6.7.000280.0"
BOOT_COMPLETED=1 STAT_SIZE=123456 DUMPSYS_VERSION=6.6.000570.5 run_service "$QA/full"
if [ -f "$QA_LOG" ] && grep -qE '^pm ' "$QA_LOG"; then fail "pm clear ran although the APK was not active"; else pass "no pm clear when APK replacement is inactive"; fi
check "size mismatch warned" "NOT active" "$QA/data/module.log"

echo "== 8. service.sh: app-store camera update detected -> warning logged"
make_variant full full
rm -f "$QA/data/module.log" "$QA_LOG" "$QA/data/.camera_cleared_6.7.000280.0"
BOOT_COMPLETED=1 STAT_SIZE=200627029 DUMPSYS_VERSION=6.7.000280.0 CODE_PATH=/data/app/com.android.camera-1 run_service "$QA/full"
check "data-app update warning logged" "cmd package uninstall-system-updates" "$QA/data/module.log"
check "codePath logged" "codePath=/data/app/com.android.camera-1" "$QA/data/module.log"

echo "== 9. action.sh / diag.sh: on-device diagnostics snapshot"
make_variant full full
rm -f "$QA/data/diag.log" "$QA/data/module.log" "$QA_LOG"
ACTION_OUT=$(PATH="$QA/bin:$PATH" QA_LOG="$QA/calls.log" sh "$QA/full/action.sh" 2>&1)
if [ -f "$QA/data/diag.log" ]; then pass "diag.log created"; else fail "diag.log missing"; fi
check "diag has module version" "module     : id=nezha_leica_moment version=1.2.0-test" "$QA/data/diag.log"
check "diag has props" "ro.theme_customize=" "$QA/data/diag.log"
check "diag has config values" "REGION_SPOOF=" "$QA/data/diag.log"
check "diag has camera payload size" "200627029" "$QA/data/diag.log"
check "diag has package versions" "versionName=" "$QA/data/diag.log"
check "diag has follow-up hints" "adb logcat" "$QA/data/diag.log"
case "$ACTION_OUT" in
  *"Diagnostics appended to:"*) pass "action.sh prints the diag path" ;;
  *) fail "action.sh output does not mention the diag path" ;;
esac

echo "== 10. CameraOnly variant: no property setting at all"
make_variant cameraonly cameraonly
rm -f "$QA/data/config.env" "$QA/data/module.log" "$QA/data/diag.log" "$QA_LOG"
run_postfs "$QA/cameraonly"
if [ ! -s "$QA_LOG" ]; then pass "no property-setting calls from CameraOnly post-fs-data.sh"; else fail "CameraOnly post-fs-data.sh invoked a property tool: $(cat "$QA_LOG")"; fi
[ ! -f "$QA/data/config.env" ] && pass "CameraOnly creates no config.env (no property layer)" \
  || fail "CameraOnly unexpectedly created config.env"
check "CameraOnly no-op post-fs-data log line" "CameraOnly variant booted" "$QA/data/module.log"
BAD=$(grep -rlE 'resetprop|ro\.theme_customize|ro\.miui\.build\.region' "$QA/cameraonly" --include='*.sh' 2>/dev/null)
[ -z "$BAD" ] && pass "CameraOnly scripts contain no property-spoofing strings" \
  || fail "CameraOnly scripts contain forbidden strings: $BAD"

echo "== 11. CameraOnly variant: camera payload + one-time data clear + diagnostics"
make_variant cameraonly cameraonly
rm -f "$QA/data/module.log" "$QA_LOG" "$QA/data/.camera_cleared_6.7.000280.0"
BOOT_COMPLETED=1 STAT_SIZE=200627029 DUMPSYS_VERSION=6.7.000280.0 run_service "$QA/cameraonly"
if [ -f "$QA_LOG" ] && grep -qF "am force-stop com.android.camera" "$QA_LOG"; then pass "CameraOnly: am force-stop called"; else fail "CameraOnly: am force-stop missing"; fi
if [ -f "$QA_LOG" ] && grep -qF "pm clear com.android.camera" "$QA_LOG"; then pass "CameraOnly: pm clear called"; else fail "CameraOnly: pm clear missing"; fi
[ -f "$QA/data/.camera_cleared_6.7.000280.0" ] && pass "CameraOnly: guard file written" \
  || fail "CameraOnly: guard file missing"
rm -f "$QA/data/diag.log"
DIAG_OUT=$(PATH="$QA/bin:$PATH" QA_LOG="$QA/calls.log" sh "$QA/cameraonly/action.sh" 2>&1)
if [ -f "$QA/data/diag.log" ]; then pass "CameraOnly: diag.log created"; else fail "CameraOnly: diag.log missing"; fi
check "CameraOnly diag identifies the variant" "variant    : CameraOnly" "$QA/data/diag.log"
check_absent "CameraOnly diag has no spoofed property names" "ro.theme_customize" "$QA/data/diag.log"
case "$DIAG_OUT" in
  *"Diagnostics appended to:"*) pass "CameraOnly action.sh prints the diag path" ;;
  *) fail "CameraOnly action.sh output does not mention the diag path" ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "smoke_test: PASS -- all script logic checks succeeded"
  rm -rf "$QA"
  exit 0
else
  echo "smoke_test: FAIL -- $FAIL check(s) failed (artifacts kept in $QA)"
  exit 1
fi
