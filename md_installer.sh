#!/usr/bin/env bash
# md_installer.sh - HLAVNÍ VSTUPNÍ BOD PROJEKTU

set -euo pipefail

# ==============================================================================
# KONFIGURACE A INICIALIZACE
# ==============================================================================

readonly VERSION="7.0.0"
readonly PROJECT_NAME="MD Installer"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VM_DIR="$PROJECT_ROOT/version_manager"
readonly LOG_FILE="$VM_DIR/logs/md_installer.log"
readonly CONFIG_FILE="$VM_DIR/config/config.json"

# Barvy pro výstup
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ==============================================================================
# FUNKCE PRO INICIALIZACI A KONTROLU
# ==============================================================================

init_project() {
    echo -e "${CYAN}🔄 Inicializace $PROJECT_NAME v$VERSION...${NC}"
    
    # Vytvoření potřebných adresářů
    local dirs=(
        "$VM_DIR/backups"
        "$VM_DIR/logs"
        "$VM_DIR/config"
        "$VM_DIR/tmp"
        "$VM_DIR/plugins"
        "$VM_DIR/state"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "DEBUG" "Vytvořen adresář: $dir"
        fi
    done
    
    # Vytvoření základní konfigurace
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_config
    fi
    
    # Kontrola závislostí
    check_dependencies
    
    # Inicializace logování
    init_logging
}

create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "1.0.0",
  "system": {
    "platform": "auto",
    "language": "cs_CZ",
    "log_level": "INFO"
  },
  "backup": {
    "compression": "tar.gz",
    "encryption": false,
    "retention_days": 30,
    "max_backups": 50,
    "exclude_patterns": [
      "*.log",
      "*.tmp",
      "*.temp",
      ".git/*",
      "node_modules/*"
    ]
  },
  "gui": {
    "default": "auto",
    "theme": "dark",
    "enable_animations": true
  },
  "cloud": {
    "enabled": false,
    "auto_sync": false,
    "providers": []
  },
  "notifications": {
    "enabled": true,
    "on_backup_complete": true,
    "on_error": true
  }
}
EOF
    log "INFO" "Vytvořena výchozí konfigurace"
}

check_dependencies() {
    echo -e "${BLUE}🔍 Kontrola závislostí...${NC}"
    
    local missing_deps=()
    
    # Základní systémové nástroje
    check_dependency "bash" "Bash shell" "4.0+" "--version"
    check_dependency "tar" "Tar archiver" "" "--version"
    check_dependency "gzip" "Gzip komprese" "" "--version"
    
    # GUI nástroje (alespoň jeden musí být)
    local gui_tools=("whiptail" "dialog" "fzf")
    local has_gui_tool=false
    
    for tool in "${gui_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            has_gui_tool=true
            log "INFO" "GUI nástroj nalezen: $tool"
            break
        fi
    done
    
    if [[ "$has_gui_tool" == false ]]; then
        log "WARNING" "Nenalezen žádný GUI nástroj, použit textový režim"
    fi
    
    # Volitelné nástroje
    check_optional_dependency "git" "Git" "true"
    check_optional_dependency "jq" "JSON processor" "false"
    check_optional_dependency "curl" "CURL" "false"
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Chybějící závislosti:${NC}"
        printf '  • %s\n' "${missing_deps[@]}"
        
        if [[ "$has_gui_tool" == true ]]; then
            if confirm "Chcete nainstalovat chybějící závislosti?"; then
                install_missing_dependencies "${missing_deps[@]}"
            fi
        fi
    else
        echo -e "${GREEN}✅ Všechny závislosti jsou nainstalovány${NC}"
    fi
}

check_dependency() {
    local cmd="$1"
    local name="$2"
    local required_version="$3"
    local version_arg="${4:---version}"
    
    if ! command -v "$cmd" &>/dev/null; then
        log "ERROR" "Chybějící závislost: $name ($cmd)"
        return 1
    fi
    
    log "DEBUG" "Závislost OK: $name"
    return 0
}

