#!/system/bin/sh
# service.sh -- Leica Moment Port (nezha), data hygiene.
#
# Runs in Magisk's late_start service stage (NON-BLOCKING, after boot).
#
# Why: replacing /product/priv-app/MiuiCamera/MiuiCamera.apk with the CN build makes the
# camera app see app data created by the previous (global) version. Prior art for
# Xiaomi camera APK swaps requires a one-time `pm clear com.android.camera`. This script
# does that once per CN camera version, only after verifying that the module replacement
# is actually active (file size + package version), and records success in a guard file.
#
#   guard file: /data/adb/leica_moment/.camera_cleared_<cn_camera_version>
#
# mediaeditor / gallery data is deliberately NOT cleared (that would reset the CTA /
# privacy acceptance state the cloud feature relies on).
#
# Toggle: CLEAR_CAMERA_DATA in /data/adb/leica_moment/config.env (default 1).

MODDIR=${0%/*}
DATA_DIR=/data/adb/leica_moment
CONF=$DATA_DIR/config.env
LOG=$DATA_DIR/module.log

CAM_PKG=com.android.camera
CAM_EXPECTED_VERSION=6.7.000280.0
CAM_EXPECTED_SIZE=200627029
CAM_PAYLOAD=$MODDIR/system/product/priv-app/MiuiCamera/MiuiCamera.apk
CAM_ON_DEVICE=/product/priv-app/MiuiCamera/MiuiCamera.apk
GUARD=$DATA_DIR/.camera_cleared_$CAM_EXPECTED_VERSION

mkdir -p "$DATA_DIR" 2>/dev/null

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] service: $*" >> "$LOG" 2>/dev/null
}

if [ -f "$LOG" ]; then
  LOG_SIZE=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  if [ "$LOG_SIZE" -gt 262144 ] 2>/dev/null; then
    mv -f "$LOG" "$LOG.old" 2>/dev/null
  fi
fi

# Read the runtime config (created by post-fs-data.sh; defaults survive a missing file).
CLEAR_CAMERA_DATA=1
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF" 2>/dev/null || log "WARN: failed to source $CONF -- default CLEAR_CAMERA_DATA=1 used"
fi
CLEAR_CAMERA_DATA=$(echo "$CLEAR_CAMERA_DATA" | tr -d '\r')
[ -n "$CLEAR_CAMERA_DATA" ] || CLEAR_CAMERA_DATA=1

# --- props-only variant: no camera payload, nothing to do --------------------
if [ ! -f "$CAM_PAYLOAD" ]; then
  log "no camera APK payload in the module -> props-only variant, skipping camera data clear"
  true
else

  # Wait for the framework (at most 120 s; boot_completed may already be 1).
  i=0
  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
    sleep 2
    i=$((i + 1))
  done
  log "boot_completed=$(getprop sys.boot_completed) after ${i} x 2 s wait"

  ON_SIZE=$(stat -c %s "$CAM_ON_DEVICE" 2>/dev/null)
  ON_VERSION=$(dumpsys package "$CAM_PKG" 2>/dev/null | grep -m1 'versionName=' | sed 's/.*versionName=//' | tr -d ' \r')
  CODE_PATH=$(dumpsys package "$CAM_PKG" 2>/dev/null | grep -m1 'codePath=' | sed 's/.*codePath=//' | tr -d ' \r')
  log "cn payload: version=$CAM_EXPECTED_VERSION size=$CAM_EXPECTED_SIZE"
  log "on device : version=$ON_VERSION size=$ON_SIZE codePath=$CODE_PATH"

  case "$CODE_PATH" in
    /data/app*)
      log "WARN: camera has a data-app update installed. An app-store camera update takes precedence over the module payload; if the check below fails run: cmd package uninstall-system-updates com.android.camera"
      ;;
  esac

  if [ "$ON_SIZE" != "$CAM_EXPECTED_SIZE" ] || [ "$ON_VERSION" != "$CAM_EXPECTED_VERSION" ]; then
    log "WARN: the CN camera APK is NOT active (size/version mismatch). Check that the module is enabled, that magic mount works for /product, and that no app-store camera update is installed (cmd package uninstall-system-updates com.android.camera); camera data left untouched."
  elif [ "$CLEAR_CAMERA_DATA" != "1" ]; then
    log "CLEAR_CAMERA_DATA=0 -> camera data left untouched"
  elif [ -f "$GUARD" ]; then
    log "camera data was already cleared for camera $CAM_EXPECTED_VERSION (guard: $GUARD)"
  else
    log "clearing $CAM_PKG data (one-time, needed after the APK replacement)"
    am force-stop "$CAM_PKG" >> "$LOG" 2>&1
    log "am force-stop $CAM_PKG -> $?"
    pm clear "$CAM_PKG" >> "$LOG" 2>&1
    PM_RC=$?
    log "pm clear $CAM_PKG -> $PM_RC"
    if [ "$PM_RC" -eq 0 ]; then
      echo "cleared $(date '+%Y-%m-%d %H:%M:%S') camera_version=$CAM_EXPECTED_VERSION" > "$GUARD"
      log "wrote guard: $GUARD"
      am force-stop "$CAM_PKG" >> "$LOG" 2>&1
    else
      log "WARN: pm clear failed; the data clear will be retried on the next boot"
    fi
  fi

fi

true
