#!/system/bin/sh
# action.sh -- Magisk "Action" button for Leica Moment Port (nezha).
#
# Magisk executes this file STANDALONE (not sourced) in its built-in console with
# BusyBox standalone mode enabled -- do not rely on installer variables/functions here.
# Keep it short: the real work is done by diag.sh (also runnable manually from a shell):
#   adb shell su -c 'sh <module-dir>/diag.sh'
#
# Output: appends a full snapshot to /data/adb/leica_moment/diag.log and prints it.

MODDIR=${0%/*}
DIAG=/data/adb/leica_moment/diag.log

echo "Leica Moment Port (nezha) -- on-device diagnostics"
echo "module dir: $MODDIR"
echo ""

if [ -f "$MODDIR/diag.sh" ]; then
  sh "$MODDIR/diag.sh"
else
  echo "ERROR: $MODDIR/diag.sh is missing from the module"
fi

echo ""
echo "Log file: $DIAG"
