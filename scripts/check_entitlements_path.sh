#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
REL="OutingCheckerWidget/OutingCheckerWidgetExtension.entitlements"
ABS="$ROOT/$REL"

printf "Project root: %s\n" "$ROOT"
printf "Expected entitlements: %s\n" "$ABS"

if [[ -f "$ABS" ]]; then
  echo "OK: entitlements file exists."
else
  echo "ERROR: entitlements file not found at expected path."
  echo "Create or restore: $REL"
  exit 1
fi

cat <<'MSG'

Next in Xcode:
1) TARGETS > WidgetExtension > Build Settings
2) Set Code Signing Entitlements (Debug/Release):
   OutingCheckerWidget/OutingCheckerWidgetExtension.entitlements
3) If error remains, delete the broken file reference and re-add the file with:
   File > Add Files to "OutingChecker"...
4) Product > Clean Build Folder, then rebuild.
MSG