check_optional_dependency() {
    local cmd="$1"
    local name="$2"
    local warn_if_missing="$3"
    
    if ! command -v "$cmd" &>/dev/null; then
        if [[ "$warn_if_missing" == "true" ]]; then
            log "WARNING" "Volitelná závislost chybí: $name"
            echo -e "${YELLOW}  ⚠️  $name není nainstalován (některé funkce nebudou dostupné)${NC}"
        fi
        return 1
    fi
    
    log "DEBUG" "Volitelná závislost OK: $name"
    return 0
}

install_missing_dependencies() {
    local deps=("$@")
    local platform=$(detect_platform)
    
    echo -e "${CYAN}📦 Instalace chybějících závislostí...${NC}"
    
    case "$platform" in
        "ubuntu"|"debian")
            sudo apt-get update
            for dep in "${deps[@]}"; do
                case "$dep" in
                    *"jq"*) sudo apt-get install -y jq ;;
                    *"curl"*) sudo apt-get install -y curl ;;
                    *"whiptail"*) sudo apt-get install -y whiptail ;;
                    *"dialog"*) sudo apt-get install -y dialog ;;
                    *"fzf"*) sudo apt-get install -y fzf ;;
                esac
            done
            ;;
        "fedora"|"rhel")
            sudo dnf check-update
            for dep in "${deps[@]}"; do
                case "$dep" in
                    *"jq"*) sudo dnf install -y jq ;;
                    *"curl"*) sudo dnf install -y curl ;;
                    *"whiptail"*) sudo dnf install -y newt ;;
                    *"dialog"*) sudo dnf install -y dialog ;;
                    *"fzf"*) sudo dnf install -y fzf ;;
                esac
            done
            ;;
        "termux")
            pkg update
            for dep in "${deps[@]}"; do
                case "$dep" in
                    *"jq"*) pkg install -y jq ;;
                    *"curl"*) pkg install -y curl ;;
                    *"dialog"*) pkg install -y dialog ;;
                esac
            done
            ;;
        *)
            echo -e "${RED}❌ Nelze automaticky nainstalovat závislosti na této platformě${NC}"
            echo "Manuálně nainstalujte: ${deps[*]}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Závislosti nainstalovány${NC}"
}

detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                case "$ID" in
                    ubuntu|debian) echo "ubuntu" ;;
                    fedora|rhel) echo "fedora" ;;
                    arch) echo "arch" ;;
                    *) echo "linux" ;;
                esac
            elif [[ -d /data/data/com.termux ]]; then
                echo "termux"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "macos" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

init_logging() {
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
    
    # Rotace logů (max 10 souborů po 1MB)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE") -gt 1048576 ]]; then
        for i in {9..1}; do
            if [[ -f "${LOG_FILE}.${i}" ]]; then
                mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
            fi
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Získat log level z konfigurace
    local config_level=$(get_config_value ".system.log_level" "INFO")
    local level_num=0
    
    case "$config_level" in
        "DEBUG") level_num=0 ;;
        "INFO") level_num=1 ;;
        "WARNING") level_num=2 ;;
        "ERROR") level_num=3 ;;
        *) level_num=1 ;;
    esac
    
    local current_level_num=0
    case "$level" in
        "DEBUG") current_level_num=0 ;;
        "INFO") current_level_num=1 ;;
        "WARNING") current_level_num=2 ;;
        "ERROR") current_level_num=3 ;;
        *) current_level_num=1 ;;
    esac
    
    # Logovat pouze pokud je úroveň dostatečně vysoká
    if [[ $current_level_num -ge $level_num ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        
        # Také vypnout na stdout pro vyšší úrovně
        if [[ $current_level_num -ge 2 ]]; then
            case "$level" in
                "WARNING") echo -e "${YELLOW}[$level]${NC} $message" >&2 ;;
                "ERROR") echo -e "${RED}[$level]${NC} $message" >&2 ;;
                *) echo "[$level] $message" ;;
            esac
        fi
    fi
}

# ==============================================================================
# KONFIGURAČNÍ FUNKCE
# ==============================================================================

