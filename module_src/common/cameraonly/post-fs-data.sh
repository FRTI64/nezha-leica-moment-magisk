#!/system/bin/sh
# post-fs-data.sh -- Leica Moment Port (nezha) CameraOnly variant: NO-OP by design.
#
# CameraOnly implements the user requirement "do not use property faking": this variant
# does not change ANY system property (no post-fs-data injection, no property-setting
# utility is invoked anywhere in the module). Feature gating is handled outside Magisk by
# the separate LSPosed module through direct method hooks.
#
# This file is intentionally only a boot marker so users can confirm in the log which
# variant booted; it does not affect the system at all.

MODDIR=${0%/*}
DATA_DIR=/data/adb/leica_moment
LOG=$DATA_DIR/module.log

mkdir -p "$DATA_DIR" 2>/dev/null
echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-fs-data: CameraOnly variant booted -- no system properties are changed by this module" >> "$LOG" 2>/dev/null

true
