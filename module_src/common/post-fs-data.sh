#!/system/bin/sh
# post-fs-data.sh -- Leica Moment Port (nezha), property layer.
#
# Runs in Magisk's post-fs-data stage: BLOCKING, before modules are mounted and before
# zygote starts; capped at 35 s. Keep it fast and non-interactive.
#
# resetprop -n is REQUIRED in this stage: it writes the property area directly and
# bypasses property_service. `setprop` would deadlock the boot process.
#   Magisk guides (Boot Scripts): "using setprop will deadlock the boot process! Please
#   use resetprop -n <prop> <value> instead."
#   Magisk tools (resetprop): "-n  set properties bypassing property_service"
#
# What is applied (toggles live in /data/adb/leica_moment/config.env):
#   LEICA_SKU_PROPS=1 (default) -> ro.theme_customize=LCC
#                                  ro.theme_leica=true
#                                  ro.boot.product.theme_customize=P1_Leica
#                                  ro.special_edition=true
#   REGION_SPOOF=1    (default) -> ro.miui.build.region=cn
#   Full variant only           -> camera.debug.safe.check.disable=true
#
# The media-editor 二次增强 (Leica look cloud) CTA predicate is:
#   Build.DEVICE == "nezha" && ro.theme_customize == "LCC"
#     && ro.miui.build.region.equalsIgnoreCase("cn")
# (evidence: mediaeditor MediaEditorProviderForGallery method_is_legend_available ->
#  mx/a.g() [DEVICE + ro.theme_customize] && r21/e.b() [ro.miui.build.region == "cn"]).
#
# Every action is logged to /data/adb/leica_moment/module.log.

MODDIR=${0%/*}
DATA_DIR=/data/adb/leica_moment
CONF=$DATA_DIR/config.env
LOG=$DATA_DIR/module.log

mkdir -p "$DATA_DIR" 2>/dev/null

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-fs-data: $*" >> "$LOG" 2>/dev/null
}

# Keep the runtime log bounded.
if [ -f "$LOG" ]; then
  LOG_SIZE=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  if [ "$LOG_SIZE" -gt 262144 ] 2>/dev/null; then
    mv -f "$LOG" "$LOG.old" 2>/dev/null
  fi
fi

# Create the runtime config with documented defaults on first boot.
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EOF'
# Leica Moment Port (nezha) -- runtime configuration
#
# Edit this file while the module is installed, then REBOOT: the values are read
# once per boot by post-fs-data.sh. Remove a line to fall back to its default.

# 1 = spoof ro.miui.build.region=cn. REQUIRED by the media-editor 二次增强 CTA
#     predicate. 0 = leave the ROM region untouched.
# WARNING: this makes the whole ROM report CN region to apps (OTA/region features,
# region-locked apps, theme store, cloud services). See README.md before enabling.
REGION_SPOOF=1

# 1 = set the Leica-edition SKU properties:
#       ro.theme_customize=LCC
#       ro.theme_leica=true
#       ro.boot.product.theme_customize=P1_Leica
#       ro.special_edition=true
#     0 = leave them untouched. Model/cert/attestation/region-marketname props are
#     NEVER set by this module (they would break Play Integrity / attestation).
LEICA_SKU_PROPS=1

# 1 = clear com.android.camera data once after the CN camera APK has been mounted
#     (FULL variant only); 0 = never touch camera data.
CLEAR_CAMERA_DATA=1
EOF
  chmod 0600 "$CONF" 2>/dev/null
  log "created default config: $CONF"
fi

# Defaults (used when a line is missing from the config).
REGION_SPOOF=1
LEICA_SKU_PROPS=1
CLEAR_CAMERA_DATA=1
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF" 2>/dev/null || log "WARN: failed to source $CONF -- built-in defaults used"
fi
# Tolerate Windows-style CRLF line endings in a hand-edited config.
REGION_SPOOF=$(echo "$REGION_SPOOF" | tr -d '\r')
LEICA_SKU_PROPS=$(echo "$LEICA_SKU_PROPS" | tr -d '\r')
CLEAR_CAMERA_DATA=$(echo "$CLEAR_CAMERA_DATA" | tr -d '\r')
[ -n "$REGION_SPOOF" ] || REGION_SPOOF=1
[ -n "$LEICA_SKU_PROPS" ] || LEICA_SKU_PROPS=1
[ -n "$CLEAR_CAMERA_DATA" ] || CLEAR_CAMERA_DATA=1

log "config: REGION_SPOOF=$REGION_SPOOF LEICA_SKU_PROPS=$LEICA_SKU_PROPS CLEAR_CAMERA_DATA=$CLEAR_CAMERA_DATA"
log "before: ro.theme_customize=$(getprop ro.theme_customize) ro.theme_leica=$(getprop ro.theme_leica) ro.miui.build.region=$(getprop ro.miui.build.region)"

# set_prop NAME VALUE -- resetprop -n (never setprop in this stage) + log.
set_prop() {
  if resetprop -n "$1" "$2"; then
    log "set $1=$2"
  else
    log "WARN: resetprop failed for $1=$2"
  fi
  true
}

if [ "$LEICA_SKU_PROPS" = "1" ]; then
  set_prop ro.theme_customize LCC
  set_prop ro.theme_leica true
  set_prop ro.boot.product.theme_customize P1_Leica
  set_prop ro.special_edition true
else
  log "LEICA_SKU_PROPS=0 -> Leica SKU properties NOT set by the module"
fi

# Camera-side debug switch read by the MiuiCamera settings class
# (camera.debug.safe.check.disable). Only meaningful with the CN camera payload.
if [ -f "$MODDIR/system/product/priv-app/MiuiCamera/MiuiCamera.apk" ]; then
  set_prop camera.debug.safe.check.disable true
fi

if [ "$REGION_SPOOF" = "1" ]; then
  set_prop ro.miui.build.region cn
  log "WARNING: REGION_SPOOF=1 -- the device now reports CN region to all apps (see README risks)"
else
  log "REGION_SPOOF=0 -> ro.miui.build.region left untouched"
fi

log "after: ro.theme_customize=$(getprop ro.theme_customize) ro.theme_leica=$(getprop ro.theme_leica) ro.miui.build.region=$(getprop ro.miui.build.region)"

true
