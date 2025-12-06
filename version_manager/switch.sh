#!/usr/bin/env bash
set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"
BACKUPS="$VM/backups"

cmd="$1"
arg="$2"

list_versions() {
    echo "Dostupné verze:"
    ls "$BACKUPS" | sed 's/installer_//g;s/.tar.gz//g'
}

use_version() {
    local ver="$1"

    archive=$(ls "$BACKUPS" | grep "$ver" | head -n1)
    if [ -z "$archive" ]; then
        echo "[ERR] Verze '$ver' nenalezena!"
        exit 1
    fi

    echo "[INFO] Obnovuji verzi $ver..."

    tar -xzf "$BACKUPS/$archive" -C "$ROOT"

    jq --arg v "$ver" '.current_version=$v' "$STATE" > "$STATE.tmp"
    mv "$STATE.tmp" "$STATE"

    echo "[OK] Verze $ver aktivována!"
}

case "$cmd" in
    list)
        list_versions
        ;;
    use)
        use_version "$arg"
        ;;
    *)
        echo "Použití:"
        echo "./switch.sh list"
        echo "./switch.sh use <verze>"
        ;;
esac
