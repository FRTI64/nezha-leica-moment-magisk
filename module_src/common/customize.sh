#!/system/bin/sh
# customize.sh -- Leica Moment Port (nezha).
#
# This file is SOURCED (not executed) by Magisk's module_installer.sh after all zip
# contents have been extracted into $MODPATH and the default permissions/secontext have
# been applied. Never call `exit` here (the installer still has cleanup to run); use
# `abort "message"` for fatal errors.
#
# Available: MAGISK_VER, MAGISK_VER_CODE, BOOTMODE, MODPATH, TMPDIR, ZIPFILE, ARCH,
#            IS64BIT, API; functions ui_print, abort, set_perm, set_perm_recursive.
# Docs: https://topjohnwu.github.io/Magisk/guides.html

SKIPUNZIP=0

ui_print "*****************************************"
ui_print " Leica Moment Port (nezha)               "
ui_print "*****************************************"

CAM_APK="$MODPATH/system/product/priv-app/MiuiCamera/MiuiCamera.apk"

if [ -f "$CAM_APK" ]; then
  ui_print "- Variant: FULL (CN MiuiCamera.apk payload present)"
  # The real /product partition still carries /product/priv-app/MiuiCamera/oat/arm64/
  # MiuiCamera.{odex,vdex} compiled for the OLD global APK. Declaring the directory in
  # REMOVE makes Magisk's installer create a dummy character device (mknod c 0 0) at
  # $MODPATH/system/product/priv-app/MiuiCamera/oat, which hides the stale ART artifacts
  # from the runtime and forces ART to recompile the replaced APK on the next boot.
  #
  # Magisk prepends "$MODPATH" to every REMOVE entry (util_functions.sh install_module():
  #   for TARGET in $REMOVE; do ... mknod $MODPATH$TARGET c 0 0; done
  # ), so the entry must start with "/system/" even for a /product path -- that is the
  # module's own payload prefix, NOT the on-device /system partition.
  # Docs: https://topjohnwu.github.io/Magisk/guides.html (Customization -> REMOVE)
  REMOVE="/system/product/priv-app/MiuiCamera/oat"
  ui_print "- Will hide stale camera oat/vdex (ART recompiles the new APK)"
else
  ui_print "- Variant: PROPS ONLY (camera APK left untouched)"
fi

# Normalize permissions: directories 0755, files 0644, scripts executable.
set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in post-fs-data.sh service.sh uninstall.sh action.sh diag.sh; do
  if [ -f "$MODPATH/$f" ]; then
    set_perm "$MODPATH/$f" 0 0 0755
  fi
done

true
