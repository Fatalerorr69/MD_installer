#!/usr/bin/env bash

set -e

ROOT="$(dirname $(dirname "$0"))"
VM="$ROOT/version_manager"
STATE="$VM/state.json"
BACKUPS="$VM/backups"

# Detekce GUI nástroje s prioritou
detect_gui() {
    if command -v fzf >/dev/null 2>&1; then
        echo "fzf"
    elif command -v whiptail >/dev/null 2>&1; then
        echo "whiptail"
    elif command -v dialog >/dev/null 2>&1; then
        echo "dialog"
    else
        echo "text"
    fi
}

GUI=$(detect_gui)

# FZF menu funkce
fzf_menu() {
    local options=(
        "1 Zálohovat aktuální verzi"
        "2 Seznam verzí"
        "3 Přepnout verzi"
        "4 Synchronizace s Git (tagy)"
        "5 Generovat Changelog"
        "6 Zobrazit aktuální stav"
        "7 Konec"
    )
    
    printf '%s\n' "${options[@]}" | \
    fzf --height=40% --reverse --prompt="🔧 MD INSTALLER – Version Manager 6.0 > " \
        --header="Vyber akci:" \
        --preview="echo 'Vyberte akci pomocí šipek a Enter'" \
        --preview-window=bottom:1 | \
    cut -d' ' -f1
}

# Whiptail/Dialog menu
classic_menu() {
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

# FZF verze selection s preview
fzf_select_version() {
    local title="$1"
    ls "$BACKUPS" | \
    fzf --height=50% --reverse --prompt="🔍 $title > " \
        --header="Vyber verzi (↑↓ pro pohyb, Ctrl+R reload)" \
        --preview="tar -tzf '$BACKUPS/{}' 2>/dev/null | head -50" \
        --preview-window=right:60% \
        --bind "ctrl-r:reload(ls $BACKUPS)"
}

# Hlavní menu
main_menu() {
    case "$GUI" in
        "fzf") selection=$(fzf_menu) ;;
        "whiptail"|"dialog") selection=$(classic_menu) ;;
        "text") selection=$(text_menu) ;;
        *) echo "Není GUI nástroj"; exit 1 ;;
    esac
    
    echo "$selection"
}

# Zobrazení stavu
show_state() {
    CURRENT=$(jq -r .current_version "$STATE" 2>/dev/null || echo "N/A")
    LAST_BACKUP=$(jq -r .last_backup "$STATE" 2>/dev/null || echo "N/A")
    
    case "$GUI" in
        "fzf")
            echo "Aktuální stav instalátoru"
            echo "════════════════════════════"
            echo "📦 Aktuální verze: $CURRENT"
            echo "💾 Poslední záloha: $LAST_BACKUP"
            echo ""
            read -p "Stiskněte Enter pro pokračování..."
            ;;
        "whiptail"|"dialog")
            $GUI --title "Aktuální stav instalátoru" \
            --msgbox "Aktuální verze: $CURRENT\nPoslední záloha: $LAST_BACKUP" 12 60
            ;;
        *)
            echo "Aktuální verze: $CURRENT"
            echo "Poslední záloha: $LAST_BACKUP"
            echo ""
            ;;
    esac
}

# Seznam verzí
list_versions() {
    VERSIONS=$(ls "$BACKUPS" 2>/dev/null | sed 's/installer_//;s/.tar.gz//;s/.zip//' | sort -r)
    
    if [ -z "$VERSIONS" ]; then
        MSG="Žádné zálohy nebyly nalezeny."
    else
        MSG="Dostupné verze:\n$VERSIONS"
    fi
    
    case "$GUI" in
        "fzf")
            echo -e "$MSG" | fzf --height=50% --reverse --prompt="📋 Verze > " \
                --header="Dostupné verze (Enter pro zavření)" \
                --preview="echo '{}'" \
                --preview-window=bottom:1
            ;;
        "whiptail"|"dialog")
            $GUI --title "Dostupné verze" --msgbox "$MSG" 20 60
            ;;
        *)
            echo -e "$MSG"
            read -p "Stiskněte Enter pro pokračování..."
            ;;
    esac
}

# Výběr verze pro přepnutí
select_version_menu() {
    case "$GUI" in
        "fzf")
            VERSION=$(fzf_select_version "Přepnout na verzi")
            [ -n "$VERSION" ] && VERSION=$(echo "$VERSION" | sed 's/installer_//;s/.tar.gz//;s/.zip//')
            ;;
        "whiptail"|"dialog")
            VERSIONS=$(ls "$BACKUPS" | sed 's/installer_//;s/.tar.gz//;s/.zip//')
            VERSION=$(echo "$VERSIONS" | $GUI --menu "Vyber verzi:" 20 60 10 3>&1 1>&2 2>&3)
            ;;
        *)
            echo "Dostupné verze:"
            ls "$BACKUPS" | sed 's/installer_//;s/.tar.gz//;s/.zip//' | nl
            read -p "Vyber číslo verze: " num
            VERSION=$(ls "$BACKUPS" | sed 's/installer_//;s/.tar.gz//;s/.zip//' | sed -n "${num}p")
            ;;
    esac
    
    echo "$VERSION"
}

# Hlavní smyčka
while true; do
    case "$(main_menu)" in
        1|"1")
            bash "$VM/backup.sh"
            ;;
        2|"2")
            list_versions
            ;;
        3|"3")
            VERSION=$(select_version_menu)
            if [ -n "$VERSION" ]; then
                bash "$VM/switch.sh" use "$VERSION"
            fi
            ;;
        4|"4")
            bash "$VM/git_sync.sh"
            ;;
        5|"5")
            bash "$VM/changelog.sh"
            ;;
        6|"6")
            show_state
            ;;
        7|"7"|"")
            exit 0
            ;;
    esac
done
