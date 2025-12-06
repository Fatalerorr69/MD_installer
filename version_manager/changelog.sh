#!/usr/bin/env bash
set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
BACKUPS="$VM/backups"

A=$(ls "$BACKUPS" | whiptail --menu "Vyber první verzi:" 20 60 10 3>&1 1>&2 2>&3)
B=$(ls "$BACKUPS" | whiptail --menu "Vyber druhou verzi:" 20 60 10 3>&1 1>&2 2>&3)

tempA="/tmp/a_$$"
tempB="/tmp/b_$$"

mkdir -p "$tempA" "$tempB"

tar -xzf "$BACKUPS/$A" -C "$tempA"
tar -xzf "$BACKUPS/$B" -C "$tempB"

DIFF=$(diff -ru "$tempA" "$tempB" || true)

OUT="$VM/CHANGELOG_${A}_vs_${B}.md"

echo "# Changelog" > "$OUT"
echo "Porovnání verzí: $A vs $B" >> "$OUT"
echo "\n\`\`\`diff" >> "$OUT"
echo "$DIFF" >> "$OUT"
echo "\`\`\`" >> "$OUT"

whiptail --msgbox "Changelog vygenerován:\n$OUT" 15 60