get_config_value() {
    local path="$1"
    local default="$2"
    
    if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        jq -r "$path // \"$default\"" "$CONFIG_FILE" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

set_config_value() {
    local path="$1"
    local value="$2"
    
    if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        local temp_file="${CONFIG_FILE}.tmp"
        jq "$path = \"$value\"" "$CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$CONFIG_FILE"
        log "DEBUG" "Konfigurace aktualizována: $path = $value"
    else
        log "WARNING" "Nelze aktualizovat konfiguraci (jq není nainstalován)"
    fi
}

# ==============================================================================
# POMOCNÉ FUNKCE
# ==============================================================================

confirm() {
    local message="${1:-Pokračovat?}"
    
    if [[ "$GUI_TOOL" == "whiptail" ]] || [[ "$GUI_TOOL" == "dialog" ]]; then
        $GUI_TOOL --title "Potvrzení" --yesno "$message" 10 60
        return $?
    else
        echo -en "${YELLOW}$message [y/N]: ${NC}"
        read -r response
        [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
    fi
}

show_header() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║          ███╗   ███╗██████╗                          ║"
    echo "║          ████╗ ████║██╔══██╗                         ║"
    echo "║          ██╔████╔██║██║  ██║                         ║"
    echo "║          ██║╚██╔╝██║██║  ██║                         ║"
    echo "║          ██║ ╚═╝ ██║██████╔╝                         ║"
    echo "║          ╚═╝     ╚═╝╚═════╝                          ║"
    echo "║                                                      ║"
    echo "║        ████████╗ ██████╗ ██╗   ██╗███████╗           ║"
    echo "║        ╚══██╔══╝██╔═══██╗██║   ██║██╔════╝           ║"
    echo "║           ██║   ██║   ██║██║   ██║███████╗           ║"
    echo "║           ██║   ██║   ██║██║   ██║╚════██║           ║"
    echo "║           ██║   ╚██████╔╝╚██████╔╝███████║           ║"
    echo "║           ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝           ║"
    echo "║                                                      ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║                Version Manager v$VERSION                ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ==============================================================================
# DETEKCE A VÝBĚR GUI NÁSTROJE
# ==============================================================================

detect_gui_tool() {
    echo -e "${CYAN}🎨 Detekce GUI nástroje...${NC}"
    
    # Priorita: fzf > whiptail > dialog > text
    if command -v fzf &>/dev/null; then
        GUI_TOOL="fzf"
        echo -e "${GREEN}✅ Používám moderní FZF rozhraní${NC}"
    elif command -v whiptail &>/dev/null; then
        GUI_TOOL="whiptail"
        echo -e "${GREEN}✅ Používám Whiptail rozhraní${NC}"
    elif command -v dialog &>/dev/null; then
        GUI_TOOL="dialog"
        echo -e "${GREEN}✅ Používám Dialog rozhraní${NC}"
    else
        GUI_TOOL="text"
        echo -e "${YELLOW}⚠️  GUI nástroj nenalezen, používám textový režim${NC}"
    fi
    
    export GUI_TOOL
    log "INFO" "GUI nástroj detekován: $GUI_TOOL"
}

# ==============================================================================
# HLAVNÍ MENU
# ==============================================================================

show_main_menu() {
    case "$GUI_TOOL" in
        "fzf")
            show_fzf_menu
            ;;
        "whiptail"|"dialog")
            show_classic_menu
            ;;
        "text")
            show_text_menu
            ;;
        *)
            show_text_menu
            ;;
    esac
}

show_fzf_menu() {
    local selection
    selection=$(printf '%s\n' \
        "🚀  Zálohovat aktuální verzi" \
        "📋  Seznam verzí" \
        "🔄  Přepnout verzi" \
        "🌐  Synchronizace s Git" \
        "📝  Generovat Changelog" \
        "📊  Zobrazit aktuální stav" \
        "⚙️   Nastavení" \
        "🖥️   Webové rozhraní" \
        "🔌  Správa pluginů" \
        "📈  Systémové informace" \
        "❓  Nápověda" \
        "🚪  Konec" | \
        fzf --height=40% --reverse --prompt="🔧 MD Installer > " \
            --header="Verze $VERSION | $(date '+%H:%M:%S')" \
            --preview="echo 'Vyberte akci pro náhled'" \
            --preview-window=right:40%:wrap)
    
    handle_menu_selection "$selection"
}

