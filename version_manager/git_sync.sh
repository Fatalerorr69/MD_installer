#!/usr/bin/env bash
set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"

if ! command -v git >/dev/null; then
    whiptail --msgbox "Git není nainstalovaný." 10 60
    exit 1
fi

ACTION=$(whiptail --title "Git Sync" --menu "Vyber akci:" 15 60 4 \
"tag" "Vytvořit git tag z aktuální verze" \
"pull" "Stáhnout tagy z repa" \
"switch" "Přepnout na git tag" \
"exit" "Zavřít" 3>&1 1>&2 2>&3)

case "$ACTION" in

"tag")
    V=$(date +"v%Y%m%d-%H%M%S")
    git tag "$V"
    git push --tags
    whiptail --msgbox "Tag $V vytvořen." 10 60
    ;;

"pull")
    git fetch --tags
    whiptail --msgbox "Tagy staženy." 10 60
    ;;

"switch")
    TAG=$(git tag | whiptail --menu "Vyber verzi:" 20 60 10 3>&1 1>&2 2>&3)
    git checkout "$TAG"
    whiptail --msgbox "Přepnuto na verzi $TAG." 10 60
    ;;

esac
