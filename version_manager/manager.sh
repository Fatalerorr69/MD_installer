#!/usr/bin/env bash

set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"
BACKUPS="$VM/backups"

mkdir -p "$BACKUPS"

# Výchozí stav, pokud state.json neexistuje
if [ ! -f "$STATE" ]; then
    echo '{"current_version":"none","last_backup":"none"}' > "$STATE"
fi

# Detekce GUI nástroje
detect_gui() {
    if command -v whiptail >/dev/null 2>&1; then
        echo "whiptail"
    elif command -v dialog >/dev/null 2>&1; then
        echo "dialog"
    else
        echo "text"
    fi
}

GUI=$(detect_gui)

# Textové menu (fallback)
text_menu() {
    clear
    echo "╔══════════════════════════════════════╗"
    echo "║   MD INSTALLER – Version Manager 6.0 ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "1) Zálohovat aktuální verzi"
    echo "2) Seznam verzí"
    echo "3) Přepnout verzi"
    echo "4) Synchronizace s Git (tagy)"
    echo "5) Generovat Changelog"
    echo "6) Zobrazit aktuální stav"
    echo "7) Konec"
    echo ""
    read -p "Vyber možnost [1-7]: " choice
    echo "$choice"
}

# Hlavní menu
main_menu() {
    case "$GUI" in
        "whiptail"|"dialog")
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
            ;;
        "text")
            text_menu
            ;;
        *)
            echo "Není GUI nástroj. Používám textový režim."
            text_menu
            ;;
    esac
}

# Zobrazení stavu
show_state() {
    CURRENT=$(jq -r .current_version "$STATE")
    LAST_BACKUP=$(jq -r .last_backup "$STATE")
    
    case "$GUI" in
        "whiptail"|"dialog")
            $GUI --title "Aktuální stav instalátoru" \
            --msgbox "Aktuální verze: $CURRENT\nPoslední záloha: $LAST_BACKUP" 12 60
            ;;
        *)
            echo "=== Aktuální stav instalátoru ==="
            echo "Aktuální verze: $CURRENT"
            echo "Poslední záloha: $LAST_BACKUP"
            echo ""
            read -p "Stiskněte Enter pro pokračování..."
            ;;
    esac
}

# Seznam verzí
list_versions() {
    if [ ! -d "$BACKUPS" ] || [ -z "$(ls -A "$BACKUPS")" ]; then
        MSG="Žádné zálohy nebyly nalezeny."
    else
        VERSIONS=$(ls "$BACKUPS" 2>/dev/null | sed 's/installer_//;s/.tar.gz//;s/.zip//' | sort -r)
        MSG="Dostupné verze:\n$VERSIONS"
    fi
    
    case "$GUI" in
        "whiptail"|"dialog")
            $GUI --title "Dostupné verze" --msgbox "$MSG" 20 60
            ;;
        *)
            echo -e "$MSG"
            echo ""
            read -p "Stiskněte Enter pro pokračování..."
            ;;
    esac
}

# Výběr verze pro přepnutí
select_version_menu() {
    if [ ! -d "$BACKUPS" ] || [ -z "$(ls -A "$BACKUPS")" ]; then
        case "$GUI" in
            "whiptail"|"dialog")
                $GUI --title "Chyba" --msgbox "Žádné zálohy k dispozici" 10 40
                ;;
            *)
                echo "Žádné zálohy k dispozici"
                ;;
        esac
        echo ""
        return
    fi
    
    VERSIONS=$(ls "$BACKUPS" | sed 's/installer_//;s/.tar.gz//;s/.zip//')
    
    case "$GUI" in
        "whiptail"|"dialog")
            SELECTED=$(echo "$VERSIONS" | $GUI --menu "Vyber verzi:" 20 60 10 3>&1 1>&2 2>&3)
            ;;
        *)
            echo "Dostupné verze:"
            echo "$VERSIONS" | nl
            read -p "Vyber číslo verze (nebo 0 pro zpět): " num
            if [ "$num" = "0" ]; then
                SELECTED=""
            else
                SELECTED=$(echo "$VERSIONS" | sed -n "${num}p")
            fi
            ;;
    esac
    
    echo "$SELECTED"
}

# Hlavní smyčka
while true; do
    SELECTION=$(main_menu)
    
    case "$SELECTION" in
        1|"1")
            echo "Spouštím zálohování..."
            bash "$VM/backup.sh"
            ;;
        2|"2")
            list_versions
            ;;
        3|"3")
            VERSION=$(select_version_menu)
            if [ -n "$VERSION" ]; then
                echo "Přepínám na verzi: $VERSION"
                bash "$VM/switch.sh" use "$VERSION"
                # Aktualizovat stav
                jq --arg ver "$VERSION" '.current_version=$ver' "$STATE" > "$STATE.tmp"
                mv "$STATE.tmp" "$STATE"
            fi
            ;;
        4|"4")
            echo "Spouštím Git synchronizaci..."
            bash "$VM/git_sync.sh"
            ;;
        5|"5")
            echo "Spouštím generování changelogu..."
            bash "$VM/changelog.sh"
            ;;
        6|"6")
            show_state
            ;;
        7|"7"|"")
            echo "Ukončuji..."
            exit 0
            ;;
        *)
            case "$GUI" in
                "whiptail"|"dialog")
                    $GUI --title "Chyba" --msgbox "Neplatná volba: $SELECTION" 10 40
                    ;;
                *)
                    echo "Neplatná volba: $SELECTION"
                    read -p "Stiskněte Enter pro pokračování..."
                    ;;
            esac
            ;;
    esac
done