show_classic_menu() {
    local selection
    selection=$($GUI_TOOL --title "MD Installer v$VERSION" \
        --menu "Vyberte akci:" 20 60 12 \
        "1" "🚀  Zálohovat aktuální verzi" \
        "2" "📋  Seznam verzí" \
        "3" "🔄  Přepnout verzi" \
        "4" "🌐  Synchronizace s Git" \
        "5" "📝  Generovat Changelog" \
        "6" "📊  Zobrazit aktuální stav" \
        "7" "⚙️   Nastavení" \
        "8" "🖥️   Webové rozhraní" \
        "9" "🔌  Správa pluginů" \
        "10" "📈  Systémové informace" \
        "11" "❓  Nápověda" \
        "12" "🚪  Konec" \
        3>&1 1>&2 2>&3)
    
    case "$selection" in
        "1") handle_menu_selection "🚀  Zálohovat aktuální verzi" ;;
        "2") handle_menu_selection "📋  Seznam verzí" ;;
        "3") handle_menu_selection "🔄  Přepnout verzi" ;;
        "4") handle_menu_selection "🌐  Synchronizace s Git" ;;
        "5") handle_menu_selection "📝  Generovat Changelog" ;;
        "6") handle_menu_selection "📊  Zobrazit aktuální stav" ;;
        "7") handle_menu_selection "⚙️   Nastavení" ;;
        "8") handle_menu_selection "🖥️   Webové rozhraní" ;;
        "9") handle_menu_selection "🔌  Správa pluginů" ;;
        "10") handle_menu_selection "📈  Systémové informace" ;;
        "11") handle_menu_selection "❓  Nápověda" ;;
        "12") handle_menu_selection "🚪  Konec" ;;
    esac
}

show_text_menu() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║               MD INSTALLER - MAIN MENU              ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  1) 🚀  Zálohovat aktuální verzi                   ║"
    echo "║  2) 📋  Seznam verzí                              ║"
    echo "║  3) 🔄  Přepnout verzi                             ║"
    echo "║  4) 🌐  Synchronizace s Git                        ║"
    echo "║  5) 📝  Generovat Changelog                        ║"
    echo "║  6) 📊  Zobrazit aktuální stav                    ║"
    echo "║  7) ⚙️   Nastavení                                 ║"
    echo "║  8) 🖥️   Webové rozhraní                           ║"
    echo "║  9) 🔌  Správa pluginů                            ║"
    echo "║  10) 📈  Systémové informace                       ║"
    echo "║  11) ❓  Nápověda                                  ║"
    echo "║  12) 🚪  Konec                                     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "Vyberte možnost [1-12]: " choice
    
    case "$choice" in
        1) handle_menu_selection "🚀  Zálohovat aktuální verzi" ;;
        2) handle_menu_selection "📋  Seznam verzí" ;;
        3) handle_menu_selection "🔄  Přepnout verzi" ;;
        4) handle_menu_selection "🌐  Synchronizace s Git" ;;
        5) handle_menu_selection "📝  Generovat Changelog" ;;
        6) handle_menu_selection "📊  Zobrazit aktuální stav" ;;
        7) handle_menu_selection "⚙️   Nastavení" ;;
        8) handle_menu_selection "🖥️   Webové rozhraní" ;;
        9) handle_menu_selection "🔌  Správa pluginů" ;;
        10) handle_menu_selection "📈  Systémové informace" ;;
        11) handle_menu_selection "❓  Nápověda" ;;
        12) handle_menu_selection "🚪  Konec" ;;
        *) 
            echo -e "${RED}❌ Neplatná volba${NC}"
            sleep 1
            show_text_menu
            ;;
    esac
}

handle_menu_selection() {
    local selection="$1"
    
    case "$selection" in
        *"Zálohovat"*)
            run_backup
            ;;
        *"Seznam verzí"*)
            list_versions
            ;;
        *"Přepnout verzi"*)
            switch_version
            ;;
        *"Synchronizace s Git"*)
            git_sync
            ;;
        *"Generovat Changelog"*)
            generate_changelog
            ;;
        *"Zobrazit aktuální stav"*)
            show_status
            ;;
        *"Nastavení"*)
            show_settings
            ;;
        *"Webové rozhraní"*)
            run_web_gui
            ;;
        *"Správa pluginů"*)
            manage_plugins
            ;;
        *"Systémové informace"*)
            show_system_info
            ;;
        *"Nápověda"*)
            show_help
            ;;
        *"Konec"*)
            echo -e "${GREEN}👋 Ukončuji MD Installer...${NC}"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}⚠️  Neznámý výběr, vracím se do menu${NC}"
            sleep 1
            show_main_menu
            ;;
    esac
}

