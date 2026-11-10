#!/system/bin/sh
# uninstall.sh -- Leica Moment Port (nezha), runs when Magisk removes the module.
#
# The APK replacement, the hidden /product oat artifacts and all properties are
# magic-mount / runtime based: nothing on the real partitions was modified, so after
# removing the module and rebooting the global ROM is back to stock (the original
# MiuiCamera.apk and its oat/vdex reappear automatically).
#
# Only the module's runtime data directory is cleaned here. Note: camera app data that
# the module cleared once cannot be restored.

DATA_DIR=/data/adb/leica_moment

rm -rf "$DATA_DIR" 2>/dev/null

true
