#!/usr/bin/env bash
set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"
BACKUPS="$VM/backups"

mkdir -p "$BACKUPS"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
archive="$BACKUPS/installer_$timestamp.tar.gz"

# Získání aktuální verze
current_version=$(jq -r .current_version "$STATE")

echo "[INFO] Archivace aktuální verze: $current_version"
echo "[INFO] Cíl archivace: $archive"

# Archivace všech skriptů instalátoru
tar -czf "$archive" \
    "$ROOT/md_super_installer_win5.ps1" \
    "$ROOT/md_super_installer_linux5.sh" \
    "$ROOT/md_super_installer_termux5.sh" \
    2>/dev/null

# Uložení do state.json
jq --arg ver "$current_version" --arg time "$timestamp" \
   '.last_backup=$time' \
   "$STATE" > "$STATE.tmp"

mv "$STATE.tmp" "$STATE"

echo "[OK] Záloha vytvořena: $archive"
