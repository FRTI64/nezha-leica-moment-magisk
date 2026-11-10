#!/system/bin/sh
# diag.sh -- Leica Moment Port (nezha) diagnostics collector.
#
# Standalone script: no Magisk installer functions, no module-system assumptions.
# Invoked by action.sh (Magisk "Action" button) or manually:
#   adb shell su -c 'sh <module-dir>/diag.sh'
#
# Appends a snapshot to /data/adb/leica_moment/diag.log and prints the tail to stdout.
# Budget: well under 5 s (two `dumpsys package` calls + small file reads).

MODDIR=${0%/*}
DATA_DIR=/data/adb/leica_moment
CONF=$DATA_DIR/config.env
LOG=$DATA_DIR/module.log
DIAG=$DATA_DIR/diag.log
MODPROP=$MODDIR/module.prop

CAM_PKG=com.android.camera
EDITOR_PKG=com.miui.mediaeditor
CAM_PAYLOAD=$MODDIR/system/product/priv-app/MiuiCamera/MiuiCamera.apk
CAM_ON_DEVICE=/product/priv-app/MiuiCamera/MiuiCamera.apk
CAM_OAT_ON_DEVICE=/product/priv-app/MiuiCamera/oat

mkdir -p "$DATA_DIR" 2>/dev/null

TS=$(date '+%Y-%m-%d %H:%M:%S')
MODVER=$(grep -m1 '^version=' "$MODPROP" 2>/dev/null | cut -d= -f2-)
MODID=$(grep -m1 '^id=' "$MODPROP" 2>/dev/null | cut -d= -f2-)

{
  echo "===== Leica Moment Port (nezha) diag: $TS ====="
  echo "module     : id=${MODID:-?} version=${MODVER:-?}"
  echo "module dir : $MODDIR"
  echo "rom        : incremental=$(getprop ro.build.version.incremental) region=$(getprop ro.miui.build.region)"
  echo "device ids : ro.product.device=$(getprop ro.product.device) ro.product.mod_device=$(getprop ro.product.mod_device)"
  echo "props:"
  for p in ro.theme_customize ro.theme_leica ro.boot.product.theme_customize \
           ro.miui.build.region ro.product.mod_device ro.product.device \
           ro.special_edition camera.debug.safe.check.disable; do
    echo "  $p=$(getprop "$p")"
  done
  echo "runtime config ($CONF):"
  if [ -f "$CONF" ]; then
    grep -v -E '^[[:space:]]*(#|$)' "$CONF" 2>/dev/null | sed 's/^/  /'
  else
    echo "  (missing; post-fs-data.sh creates it on first boot)"
  fi
  echo "camera payload in module (Full variant only):"
  if [ -f "$CAM_PAYLOAD" ]; then
    echo "  present: size=$(stat -c %s "$CAM_PAYLOAD" 2>/dev/null) bytes (CN 6.7.000280.0 expected size 200627029)"
  else
    echo "  absent -> PROPS-ONLY variant"
  fi
  echo "camera apk on device ($CAM_ON_DEVICE):"
  if [ -e "$CAM_ON_DEVICE" ]; then
    echo "  type=$(stat -c %F "$CAM_ON_DEVICE" 2>/dev/null) size=$(stat -c %s "$CAM_ON_DEVICE" 2>/dev/null)"
  else
    echo "  missing"
  fi
  echo "camera oat dir on device ($CAM_OAT_ON_DEVICE):"
  if [ -e "$CAM_OAT_ON_DEVICE" ]; then
    echo "  type=$(stat -c %F "$CAM_OAT_ON_DEVICE" 2>/dev/null) (Full variant: expect 'character special file' = hidden by the module)"
  else
    echo "  missing"
  fi
  echo "package versions:"
  for pkg in "$CAM_PKG" "$EDITOR_PKG"; do
    PKG_INFO=$(dumpsys package "$pkg" 2>/dev/null)
    echo "  [$pkg]"
    echo "$PKG_INFO" | grep -m2 -E 'versionName=|versionCode=' | sed 's/^ */    /'
    echo "$PKG_INFO" | grep -m1 'codePath=' | sed 's/^ */    /'
  done
  echo "last 40 lines of $LOG:"
  if [ -f "$LOG" ]; then
    tail -n 40 "$LOG" 2>/dev/null | sed 's/^/  /'
  else
    echo "  ($LOG not found; module may not have booted yet)"
  fi
  echo "manual follow-ups (run from a PC with adb):"
  echo "  adb logcat -d | grep -Ei 'LegendCloudManager|legendary|mediaeditor|hardwareAuthToken'"
  echo "  adb shell getprop | grep -iE 'leica|theme_customize|build.region'"
  echo "  adb shell mount | grep -E 'mi_ext|overlay'"
  echo "  adb shell ls -l /product/priv-app/MiuiCamera/"
  echo "  adb shell cmd package uninstall-system-updates com.android.camera  # if a GetApps/Play camera update shadows the module APK"
  echo "===== end diag ====="
} >> "$DIAG" 2>&1

tail -n 30 "$DIAG" 2>/dev/null
echo ""
echo "Diagnostics appended to: $DIAG"
echo "Share that file (or: adb pull $DIAG)."
