#!/system/bin/sh
# customize.sh -- Leica Moment Port (nezha) CameraOnly variant.
#
# This file is SOURCED (not executed) by Magisk's module_installer.sh after all zip
# contents have been extracted into $MODPATH and the default permissions/secontext applied.
# Never call `exit` here (use `abort "message"` for fatal errors).
#
# CameraOnly = CN MiuiCamera APK replacement ONLY. This variant makes NO system-property
# changes of any kind (see post-fs-data.sh, which is a no-op marker) and never invokes a
# property-setting tool. Gating is left to the separate LSPosed module (method hooks).
#
# Available: MAGISK_VER, MAGISK_VER_CODE, BOOTMODE, MODPATH, TMPDIR, ZIPFILE, ARCH,
#            IS64BIT, API; functions ui_print, abort, set_perm, set_perm_recursive.

SKIPUNZIP=0

ui_print "******************************************"
ui_print " Leica Moment Port (nezha) - CameraOnly  "
ui_print "******************************************"
ui_print "- No system properties are modified by this variant."

CAM_APK="$MODPATH/system/product/priv-app/MiuiCamera/MiuiCamera.apk"

if [ -f "$CAM_APK" ]; then
  ui_print "- CN MiuiCamera.apk payload present (6.7.000280.0)"
  # The real /product partition still carries /product/priv-app/MiuiCamera/oat/arm64/
  # MiuiCamera.{odex,vdex} compiled for the OLD global APK. Declaring the directory in
  # REMOVE makes Magisk's installer create a dummy character device (mknod c 0 0) at
  # $MODPATH/system/product/priv-app/MiuiCamera/oat, hiding the stale ART artifacts and
  # forcing ART to recompile the replaced APK on the next boot.
  #
  # Magisk prepends "$MODPATH" to every REMOVE entry (util_functions.sh install_module():
  #   for TARGET in $REMOVE; do ... mknod $MODPATH$TARGET c 0 0; done
  # ), so the entry must start with "/system/" even for a /product path.
  REMOVE="/system/product/priv-app/MiuiCamera/oat"
  ui_print "- Will hide stale camera oat/vdex (ART recompiles the new APK)"
else
  ui_print "! Camera payload missing from this build -- installation will have no effect"
fi

# Normalize permissions: directories 0755, files 0644, scripts executable.
set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in post-fs-data.sh service.sh uninstall.sh action.sh diag.sh; do
  if [ -f "$MODPATH/$f" ]; then
    set_perm "$MODPATH/$f" 0 0 0755
  fi
done

true