# ==============================================================================
# HLAVNÍ FUNKCE
# ==============================================================================

run_backup() {
    echo -e "${CYAN}🔄 Spouštím proces zálohování...${NC}"
    
    if [[ -f "$VM_DIR/backup.sh" ]]; then
        log "INFO" "Spouštím backup skript"
        bash "$VM_DIR/backup.sh"
    else
        echo -e "${RED}❌ Soubor backup.sh nebyl nalezen${NC}"
        log "ERROR" "Soubor backup.sh neexistuje: $VM_DIR/backup.sh"
    fi
    
    pause_and_return
}

list_versions() {
    echo -e "${CYAN}📋 Načítám seznam verzí...${NC}"
    
    if [[ -d "$VM_DIR/backups" ]]; then
        local backups=("$VM_DIR/backups"/*)
        
        if [[ ${#backups[@]} -eq 0 ]] || [[ ! -f "${backups[0]}" ]]; then
            echo -e "${YELLOW}⚠️  Žádné zálohy nenalezeny${NC}"
        else
            echo -e "${GREEN}✅ Dostupné zálohy:${NC}"
            for backup in "${backups[@]}"; do
                if [[ -f "$backup" ]]; then
                    local filename=$(basename "$backup")
                    local size=$(du -h "$backup" | cut -f1)
                    local date=$(stat -c %y "$backup" 2>/dev/null || stat -f %Sm "$backup")
                    echo "  • $filename ($size) - $date"
                fi
            done
        fi
    else
        echo -e "${RED}❌ Adresář backups neexistuje${NC}"
    fi
    
    pause_and_return
}

switch_version() {
    echo -e "${CYAN}🔄 Příprava přepnutí verze...${NC}"
    
    if [[ -f "$VM_DIR/switch.sh" ]]; then
        # Nejdřív ukázat seznam verzí
        list_versions
        
        echo -e "${YELLOW}📝 Zadejte název verze k přepnutí: ${NC}"
        read -r version_name
        
        if [[ -n "$version_name" ]]; then
            log "INFO" "Přepínám na verzi: $version_name"
            bash "$VM_DIR/switch.sh" use "$version_name"
        else
            echo -e "${RED}❌ Není zadán název verze${NC}"
        fi
    else
        echo -e "${RED}❌ Soubor switch.sh nebyl nalezen${NC}"
    fi
    
    pause_and_return
}

git_sync() {
    echo -e "${CYAN}🌐 Spouštím Git synchronizaci...${NC}"
    
    if [[ -f "$VM_DIR/git_sync.sh" ]]; then
        bash "$VM_DIR/git_sync.sh"
    else
        echo -e "${YELLOW}⚠️  Git synchronizace není dostupná${NC}"
        echo "Instalace: sudo apt install git"
    fi
    
    pause_and_return
}

generate_changelog() {
    echo -e "${CYAN}📝 Generuji changelog...${NC}"
    
    if [[ -f "$VM_DIR/changelog.sh" ]]; then
        bash "$VM_DIR/changelog.sh"
    else
        echo -e "${RED}❌ Soubor changelog.sh nebyl nalezen${NC}"
    fi
    
    pause_and_return
}

show_status() {
    echo -e "${CYAN}📊 Aktuální stav systému:${NC}"
    
    # Získat informace z state.json
    local state_file="$VM_DIR/state.json"
    if [[ -f "$state_file" ]]; then
        if command -v jq &>/dev/null; then
            local current_version=$(jq -r '.current_version // "N/A"' "$state_file")
            local last_backup=$(jq -r '.last_backup // "N/A"' "$state_file")
            
            echo -e "  ${GREEN}✓${NC} Aktuální verze: $current_version"
            echo -e "  ${GREEN}✓${NC} Poslední záloha: $last_backup"
        else
            echo "  Stav: state.json existuje (jq není nainstalován pro čtení)"
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC} Stav: state.json neexistuje"
    fi
    
    # Počet záloh
    if [[ -d "$VM_DIR/backups" ]]; then
        local backup_count=$(find "$VM_DIR/backups" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓${NC} Počet záloh: $backup_count"
    fi
    
    # Velikost logů
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(du -h "$LOG_FILE" | cut -f1)
        echo -e "  ${GREEN}✓${NC} Velikost logů: $log_size"
    fi
    
    pause_and_return
}

show_settings() {
    echo -e "${CYAN}⚙️  Nastavení aplikace:${NC}"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Konfigurační soubor: $CONFIG_FILE"
        
        if command -v jq &>/dev/null; then
            jq . "$CONFIG_FILE" 2>/dev/null || echo "  (Nelze načíst, možná neplatný JSON)"
        else
            echo "  Obsah:"
            cat "$CONFIG_FILE"
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC} Konfigurační soubor neexistuje"
    fi
    
    echo ""
    echo -e "${YELLOW}Možnosti:${NC}"
    echo "  1) Upravit konfiguraci"
    echo "  2) Obnovit výchozí nastavení"
    echo "  3) Smazat všechny zálohy"
    echo "  4) Zpět do hlavního menu"
    
    read -p "Vyberte možnost [1-4]: " choice
    
    case "$choice" in
        1)
            if [[ -f "$CONFIG_FILE" ]]; then
                ${EDITOR:-nano} "$CONFIG_FILE"
            fi
            ;;
        2)
            if confirm "Opravdu obnovit výchozí nastavení?"; then
                create_default_config
                echo -e "${GREEN}✅ Výchozí nastavení obnoveno${NC}"
            fi
            ;;
        3)
            if confirm "Opravdu smazat VŠECHNY zálohy? Tato akce je nevratná!"; then
                rm -rf "$VM_DIR/backups"/*
                echo -e "${GREEN}✅ Všechny zálohy smazány${NC}"
            fi
            ;;
    esac
    
    pause_and_return
}

run_web_gui() {
    echo -e "${CYAN}🖥️  Spouštím webové rozhraní...${NC}"
    
    local web_gui_dir="$PROJECT_ROOT/web_gui"
    
    if [[ -d "$web_gui_dir" ]]; then
        if command -v node &>/dev/null && command -v npm &>/dev/null; then
            if [[ -f "$web_gui_dir/package.json" ]]; then
                echo -e "${BLUE}Instaluji závislosti...${NC}"
                cd "$web_gui_dir" && npm install
                
                echo -e "${BLUE}Spouštím server...${NC}"
                echo -e "${GREEN}✅ Web GUI bude dostupné na: http://localhost:3000${NC}"
                echo -e "${YELLOW}Pro zastavení stiskněte Ctrl+C${NC}"
                
                cd "$web_gui_dir" && npm start
            else
                echo -e "${RED}❌ package.json nebyl nalezen${NC}"
            fi
        else
            echo -e "${RED}❌ Node.js a npm nejsou nainstalovány${NC}"
            echo "Instalace:"
            echo "  Ubuntu: sudo apt install nodejs npm"
            echo "  Mac: brew install node"
            echo "  Windows: stáhněte z nodejs.org"
        fi
    else
        echo -e "${RED}❌ Adresář web_gui nebyl nalezen${NC}"
    fi
    
    pause_and_return
}

manage_plugins() {
    echo -e "${CYAN}🔌 Správa pluginů...${NC}"
    
    local plugins_dir="$VM_DIR/plugins"
    
    if [[ -d "$plugins_dir" ]]; then
        local plugins=("$plugins_dir"/*.sh)
        
        if [[ ${#plugins[@]} -eq 0 ]] || [[ ! -f "${plugins[0]}" ]]; then
            echo -e "${YELLOW}⚠️  Žádné pluginy nenalezeny${NC}"
            echo "Pluginy ukládejte jako: $plugins_dir/nazev_plugin.sh"
        else
            echo -e "${GREEN}✅ Dostupné pluginy:${NC}"
            for plugin in "${plugins[@]}"; do
                if [[ -f "$plugin" ]]; then
                    local plugin_name=$(basename "$plugin" .sh)
                    echo "  • $plugin_name"
                fi
            done
        fi
    else
        echo -e "${RED}❌ Adresář plugins neexistuje${NC}"
        mkdir -p "$plugins_dir"
        echo -e "${GREEN}✅ Adresář plugins vytvořen${NC}"
    fi
    
    pause_and_return
}

show_system_info() {
    echo -e "${CYAN}📈 Systémové informace:${NC}"
    
    # Platforma
    local platform=$(detect_platform)
    echo -e "  ${GREEN}✓${NC} Platforma: $platform"
    
    # Shell
    echo -e "  ${GREEN}✓${NC} Shell: $SHELL"
    
    # Uptime
    if command -v uptime &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Uptime: $(uptime -p 2>/dev/null || uptime)"
    fi
    
    # Paměť
    if [[ "$platform" != "windows" ]]; then
        if command -v free &>/dev/null; then
            local mem=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
            echo -e "  ${GREEN}✓${NC} Paměť: $mem"
        fi
    fi
    
    # Disk
    if command -v df &>/dev/null; then
        local disk=$(df -h . | awk 'NR==2 {print $4 " volné z " $2}')
        echo -e "  ${GREEN}✓${NC} Disk: $disk"
    fi
    
    # MD Installer info
    echo -e "\n${BLUE}MD Installer Informace:${NC}"
    echo -e "  ${GREEN}✓${NC} Verze: $VERSION"
    echo -e "  ${GREEN}✓${NC} Kořenový adresář: $PROJECT_ROOT"
    echo -e "  ${GREEN}✓${NC} GUI nástroj: $GUI_TOOL"
    
    if [[ -f "$LOG_FILE" ]]; then
        local log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓${NC} Log souborů: $log_lines řádků"
    fi
    
    pause_and_return
}

show_help() {
    echo -e "${CYAN}❓ Nápověda - MD Installer v$VERSION${NC}"
    
    cat << 'EOF'

ZÁKLADNÍ POUŽITÍ:
  ./md_installer.sh          Spustí interaktivní menu
  ./md_installer.sh --help   Zobrazí tuto nápovědu
  ./md_installer.sh --backup Rychlá záloha bez menu

FUNKCE:
  • Zálohování - Vytváří komprimované archivy vašich instalačních souborů
  • Správa verzí - Přepínání mezi různými verzemi instalátoru
  • Git synchronizace - Propojení s GitHub repozitářem
  • Webové rozhraní - Moderní GUI dostupné v prohlížeči
  • Pluginy - Rozšiřitelnost pomocí vlastních skriptů

ADRESÁŘOVÁ STRUKTURA:
  version_manager/          Hlavní adresář s logikou
    ├── backups/           Uložené zálohy
    ├── config/            Konfigurační soubory
    ├── logs/              Log soubory
    ├── plugins/           Uživatelské pluginy
    └── state/             Stavové informace

KONFIGURACE:
  Upravte: version_manager/config/config.json
  nebo použijte "Nastavení" v hlavním menu

PROBLÉMY:
  • Kontrola logů: cat version_manager/logs/md_installer.log
  • Kontrola závislostí: ./md_installer.sh --check-deps
  • Report chyb: https://github.com/Fatalerorr69/MD_installer/issues

EOF
    
    pause_and_return
}

pause_and_return() {
    echo ""
    echo -e "${YELLOW}Stiskněte Enter pro návrat do menu...${NC}"
    read -r
    show_main_menu
}

# ==============================================================================
# HLAVNÍ SMYČKA
# ==============================================================================

main() {
    # Zpracování argumentů příkazové řádky
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--version"|"-v")
            echo "MD Installer Version Manager v$VERSION"
            exit 0
            ;;
        "--backup"|"-b")
            run_backup
            exit 0
            ;;
        "--check-deps"|"-c")
            check_dependencies
            exit 0
            ;;
    esac
    
    # Inicializace
    init_project
    detect_gui_tool
    
    # Zobrazení hlavičky
    show_header
    
    # Hlavní smyčka
    while true; do
        show_main_menu
    done
}

# ==============================================================================
# SPUŠTĚNÍ
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
