#!/usr/bin/env bash
set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"
BACKUPS="$VM/backups"

mkdir -p "$BACKUPS"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

# Zjištění typu vydání
release_type=$(whiptail --title "Typ verze" --radiolist "Vyber typ verze:" 15 60 5 \
"stable" "Stabilní verze" ON \
"beta" "Vývojová verze" OFF \
3>&1 1>&2 2>&3)

archive_tar="$BACKUPS/installer_${timestamp}_${release_type}.tar.gz"
archive_zip="$BACKUPS/installer_${timestamp}_${release_type}.zip"

echo "[INFO] Archivace verze: $archive_tar"
tar -czf "$archive_tar" "$ROOT"/md_super_installer_*

echo "[INFO] Archivace verze (zip): $archive_zip"
zip -q "$archive_zip" "$ROOT"/md_super_installer_*

jq --arg ver "$timestamp" --arg type "$release_type" \
   '.current_version=$ver | .last_backup=$type' \
   "$STATE" > "$STATE.tmp"

mv "$STATE.tmp" "$STATE"

whiptail --title "Hotovo" --msgbox "Záloha vytvořena:\n$archive_tar\n$archive_zip" 12 60
