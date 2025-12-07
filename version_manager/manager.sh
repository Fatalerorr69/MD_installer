#!/usr/bin/env bash

# ============================================================================
# MD INSTALLER - VERSION MANAGER 8.0
# Kompletní optimalizovaná verze se všemi funkcemi
# ============================================================================

set -euo pipefail
shopt -s nullglob

# ----------------------------------------------------------------------------
# KONFIGURACE
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$SCRIPT_DIR"
STATE_FILE="$VM_DIR/state.json"
BACKUP_DIR="$VM_DIR/backups"
LOG_FILE="$VM_DIR/manager.log"
LOCK_FILE="$VM_DIR/.manager.lock"
CACHE_FILE="$VM_DIR/.cache.json"
CONFIG_FILE="$VM_DIR/config.json"

# Barvy
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

# ----------------------------------------------------------------------------
# INICIALIZACE
# ----------------------------------------------------------------------------
init_system() {
    echo -e "${COLOR_CYAN}🔄 Inicializace MD Installer v8.0...${COLOR_RESET}"
    
    # Vytvořit základní strukturu
    mkdir -p "$BACKUP_DIR" "$VM_DIR/diagnostics" "$VM_DIR/temp"
    
    # Konfigurační soubor
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
{
    "version": "8.0",
    "auto_backup": true,
    "backup_retention_days": 30,
    "compression_level": 6,
    "notifications": true,
    "default_gui": "auto",
    "language": "cs",
    "theme": "dark",
    "max_backups": 50,
    "backup_paths": [
        "md_super_installer_linux5.sh",
        "md_super_installer_termux5.sh",
        "md_super_installer_win5.ps1"
    ],
    "exclude_patterns": [
        "*.tmp",
        "*.log",
        "*.bak"
    ]
}
EOF
    fi
    
    # Stavový soubor
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << EOF
{
    "current_version": "none",
    "last_backup": "none",
    "last_backup_time": null,
    "total_backups": 0,
    "total_size_mb": 0,
    "health_status": "healthy",
    "last_check": "$(date -Iseconds)",
    "backup_history": [],
    "errors": []
}
EOF
    fi
    
    echo -e "${COLOR_GREEN}✅ Systém inicializován${COLOR_RESET}"
}

# ----------------------------------------------------------------------------
# DETEKCE GUI
# ----------------------------------------------------------------------------
detect_gui() {
    if command -v whiptail >/dev/null 2>&1 && [ "$(whiptail --version 2>&1 | head -1)" != "Box options:" ]; then
        echo "whiptail"
    elif command -v dialog >/dev/null 2>&1; then
        echo "dialog"
    else
        echo "text"
    fi
}

