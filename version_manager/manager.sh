#!/usr/bin/env bash

set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"

# Detekce GUI nástroje
if command -v whiptail >/dev/null 2>&1; then
    GUI="whiptail"
elif command -v dialog >/dev/null 2>&1; then
    GUI="dialog"
else
    echo "Nebyl nalezen whiptail ani dialog."
    exit 1
fi

menu() {
    $GUI --title "MD INSTALLER – Version Manager 6.0" \
    --menu "Vyber akci:" 20 60 10 \
        1 "Zálohovat aktuální verzi" \
        2 "Seznam verzí" \
        3 "Přepnout verzi" \
        4 "Synchronizace s Git (tagy)" \
        5 "Generovat Changelog" \
        6 "Zobrazit aktuální stav" \
        7 "Konec" \
    3>&1 1>&2 2>&3
}

show_state() {
    CURRENT=$(jq -r .current_version "$STATE")
    LAST_BACKUP=$(jq -r .last_backup "$STATE")

    $GUI --title "Aktuální stav instalátoru" \
    --msgbox "Aktuální verze: $CURRENT\nPoslední záloha: $LAST_BACKUP" 12 60
}

case "$(menu)" in
    1)
        bash "$VM/backup.sh"
        ;;
    2)
        VERSIONS=$(ls "$VM/backups" | sed 's/installer_//;s/.tar.gz//')
        $GUI --title "Dostupné verze" --msgbox "$VERSIONS" 20 60
        ;;
    3)
        VERSION=$(ls "$VM/backups" | sed 's/installer_//;s/.tar.gz//' | $GUI --menu "Vyber verzi:" 20 60 10 3>&1 1>&2 2>&3)
        bash "$VM/switch.sh" use "$VERSION"
        ;;
    4)
        bash "$VM/git_sync.sh"
        ;;
    5)
        bash "$VM/changelog.sh"
        ;;
    6)
        show_state
        ;;
    7)
        exit 0
        ;;
esac