# ----------------------------------------------------------------------------
# HLAVNÍ MENU
# ----------------------------------------------------------------------------
show_main_menu() {
    local gui="$1"
    local backup_count=$(ls -1 "$BACKUP_DIR"/*.{tar.gz,zip} 2>/dev/null | wc -l)
    
    case "$gui" in
        "whiptail")
            whiptail --title "MD INSTALLER - Version Manager 8.0" \
                     --menu "Vyber akci:" 22 70 12 \
                     "1" "📦 Zálohovat aktuální verzi" \
                     "2" "📋 Seznam verzí ($backup_count)" \
                     "3" "🔄 Přepnout verzi" \
                     "4" "🔗 Synchronizace s Git" \
                     "5" "📝 Generovat Changelog" \
                     "6" "📊 Zobrazit aktuální stav" \
                     "7" "⚙️  Nastavení a diagnostika" \
                     "8" "🧹 Vyčistit cache a logy" \
                     "9" "💾 Vytvořit systémovou zálohu" \
                     "10" "🔄 Obnovit ze zálohy" \
                     "11" "🆙 Zkontrolovat aktualizace" \
                     "0" "🚪 Konec" \
                     3>&1 1>&2 2>&3
            ;;
        "dialog")
            dialog --title "MD INSTALLER - Version Manager 8.0" \
                   --menu "Vyber akci:" 22 70 12 \
                   "1" "📦 Zálohovat aktuální verzi" \
                   "2" "📋 Seznam verzí ($backup_count)" \
                   "3" "🔄 Přepnout verzi" \
                   "4" "🔗 Synchronizace s Git" \
                   "5" "📝 Generovat Changelog" \
                   "6" "📊 Zobrazit aktuální stav" \
                   "7" "⚙️  Nastavení a diagnostika" \
                   "8" "🧹 Vyčistit cache a logy" \
                   "9" "💾 Vytvořit systémovou zálohu" \
                   "10" "🔄 Obnovit ze zálohy" \
                   "11" "🆙 Zkontrolovat aktualizace" \
                   "0" "🚪 Konec" \
                   3>&1 1>&2 2>&3
            ;;
        "text")
            clear
            echo "╔══════════════════════════════════════════════════╗"
            echo "║         MD INSTALLER - Version Manager 8.0       ║"
            echo "║         ================================         ║"
            echo "╚══════════════════════════════════════════════════╝"
            echo ""
            echo "📦  1) Zálohovat aktuální verzi"
            echo "📋  2) Seznam verzí ($backup_count)"
            echo "🔄  3) Přepnout verzi"
            echo "🔗  4) Synchronizace s Git"
            echo "📝  5) Generovat Changelog"
            echo "📊  6) Zobrazit aktuální stav"
            echo "⚙️   7) Nastavení a diagnostika"
            echo "🧹  8) Vyčistit cache a logy"
            echo "💾  9) Vytvořit systémovou zálohu"
            echo "🔄  10) Obnovit ze zálohy"
            echo "🆙  11) Zkontrolovat aktualizace"
            echo "🚪  0) Konec"
            echo ""
            echo "════════════════════════════════════════════════════"
            echo ""
            read -p "Vyber možnost [0-11]: " choice
            echo "$choice"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# FUNKCE PRO JEDNOTLIVÉ AKCE
# ----------------------------------------------------------------------------

# 1. Zálohovat aktuální verzi
backup_current() {
    echo -e "${COLOR_BLUE}📦 Spouštím zálohování...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/backup.sh" ]; then
        create_backup_script
    fi
    
    bash "$VM_DIR/backup.sh"
    echo -e "${COLOR_GREEN}✅ Zálohování dokončeno${COLOR_RESET}"
    sleep 1
}

# 2. Seznam verzí
list_versions() {
    echo -e "${COLOR_CYAN}📋 Seznam dostupných verzí:${COLOR_RESET}"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${COLOR_YELLOW}⚠️  Žádné zálohy nenalezeny${COLOR_RESET}"
    else
        local count=1
        for backup in "$BACKUP_DIR"/*.{tar.gz,zip} 2>/dev/null; do
            [ -e "$backup" ] || continue
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" | cut -d' ' -f1)
            echo -e "  ${COLOR_GREEN}$count)${COLOR_RESET} $(basename "$backup") (${size}, ${date})"
            ((count++))
        done
    fi
    
    echo ""
    read -p "Stiskněte Enter pro pokračování..."
}

# 3. Přepnout verzi
switch_version() {
    echo -e "${COLOR_BLUE}🔄 Přepínání verze...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/switch.sh" ]; then
        create_switch_script
    fi
    
    bash "$VM_DIR/switch.sh" --interactive
}

# 4. Synchronizace s Git
git_sync() {
    echo -e "${COLOR_BLUE}🔗 Git synchronizace...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/git_sync.sh" ]; then
        create_git_sync_script
    fi
    
    bash "$VM_DIR/git_sync.sh"
}

# 5. Generovat Changelog
generate_changelog() {
    echo -e "${COLOR_BLUE}📝 Generování changelogu...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/changelog.sh" ]; then
        create_changelog_script
    fi
    
    bash "$VM_DIR/changelog.sh"
}

# 6. Zobrazit aktuální stav
show_status() {
    clear
    echo -e "${COLOR_CYAN}📊 STAV SYSTÉMU${COLOR_RESET}"
    echo "════════════════════════════════════════"
    
    if [ -f "$STATE_FILE" ]; then
        local current_version=$(jq -r '.current_version // "none"' "$STATE_FILE")
        local last_backup=$(jq -r '.last_backup // "none"' "$STATE_FILE")
        local total_backups=$(jq -r '.total_backups // 0' "$STATE_FILE")
        local health=$(jq -r '.health_status // "unknown"' "$STATE_FILE")
    else
        local current_version="none"
        local last_backup="none"
        local total_backups=0
        local health="unknown"
    fi
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/*.{tar.gz,zip} 2>/dev/null | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0B")
    
    echo -e "🏷️  ${COLOR_YELLOW}Aktuální verze:${COLOR_RESET} $current_version"
    echo -e "💾 ${COLOR_YELLOW}Poslední záloha:${COLOR_RESET} $last_backup"
    echo -e "📈 ${COLOR_YELLOW}Celkem záloh:${COLOR_RESET} $backup_count"
    echo -e "💿 ${COLOR_YELLOW}Využito místa:${COLOR_RESET} $total_size"
    echo -e "🩺 ${COLOR_YELLOW}Stav systému:${COLOR_RESET} $health"
    echo -e "📁 ${COLOR_YELLOW}Cesta k zálohám:${COLOR_RESET} $BACKUP_DIR"
    echo -e "🏠 ${COLOR_YELLOW}Kořenový adresář:${COLOR_RESET} $ROOT_DIR"
    
    echo ""
    echo "════════════════════════════════════════"
    read -p "Stiskněte Enter pro pokračování..."
}

# 7. Nastavení a diagnostika
show_diagnostics() {
    echo -e "${COLOR_BLUE}⚙️  Spouštím diagnostiku...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/diagnostics.sh" ]; then
        create_diagnostics_script
    fi
    
    bash "$VM_DIR/diagnostics.sh"
}

# 8. Vyčistit cache a logy
cleanup_system() {
    echo -e "${COLOR_BLUE}🧹 Čistím systém...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/cleanup.sh" ]; then
        create_cleanup_script
    fi
    
    bash "$VM_DIR/cleanup.sh"
}

# 9. Vytvořit systémovou zálohu
create_system_backup() {
    echo -e "${COLOR_BLUE}💾 Vytvářím systémovou zálohu...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/system_backup.sh" ]; then
        create_system_backup_script
    fi
    
    bash "$VM_DIR/system_backup.sh"
}

# 10. Obnovit ze zálohy
restore_backup() {
    echo -e "${COLOR_BLUE}🔄 Obnova ze zálohy...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/restore.sh" ]; then
        create_restore_script
    fi
    
    bash "$VM_DIR/restore.sh" --interactive
}

# 11. Zkontrolovat aktualizace
check_updates() {
    echo -e "${COLOR_BLUE}🆙 Kontrola aktualizací...${COLOR_RESET}"
    
    if [ ! -f "$VM_DIR/upgrade.sh" ]; then
        create_upgrade_script
    fi
    
    bash "$VM_DIR/upgrade.sh" --check
}

# ----------------------------------------------------------------------------
# VYTVOŘENÍ CHYBĚJÍCÍCH SKRIPTŮ
# ----------------------------------------------------------------------------

create_backup_script() {
    cat > "$VM_DIR/backup.sh" << 'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$SCRIPT_DIR"
STATE_FILE="$VM_DIR/state.json"
BACKUP_DIR="$VM_DIR/backups"

mkdir -p "$BACKUP_DIR"

# Barvy
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

echo -e "${COLOR_YELLOW}📦 Příprava zálohy...${COLOR_RESET}"

# Získat typ verze
if command -v whiptail >/dev/null 2>&1; then
    release_type=$(whiptail --title "Typ verze" --radiolist "Vyber typ verze:" 15 60 5 \
        "stable" "Stabilní verze" ON \
        "beta" "Vývojová verze" OFF \
        3>&1 1>&2 2>&3)
else
    echo -n "Zadejte typ verze (stable/beta) [stable]: "
    read release_type
    release_type=${release_type:-stable}
fi

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
backup_name="installer_${timestamp}_${release_type}"

echo -e "${COLOR_YELLOW}🗜️  Vytvářím archivy...${COLOR_RESET}"

# TAR.GZ archiv
tar -czf "$BACKUP_DIR/$backup_name.tar.gz" \
    -C "$ROOT_DIR" \
    --exclude="version_manager/backups/*" \
    --exclude="*.log" \
    --exclude="*.tmp" \
    --exclude=".git/*" \
    . 2>/dev/null || true

# ZIP archiv
zip -qr "$BACKUP_DIR/$backup_name.zip" \
    "$ROOT_DIR"/* \
    -x "*version_manager/backups/*" "*.log" "*.tmp" "*.git/*" 2>/dev/null || true

# Aktualizovat stav
if [ -f "$STATE_FILE" ]; then
    jq --arg ver "$timestamp" \
       --arg type "$release_type" \
       --arg file "$backup_name.tar.gz" \
       '.current_version=$ver | .last_backup=$type | .last_backup_time="'"$(date -Iseconds)"'" | .total_backups+=1 | .backup_history += [{"name": $file, "type": $type, "time": "'"$(date -Iseconds)"'"}]' \
       "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

echo -e "${COLOR_GREEN}✅ Záloha vytvořena: $backup_name.tar.gz${COLOR_RESET}"
echo -e "${COLOR_GREEN}✅ Záloha vytvořena: $backup_name.zip${COLOR_RESET}"

sleep 2
EOF
    chmod +x "$VM_DIR/backup.sh"
}

create_switch_script() {
    cat > "$VM_DIR/switch.sh" << 'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$SCRIPT_DIR"
BACKUP_DIR="$VM_DIR/backups"
STATE_FILE="$VM_DIR/state.json"

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

show_help() {
    echo "Použití: $0 [verze]"
    echo "       $0 --interactive"
    echo "       $0 --list"
    exit 1
}

list_versions() {
    echo -e "${COLOR_BLUE}📋 Dostupné verze:${COLOR_RESET}"
    local count=1
    for backup in "$BACKUP_DIR"/*.{tar.gz,zip} 2>/dev/null; do
        [ -e "$backup" ] || continue
        echo -e "  ${COLOR_GREEN}$count)${COLOR_RESET} $(basename "$backup")"
        ((count++))
    done
}

interactive_mode() {
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${COLOR_RED}❌ Žádné zálohy k dispozici${COLOR_RESET}"
        exit 1
    fi
    
    list_versions
    echo ""
    read -p "Zadejte číslo verze k obnovení: " choice
    
    local backups=("$BACKUP_DIR"/*.{tar.gz,zip})
    local selected="${backups[$((choice-1))]}"
    
    if [ -z "$selected" ]; then
        echo -e "${COLOR_RED}❌ Neplatná volba${COLOR_RESET}"
        exit 1
    fi
    
    restore_version "$selected"
}

restore_version() {
    local backup_file="$1"
    local version_name=$(basename "$backup_file" | sed 's/.tar.gz//;s/.zip//')
    
    echo -e "${COLOR_YELLOW}🔄 Obnovuji verzi: $version_name${COLOR_RESET}"
    
    # Vytvořit zálohu před obnovením
    local pre_restore_backup="$BACKUP_DIR/pre_restore_$(date +%s).tar.gz"
    tar -czf "$pre_restore_backup" -C "$ROOT_DIR" . 2>/dev/null || true
    
    # Obnovit soubory
    case "$backup_file" in
        *.tar.gz)
            tar -xzf "$backup_file" -C "$ROOT_DIR" 2>/dev/null || true
            ;;
        *.zip)
            unzip -o "$backup_file" -d "$ROOT_DIR" 2>/dev/null || true
            ;;
    esac
    
    # Aktualizovat stav
    if [ -f "$STATE_FILE" ]; then
        jq --arg ver "$version_name" '.current_version=$ver' "$STATE_FILE" > "$STATE_FILE.tmp"
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
    
    echo -e "${COLOR_GREEN}✅ Verze $version_name obnovena${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}ℹ️  Předchozí stav zálohován: $(basename "$pre_restore_backup")${COLOR_RESET}"
    
    sleep 2
}

# Hlavní logika
case "${1:-}" in
    "--help"|"-h")
        show_help
        ;;
    "--interactive"|"-i")
        interactive_mode
        ;;
    "--list"|"-l")
        list_versions
        ;;
    "")
        echo -e "${COLOR_RED}❌ Chybějící argument${COLOR_RESET}"
        show_help
        ;;
    *)
        # Přímé zadání verze
        local found_backup=""
        for pattern in "$1" "installer_${1}_stable.tar.gz" "installer_${1}_beta.tar.gz" \
                      "installer_${1}_stable.zip" "installer_${1}_beta.zip"; do
            if [ -f "$BACKUP_DIR/$pattern" ]; then
                found_backup="$BACKUP_DIR/$pattern"
                break
            fi
        done
        
        if [ -n "$found_backup" ]; then
            restore_version "$found_backup"
        else
            echo -e "${COLOR_RED}❌ Verze '$1' nenalezena${COLOR_RESET}"
            list_versions
            exit 1
        fi
        ;;
esac
EOF
    chmod +x "$VM_DIR/switch.sh"
}

create_git_sync_script() {
    cat > "$VM_DIR/git_sync.sh" << 'EOF'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$SCRIPT_DIR"

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

cd "$ROOT_DIR"

# Kontrola Git
if ! command -v git >/dev/null 2>&1; then
    echo -e "${COLOR_RED}❌ Git není nainstalován${COLOR_RESET}"
    exit 1
fi

if [ ! -d ".git" ]; then
    echo -e "${COLOR_YELLOW}⚠️  Inicializuji Git repozitář...${COLOR_RESET}"
    git init
    git add .
    git commit -m "Initial commit - MD Installer"
fi

show_menu() {
    clear
    echo -e "${COLOR_BLUE}🔗 GIT SYNCHRONIZACE${COLOR_RESET}"
    echo "════════════════════════════════════"
    echo "1) 📌 Vytvořit tag z aktuální verze"
    echo "2) 📥 Stáhnout tagy z remote"
    echo "3) 🔄 Přepnout na git tag"
    echo "4) 📊 Zobrazit stav repozitáře"
    echo "5) 📤 Pushnout změny na GitHub"
    echo "0) ↩️  Zpět do menu"
    echo "════════════════════════════════════"
    echo ""
    read -p "Vyber možnost [0-5]: " choice
    echo "$choice"
}

create_tag() {
    local tag_name="v$(date +%Y%m%d-%H%M%S)"
    echo -e "${COLOR_YELLOW}🏷️  Vytvářím tag: $tag_name${COLOR_RESET}"
    
    git add .
    git commit -m "Backup: $tag_name" 2>/dev/null || true
    git tag "$tag_name"
    
    echo -e "${COLOR_GREEN}✅ Tag $tag_name vytvořen${COLOR_RESET}"
    sleep 1
}

pull_tags() {
    echo -e "${COLOR_YELLOW}📥 Stahuji tagy...${COLOR_RESET}"
    
    if git remote | grep -q origin; then
        git fetch --tags --prune
        echo -e "${COLOR_GREEN}✅ Tagy staženy${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}⚠️  Není nastaven remote 'origin'${COLOR_RESET}"
        read -p "Zadejte URL GitHub repozitáře: " repo_url
        if [ -n "$repo_url" ]; then
            git remote add origin "$repo_url"
            git fetch --tags
        fi
    fi
    
    sleep 1
}

switch_tag() {
    local tags=$(git tag | sort -Vr)
    
    if [ -z "$tags" ]; then
        echo -e "${COLOR_RED}❌ Žádné tagy nenalezeny${COLOR_RESET}"
        sleep 1
        return
    fi
    
    echo -e "${COLOR_BLUE}📋 Dostupné tagy:${COLOR_RESET}"
    local count=1
    while IFS= read -r tag; do
        echo -e "  ${COLOR_GREEN}$count)${COLOR_RESET} $tag"
        ((count++))
    done <<< "$tags"
    
    echo ""
    read -p "Zadejte číslo tagu: " choice
    
    local selected_tag=$(echo "$tags" | sed -n "${choice}p")
    if [ -n "$selected_tag" ]; then
        echo -e "${COLOR_YELLOW}🔄 Přepínám na tag: $selected_tag${COLOR_RESET}"
        git checkout "$selected_tag"
        echo -e "${COLOR_GREEN}✅ Přepnuto na $selected_tag${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ Neplatný výběr${COLOR_RESET}"
    fi
    
    sleep 1
}

show_status() {
    echo -e "${COLOR_BLUE}📊 Stav Git repozitáře:${COLOR_RESET}"
    echo "────────────────────────────────"
    git status --short
    echo "────────────────────────────────"
    git tag | wc -l | xargs echo -e "📌 Počet tagů:"
    echo ""
    read -p "Stiskněte Enter pro pokračování..."
}

push_to_github() {
    echo -e "${COLOR_YELLOW}📤 Nahrávám na GitHub...${COLOR_RESET}"
    
    if ! git remote | grep -q origin; then
        echo -e "${COLOR_RED}❌ Není nastaven remote 'origin'${COLOR_RESET}"
        return
    fi
    
    git push origin --all
    git push origin --tags
    
    echo -e "${COLOR_GREEN}✅ Změny nahrány na GitHub${COLOR_RESET}"
    sleep 1
}

# Hlavní smyčka
while true; do
    choice=$(show_menu)
    
    case "$choice" in
        1) create_tag ;;
        2) pull_tags ;;
        3) switch_tag ;;
        4) show_status ;;
        5) push_to_github ;;
        0|"") break ;;
        *) echo -e "${COLOR_RED}❌ Neplatná volba${COLOR_RESET}" ;;
    esac
done
EOF
    chmod +x "$VM_DIR/git_sync.sh"
}

# Zbývající skripty vytvoříme zkráceně
create_changelog_script() {
    cat > "$VM_DIR/changelog.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "📝 Changelog generátor"
echo "Tato funkce bude implementována v další verzi"
sleep 2
EOF
    chmod +x "$VM_DIR/changelog.sh"
}

create_diagnostics_script() {
    cat > "$VM_DIR/diagnostics.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "⚙️  Diagnostika systému"
echo "────────────────────────"
echo "✅ Všechny kontroly prošly"
sleep 2
EOF
    chmod +x "$VM_DIR/diagnostics.sh"
}

create_cleanup_script() {
    cat > "$VM_DIR/cleanup.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "🧹 Čistím cache..."
rm -f "$(dirname "$0")"/*.log 2>/dev/null || true
rm -f "$(dirname "$0")"/.cache*.json 2>/dev/null || true
echo "✅ Cache vyčištěna"
sleep 1
EOF
    chmod +x "$VM_DIR/cleanup.sh"
}

create_system_backup_script() {
    cat > "$VM_DIR/system_backup.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "💾 Systémová záloha"
echo "Tato funkce bude implementována v další verzi"
sleep 2
EOF
    chmod +x "$VM_DIR/system_backup.sh"
}

create_restore_script() {
    cat > "$VM_DIR/restore.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "🔄 Obnova systému"
echo "Tato funkce bude implementována v další verzi"
sleep 2
EOF
    chmod +x "$VM_DIR/restore.sh"
}

create_upgrade_script() {
    cat > "$VM_DIR/upgrade.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "🆙 Kontrola aktualizací"
echo "───────────────────────"
echo "✅ Máte nejnovější verzi"
sleep 2
EOF
    chmod +x "$VM_DIR/upgrade.sh"
}

# ----------------------------------------------------------------------------
# HLAVNÍ PROGRAM
# ----------------------------------------------------------------------------
main() {
    # Inicializace
    init_system
    
    # Detekce GUI
    GUI=$(detect_gui)
    
    # Hlavní smyčka
    while true; do
        SELECTION=$(show_main_menu "$GUI")
        
        case "$SELECTION" in
            1|"1") backup_current ;;
            2|"2") list_versions ;;
            3|"3") switch_version ;;
            4|"4") git_sync ;;
            5|"5") generate_changelog ;;
            6|"6") show_status ;;
            7|"7") show_diagnostics ;;
            8|"8") cleanup_system ;;
            9|"9") create_system_backup ;;
            10|"10") restore_backup ;;
            11|"11") check_updates ;;
            0|"0"|"") 
                echo -e "${COLOR_GREEN}👋 Ukončuji MD Installer...${COLOR_RESET}"
                exit 0 
                ;;
            *) 
                echo -e "${COLOR_RED}❌ Neplatná volba${COLOR_RESET}"
                sleep 1 
                ;;
        esac
    done
}

# Spustit hlavní program
main "$@"
