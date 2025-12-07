#!/usr/bin/env bash
# ============================================================================
# MD INSTALLER - Hlavní integrovaný skript
# Verze: 2.0.0
# Autor: Fatalerorr69
# ============================================================================

set -euo pipefail

# ============================================================================
# KONFIGURACE A GLOBÁLNÍ PROMĚNNÉ
# ============================================================================

readonly VERSION="2.0.0"
readonly APP_NAME="MD Installer"
readonly APP_AUTHOR="Fatalerorr69"

# Cesty
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$SCRIPT_DIR"
readonly VERSION_MANAGER_DIR="$ROOT_DIR/version_manager"
readonly WEB_GUI_DIR="$ROOT_DIR/web_gui"
readonly CONFIG_DIR="$VERSION_MANAGER_DIR/config"
readonly LOGS_DIR="$VERSION_MANAGER_DIR/logs"
readonly BACKUPS_DIR="$VERSION_MANAGER_DIR/backups"
readonly PLUGINS_DIR="$VERSION_MANAGER_DIR/plugins"
readonly STATE_FILE="$VERSION_MANAGER_DIR/state.json"

# Konfigurační soubory
readonly MAIN_CONFIG="$CONFIG_DIR/main.json"
readonly DEPENDENCIES_CONFIG="$CONFIG_DIR/dependencies.json"
readonly PLATFORM_CONFIG="$CONFIG_DIR/platforms.json"

# Logování
readonly LOG_FILE="$LOGS_DIR/md_installer.log"

# Barvy pro výstup
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'

# ============================================================================
# INICIALIZAČNÍ FUNKCE
# ============================================================================

initialize() {
    clear
    show_banner
    create_directory_structure
    load_configuration
    detect_platform
    detect_gui_tool
    check_dependencies
    setup_logging
}

show_banner() {
    cat << "EOF"
${COLOR_MAGENTA}
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║    ███╗   ███╗██████╗      ██╗███╗   ██╗███████╗        ║
║    ████╗ ████║██╔══██╗     ██║████╗  ██║██╔════╝        ║
║    ██╔████╔██║██║  ██║     ██║██╔██╗ ██║███████╗        ║
║    ██║╚██╔╝██║██║  ██║██   ██║██║╚██╗██║╚════██║        ║
║    ██║ ╚═╝ ██║██████╔╝╚█████╔╝██║ ╚████║███████║        ║
║    ╚═╝     ╚═╝╚═════╝  ╚════╝ ╚═╝  ╚═══╝╚══════╝        ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║                Version Manager v2.0.0                    ║
║                Integrated Main GUI                       ║
╚══════════════════════════════════════════════════════════╝
${COLOR_RESET}
EOF
    
    echo -e "${COLOR_CYAN}📂 Kořenový adresář: ${COLOR_WHITE}$ROOT_DIR${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📦 Verze: ${COLOR_WHITE}$VERSION${COLOR_RESET}"
    echo -e "${COLOR_CYAN}👤 Autor: ${COLOR_WHITE}$APP_AUTHOR${COLOR_RESET}"
    echo ""
}

create_directory_structure() {
    echo -e "${COLOR_BLUE}📁 Vytvářím adresářovou strukturu...${COLOR_RESET}"
    
    local directories=(
        "$CONFIG_DIR"
        "$LOGS_DIR"
        "$BACKUPS_DIR"
        "$PLUGINS_DIR"
        "$WEB_GUI_DIR/public"
        "$WEB_GUI_DIR/api"
        "$WEB_GUI_DIR/assets"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_message "INFO" "Vytvořen adresář: $dir"
        fi
    done
    
    echo -e "${COLOR_GREEN}✅ Adresářová struktura vytvořena${COLOR_RESET}"
}

load_configuration() {
    echo -e "${COLOR_BLUE}⚙️  Načítám konfiguraci...${COLOR_RESET}"
    
    # Hlavní konfigurace
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        create_main_config
    fi
    
    # Konfigurace závislostí
    if [[ ! -f "$DEPENDENCIES_CONFIG" ]]; then
        create_dependencies_config
    fi
    
    # Platform konfigurace
    if [[ ! -f "$PLATFORM_CONFIG" ]]; then
        create_platform_config
    fi
    
    echo -e "${COLOR_GREEN}✅ Konfigurace načtena${COLOR_RESET}"
}

detect_platform() {
    echo -e "${COLOR_BLUE}🔍 Detekuji platformu...${COLOR_RESET}"
    
    local os_name
    case "$(uname -s)" in
        Linux*)
            if [[ -f /etc/os-release ]]; then
                os_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
            elif [[ -d /data/data/com.termux ]]; then
                os_name="Android (Termux)"
            else
                os_name="Linux"
            fi
            PLATFORM="linux"
            ;;
        Darwin*)
            os_name="macOS"
            PLATFORM="macos"
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            os_name="Windows"
            PLATFORM="windows"
            ;;
        *)
            os_name="Neznámý OS"
            PLATFORM="unknown"
            ;;
    esac
    
    export PLATFORM
    echo -e "${COLOR_GREEN}✅ Platforma: ${COLOR_WHITE}$os_name${COLOR_RESET}"
    log_message "INFO" "Detekovaná platforma: $PLATFORM ($os_name)"
}

detect_gui_tool() {
    echo -e "${COLOR_BLUE}🎨 Detekuji GUI nástroje...${COLOR_RESET}"
    
    GUI_TOOL=""
    
    # Priorita: fzf > whiptail > dialog
    if command -v fzf &>/dev/null; then
        GUI_TOOL="fzf"
        echo -e "${COLOR_GREEN}✅ Moderní FZF rozhraní${COLOR_RESET}"
    elif command -v whiptail &>/dev/null; then
        GUI_TOOL="whiptail"
        echo -e "${COLOR_GREEN}✅ Whiptail rozhraní${COLOR_RESET}"
    elif command -v dialog &>/dev/null; then
        GUI_TOOL="dialog"
        echo -e "${COLOR_GREEN}✅ Dialog rozhraní${COLOR_RESET}"
    else
        GUI_TOOL="text"
        echo -e "${COLOR_YELLOW}⚠️  Textový režim (GUI nástroje nenalezeny)${COLOR_RESET}"
    fi
    
    export GUI_TOOL
    log_message "INFO" "GUI nástroj: $GUI_TOOL"
}

check_dependencies() {
    echo -e "${COLOR_BLUE}🔍 Kontroluji závislosti...${COLOR_RESET}"
    
    local missing_deps=()
    
    # Načíst požadované závislosti z konfigurace
    if [[ -f "$DEPENDENCIES_CONFIG" ]] && command -v jq &>/dev/null; then
        local required_tools
        required_tools=$(jq -r ".$PLATFORM.required[]" "$DEPENDENCIES_CONFIG" 2>/dev/null)
        
        for tool in $required_tools; do
            if ! command -v "$tool" &>/dev/null; then
                missing_deps+=("$tool")
            fi
        done
    else
        # Základní kontrola
        local basic_tools=("bash" "tar" "gzip")
        for tool in "${basic_tools[@]}"; do
            if ! command -v "$tool" &>/dev/null; then
                missing_deps+=("$tool")
            fi
        done
    fi
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        echo -e "${COLOR_GREEN}✅ Všechny závislosti jsou nainstalovány${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}⚠️  Chybějící závislosti: ${missing_deps[*]}${COLOR_RESET}"
        log_message "WARNING" "Chybějící závislosti: ${missing_deps[*]}"
        
        if [[ "$GUI_TOOL" != "text" ]]; then
            if confirm "Chcete nainstalovat chybějící závislosti?"; then
                install_dependencies "${missing_deps[@]}"
            fi
        fi
    fi
}

setup_logging() {
    if [[ ! -d "$LOGS_DIR" ]]; then
        mkdir -p "$LOGS_DIR"
    fi
    
    # Rotace logů
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]]; then
        for i in {9..1}; do
            if [[ -f "${LOG_FILE}.$i" ]]; then
                mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
            fi
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# ============================================================================
# KONFIGURAČNÍ FUNKCE
# ============================================================================

create_main_config() {
    cat > "$MAIN_CONFIG" << 'EOF'
{
  "application": {
    "name": "MD Installer",
    "version": "2.0.0",
    "author": "Fatalerorr69"
  },
  "backup": {
    "compression": "tar.gz",
    "encryption": false,
    "retention_days": 30,
    "max_backups": 50,
    "exclude_patterns": [
      "*.log",
      "*.tmp",
      ".git/*",
      "node_modules/*"
    ]
  },
  "gui": {
    "default_tool": "auto",
    "theme": "dark",
    "language": "cs_CZ",
    "enable_animations": true
  },
  "web": {
    "port": 3000,
    "host": "localhost",
    "enable_ssl": false,
    "auto_start": false
  },
  "git": {
    "auto_sync": false,
    "push_on_backup": false,
    "remote": "origin"
  },
  "notifications": {
    "enabled": true,
    "on_backup_complete": true,
    "on_error": true
  }
}
EOF
    log_message "INFO" "Hlavní konfigurace vytvořena"
}

create_dependencies_config() {
    cat > "$DEPENDENCIES_CONFIG" << 'EOF'
{
  "linux": {
    "required": ["bash", "tar", "gzip", "git"],
    "optional": ["whiptail", "dialog", "fzf", "jq", "curl", "node", "npm"]
  },
  "macos": {
    "required": ["bash", "tar", "gzip"],
    "optional": ["whiptail", "dialog", "fzf", "jq", "curl", "node", "npm"]
  },
  "windows": {
    "required": ["bash", "tar", "gzip"],
    "optional": ["whiptail", "dialog", "fzf", "jq", "curl", "node", "npm"]
  },
  "termux": {
    "required": ["bash", "tar", "gzip"],
    "optional": ["dialog", "git", "nodejs"]
  }
}
EOF
    log_message "INFO" "Konfigurace závislostí vytvořena"
}

create_platform_config() {
    cat > "$PLATFORM_CONFIG" << 'EOF'
{
  "platforms": {
    "linux": {
      "package_manager": "apt-get",
      "install_command": "sudo apt-get install -y",
      "backup_path": "/var/backups"
    },
    "macos": {
      "package_manager": "brew",
      "install_command": "brew install",
      "backup_path": "~/Library/Backups"
    },
    "windows": {
      "package_manager": "choco",
      "install_command": "choco install -y",
      "backup_path": "C:/Backups"
    },
    "termux": {
      "package_manager": "pkg",
      "install_command": "pkg install -y",
      "backup_path": "/data/data/com.termux/files/backups"
    }
  }
}
EOF
    log_message "INFO" "Konfigurace platforem vytvořena"
}

# ============================================================================
# INSTALAČNÍ FUNKCE
# ============================================================================

install_dependencies() {
    local deps=("$@")
    
    echo -e "${COLOR_CYAN}📦 Instalace závislostí...${COLOR_RESET}"
    
    case "$PLATFORM" in
        "linux")
            if command -v apt-get &>/dev/null; then
                sudo apt-get update
                for dep in "${deps[@]}"; do
                    echo "Instaluji $dep..."
                    sudo apt-get install -y "$dep" 2>/dev/null || true
                done
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y "${deps[@]}"
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm "${deps[@]}"
            fi
            ;;
        "macos")
            if command -v brew &>/dev/null; then
                brew install "${deps[@]}"
            else
                echo -e "${COLOR_RED}❌ Homebrew není nainstalován${COLOR_RESET}"
                return 1
            fi
            ;;
        "termux")
            pkg update
            pkg install -y "${deps[@]}"
            ;;
        *)
            echo -e "${COLOR_RED}❌ Nelze automaticky instalovat na této platformě${COLOR_RESET}"
            return 1
            ;;
    esac
    
    echo -e "${COLOR_GREEN}✅ Závislosti nainstalovány${COLOR_RESET}"
    log_message "INFO" "Závislosti nainstalovány: ${deps[*]}"
}

# ============================================================================
# HLAVNÍ MENU FUNKCE
# ============================================================================

show_main_menu() {
    case "$GUI_TOOL" in
        "fzf")
            show_fzf_menu
            ;;
        "whiptail"|"dialog")
            show_whiptail_menu
            ;;
        *)
            show_text_menu
            ;;
    esac
}

show_fzf_menu() {
    while true; do
        local selection
        selection=$(printf '%s\n' \
            "🚀  ZÁLOHOVAT - Vytvořit novou zálohu" \
            "📋  VERZE - Seznam a správa verzí" \
            "🔄  PŘEPNOUT - Změnit aktivní verzi" \
            "🌐  GIT - Synchronizace s GitHub" \
            "📝  CHANGELOG - Generovat změny" \
            "🖥️   WEB GUI - Spustit webové rozhraní" \
            "⚙️   NASTAVENÍ - Konfigurace aplikace" \
            "🔧  NÁSTROJE - Rozšířené nástroje" \
            "📊  STAV - Systémové informace" \
            "❓  NÁPOVĚDA - Dokumentace a pomoc" \
            "🚪  KONEC - Ukončit aplikaci" | \
            fzf --height=50% --reverse --prompt="🔧 MD Installer > " \
                --header="Verze $VERSION | Platforma: $PLATFORM | GUI: $GUI_TOOL" \
                --preview="echo 'Vyberte akci pro zobrazení detailů'" \
                --preview-window=right:40%:wrap)
        
        if [[ -z "$selection" ]]; then
            exit 0
        fi
        
        handle_menu_selection "$selection"
    done
}

show_whiptail_menu() {
    while true; do
        local selection
        selection=$($GUI_TOOL --title "MD Installer v$VERSION" \
            --menu "Vyberte akci:" 25 60 15 \
            "1" "🚀  Zálohovat - Vytvořit novou zálohu" \
            "2" "📋  Verze - Seznam a správa verzí" \
            "3" "🔄  Přepnout - Změnit aktivní verzi" \
            "4" "🌐  Git - Synchronizace s GitHub" \
            "5" "📝  Changelog - Generovat změny" \
            "6" "🖥️   Web GUI - Spustit webové rozhraní" \
            "7" "⚙️   Nastavení - Konfigurace aplikace" \
            "8" "🔧  Nástroje - Rozšířené nástroje" \
            "9" "📊  Stav - Systémové informace" \
            "10" "❓  Nápověda - Dokumentace a pomoc" \
            "11" "🚪  Konec - Ukončit aplikaci" \
            3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]]; then
            exit 0
        fi
        
        case "$selection" in
            "1") handle_menu_selection "🚀  ZÁLOHOVAT - Vytvořit novou zálohu" ;;
            "2") handle_menu_selection "📋  VERZE - Seznam a správa verzí" ;;
            "3") handle_menu_selection "🔄  PŘEPNOUT - Změnit aktivní verzi" ;;
            "4") handle_menu_selection "🌐  GIT - Synchronizace s GitHub" ;;
            "5") handle_menu_selection "📝  CHANGELOG - Generovat změny" ;;
            "6") handle_menu_selection "🖥️   WEB GUI - Spustit webové rozhraní" ;;
            "7") handle_menu_selection "⚙️   NASTAVENÍ - Konfigurace aplikace" ;;
            "8") handle_menu_selection "🔧  NÁSTROJE - Rozšířené nástroje" ;;
            "9") handle_menu_selection "📊  STAV - Systémové informace" ;;
            "10") handle_menu_selection "❓  NÁPOVĚDA - Dokumentace a pomoc" ;;
            "11") exit 0 ;;
        esac
    done
}

show_text_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}"
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║               MD INSTALLER - HLAVNÍ MENU                ║"
        echo "╠══════════════════════════════════════════════════════════╣"
        echo "║  1) 🚀  Zálohovat - Vytvořit novou zálohu              ║"
        echo "║  2) 📋  Verze - Seznam a správa verzí                 ║"
        echo "║  3) 🔄  Přepnout - Změnit aktivní verzi               ║"
        echo "║  4) 🌐  Git - Synchronizace s GitHub                  ║"
        echo "║  5) 📝  Changelog - Generovat změny                   ║"
        echo "║  6) 🖥️   Web GUI - Spustit webové rozhraní            ║"
        echo "║  7) ⚙️   Nastavení - Konfigurace aplikace             ║"
        echo "║  8) 🔧  Nástroje - Rozšířené nástroje                 ║"
        echo "║  9) 📊  Stav - Systémové informace                    ║"
        echo "║  10) ❓  Nápověda - Dokumentace a pomoc                ║"
        echo "║  11) 🚪  Konec - Ukončit aplikaci                     ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo -e "${COLOR_RESET}"
        
        read -p "Vyberte možnost [1-11]: " choice
        
        case "$choice" in
            1) handle_menu_selection "🚀  ZÁLOHOVAT - Vytvořit novou zálohu" ;;
            2) handle_menu_selection "📋  VERZE - Seznam a správa verzí" ;;
            3) handle_menu_selection "🔄  PŘEPNOUT - Změnit aktivní verzi" ;;
            4) handle_menu_selection "🌐  GIT - Synchronizace s GitHub" ;;
            5) handle_menu_selection "📝  CHANGELOG - Generovat změny" ;;
            6) handle_menu_selection "🖥️   WEB GUI - Spustit webové rozhraní" ;;
            7) handle_menu_selection "⚙️   NASTAVENÍ - Konfigurace aplikace" ;;
            8) handle_menu_selection "🔧  NÁSTROJE - Rozšířené nástroje" ;;
            9) handle_menu_selection "📊  STAV - Systémové informace" ;;
            10) handle_menu_selection "❓  NÁPOVĚDA - Dokumentace a pomoc" ;;
            11) exit 0 ;;
            *) 
                echo -e "${COLOR_RED}❌ Neplatná volba${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

handle_menu_selection() {
    local selection="$1"
    
    case "$selection" in
        *"ZÁLOHOVAT"*)
            run_backup_function
            ;;
        *"VERZE"*)
            list_versions_function
            ;;
        *"PŘEPNOUT"*)
            switch_version_function
            ;;
        *"GIT"*)
            git_sync_function
            ;;
        *"CHANGELOG"*)
            changelog_function
            ;;
        *"WEB GUI"*)
            web_gui_function
            ;;
        *"NASTAVENÍ"*)
            settings_function
            ;;
        *"NÁSTROJE"*)
            tools_function
            ;;
        *"STAV"*)
            status_function
            ;;
        *"NÁPOVĚDA"*)
            help_function
            ;;
        *)
            echo -e "${COLOR_YELLOW}⚠️  Neznámá volba${COLOR_RESET}"
            ;;
    esac
    
    pause_for_return
}

# ============================================================================
# FUNKCE PRO HLAVNÍ OPERACE
# ============================================================================

run_backup_function() {
    clear
    echo -e "${COLOR_CYAN}🔄 Spouštím proces zálohování...${COLOR_RESET}"
    
    if [[ -f "$VERSION_MANAGER_DIR/backup.sh" ]]; then
        log_message "INFO" "Spouštím backup skript"
        bash "$VERSION_MANAGER_DIR/backup.sh"
    else
        echo -e "${COLOR_RED}❌ Soubor backup.sh nebyl nalezen${COLOR_RESET}"
        log_message "ERROR" "Soubor backup.sh neexistuje"
        
        # Nabídnout vytvoření základního backup skriptu
        if confirm "Chcete vytvořit základní backup skript?"; then
            create_basic_backup_script
        fi
    fi
}

list_versions_function() {
    clear
    echo -e "${COLOR_CYAN}📋 Seznam dostupných verzí...${COLOR_RESET}"
    
    if [[ -d "$BACKUPS_DIR" ]]; then
        local backups=("$BACKUPS_DIR"/*)
        
        if [[ ${#backups[@]} -eq 0 ]] || [[ ! -f "${backups[0]}" ]]; then
            echo -e "${COLOR_YELLOW}⚠️  Žádné zálohy nenalezeny${COLOR_RESET}"
        else
            echo -e "${COLOR_GREEN}✅ Dostupné zálohy:${COLOR_RESET}"
            echo ""
            
            local counter=1
            for backup in "${backups[@]}"; do
                if [[ -f "$backup" ]]; then
                    local filename=$(basename "$backup")
                    local size=$(du -h "$backup" 2>/dev/null | cut -f1 || echo "N/A")
                    local date=$(stat -c "%y" "$backup" 2>/dev/null || echo "N/A")
                    
                    printf "${COLOR_WHITE}%3d) ${COLOR_CYAN}%-40s ${COLOR_YELLOW}%8s ${COLOR_MAGENTA}%s${COLOR_RESET}\n" \
                        "$counter" "$filename" "$size" "$date"
                    ((counter++))
                fi
            done
        fi
    else
        echo -e "${COLOR_RED}❌ Adresář backups neexistuje${COLOR_RESET}"
    fi
}

switch_version_function() {
    clear
    echo -e "${COLOR_CYAN}🔄 Příprava přepnutí verze...${COLOR_RESET}"
    
    if [[ -f "$VERSION_MANAGER_DIR/switch.sh" ]]; then
        # Nejprve zobrazit seznam
        list_versions_function
        
        echo ""
        echo -e "${COLOR_YELLOW}📝 Zadejte název verze k přepnutí: ${COLOR_RESET}"
        read -r version_name
        
        if [[ -n "$version_name" ]]; then
            log_message "INFO" "Přepínám na verzi: $version_name"
            bash "$VERSION_MANAGER_DIR/switch.sh" use "$version_name"
        else
            echo -e "${COLOR_RED}❌ Není zadán název verze${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_RED}❌ Soubor switch.sh nebyl nalezen${COLOR_RESET}"
    fi
}

git_sync_function() {
    clear
    echo -e "${COLOR_CYAN}🌐 Spouštím Git synchronizaci...${COLOR_RESET}"
    
    if [[ -f "$VERSION_MANAGER_DIR/git_sync.sh" ]]; then
        bash "$VERSION_MANAGER_DIR/git_sync.sh"
    else
        echo -e "${COLOR_YELLOW}⚠️  Git synchronizace není dostupná${COLOR_RESET}"
        log_message "WARNING" "Git sync skript neexistuje"
        
        if confirm "Chcete vytvořit základní Git sync skript?"; then
            create_basic_git_sync_script
        fi
    fi
}

changelog_function() {
    clear
    echo -e "${COLOR_CYAN}📝 Generuji changelog...${COLOR_RESET}"
    
    if [[ -f "$VERSION_MANAGER_DIR/changelog.sh" ]]; then
        bash "$VERSION_MANAGER_DIR/changelog.sh"
    else
        echo -e "${COLOR_RED}❌ Soubor changelog.sh nebyl nalezen${COLOR_RESET}"
    fi
}

web_gui_function() {
    clear
    echo -e "${COLOR_CYAN}🖥️  Spouštím webové rozhraní...${COLOR_RESET}"
    
    if [[ -d "$WEB_GUI_DIR" ]]; then
        if command -v node &>/dev/null && command -v npm &>/dev/null; then
            if [[ -f "$WEB_GUI_DIR/package.json" ]]; then
                echo -e "${COLOR_BLUE}📦 Kontroluji závislosti...${COLOR_RESET}"
                
                # Instalace závislostí pokud neexistují
                if [[ ! -d "$WEB_GUI_DIR/node_modules" ]]; then
                    cd "$WEB_GUI_DIR" && npm install --quiet
                fi
                
                echo -e "${COLOR_BLUE}🚀 Spouštím server...${COLOR_RESET}"
                echo -e "${COLOR_GREEN}✅ Web GUI bude dostupné na: http://localhost:3000${COLOR_RESET}"
                echo -e "${COLOR_YELLOW}📌 Pro zastavení stiskněte Ctrl+C${COLOR_RESET}"
                echo ""
                
                cd "$WEB_GUI_DIR" && npm start
            else
                echo -e "${COLOR_RED}❌ package.json nebyl nalezen${COLOR_RESET}"
                
                if confirm "Chcete vytvořit základní webové rozhraní?"; then
                    create_basic_web_gui
                fi
            fi
        else
            echo -e "${COLOR_RED}❌ Node.js a npm nejsou nainstalovány${COLOR_RESET}"
            echo ""
            echo -e "${COLOR_YELLOW}Instalace Node.js:${COLOR_RESET}"
            echo "  Ubuntu/Debian: sudo apt install nodejs npm"
            echo "  Fedora: sudo dnf install nodejs npm"
            echo "  Mac: brew install node"
            echo "  Windows: stáhněte z nodejs.org"
        fi
    else
        echo -e "${COLOR_RED}❌ Adresář web_gui nebyl nalezen${COLOR_RESET}"
        mkdir -p "$WEB_GUI_DIR"
        echo -e "${COLOR_GREEN}✅ Adresář web_gui vytvořen${COLOR_RESET}"
        
        if confirm "Chcete vytvořit základní webové rozhraní?"; then
            create_basic_web_gui
        fi
    fi
}

settings_function() {
    clear
    echo -e "${COLOR_CYAN}⚙️  Nastavení aplikace...${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_YELLOW}Konfigurační soubory:${COLOR_RESET}"
    echo "  1) Hlavní konfigurace: $MAIN_CONFIG"
    echo "  2) Závislosti: $DEPENDENCIES_CONFIG"
    echo "  3) Platformy: $PLATFORM_CONFIG"
    echo ""
    echo -e "${COLOR_YELLOW}Možnosti:${COLOR_RESET}"
    echo "  1) Upravit hlavní konfiguraci"
    echo "  2) Zobrazit systémové informace"
    echo "  3) Smazat všechny zálohy"
    echo "  4) Vyčistit logy"
    echo "  5) Obnovit výchozí nastavení"
    echo "  6) Zpět do hlavního menu"
    
    read -p "Vyberte možnost [1-6]: " choice
    
    case "$choice" in
        1)
            if [[ -f "$MAIN_CONFIG" ]]; then
                ${EDITOR:-nano} "$MAIN_CONFIG"
                echo -e "${COLOR_GREEN}✅ Konfigurace uložena${COLOR_RESET}"
            fi
            ;;
        2)
            show_system_info
            ;;
        3)
            if confirm "Opravdu chcete smazat VŠECHNY zálohy? Tato akce je nevratná!"; then
                rm -rf "$BACKUPS_DIR"/*
                echo -e "${COLOR_GREEN}✅ Všechny zálohy smazány${COLOR_RESET}"
            fi
            ;;
        4)
            if confirm "Vyčistit všechny logy?"; then
                rm -f "$LOGS_DIR"/*
                echo -e "${COLOR_GREEN}✅ Logy vyčištěny${COLOR_RESET}"
            fi
            ;;
        5)
            if confirm "Obnovit výchozí nastavení?"; then
                rm -f "$MAIN_CONFIG" "$DEPENDENCIES_CONFIG" "$PLATFORM_CONFIG"
                create_main_config
                create_dependencies_config
                create_platform_config
                echo -e "${COLOR_GREEN}✅ Výchozí nastavení obnoveno${COLOR_RESET}"
            fi
            ;;
    esac
}

tools_function() {
    clear
    echo -e "${COLOR_CYAN}🔧 Rozšířené nástroje...${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_YELLOW}Dostupné nástroje:${COLOR_RESET}"
    echo "  1) Kontrola integrity záloh"
    echo "  2) Export konfigurace"
    echo "  3) Import konfigurace"
    echo "  4) Zálohovat konfiguraci"
    echo "  5) Monitorování zdrojů"
    echo "  6) Zpět do hlavního menu"
    
    read -p "Vyberte možnost [1-6]: " choice
    
    case "$choice" in
        1)
            check_backup_integrity
            ;;
        2)
            export_configuration
            ;;
        3)
            import_configuration
            ;;
        4)
            backup_configuration
            ;;
        5)
            monitor_resources
            ;;
    esac
}

status_function() {
    clear
    echo -e "${COLOR_CYAN}📊 Stav systému a aplikace...${COLOR_RESET}"
    echo ""
    
    # Systémové informace
    echo -e "${COLOR_YELLOW}💻 Systémové informace:${COLOR_RESET}"
    echo -e "  OS: $(uname -s) $(uname -r)"
    echo -e "  Architektura: $(uname -m)"
    echo -e "  Hostname: $(hostname)"
    
    # Uptime
    if command -v uptime &>/dev/null; then
        echo -e "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    fi
    
    # Paměť
    if [[ "$PLATFORM" != "windows" ]] && command -v free &>/dev/null; then
        local mem_info
        mem_info=$(free -h | awk '/^Mem:/ {print "RAM: " $3 "/" $2 " (" $4 " volné)"}')
        echo -e "  $mem_info"
    fi
    
    # Disk
    if command -v df &>/dev/null; then
        local disk_info
        disk_info=$(df -h . | awk 'NR==2 {print "Disk: " $4 " volné z " $2 " (" $5 " použito)"}')
        echo -e "  $disk_info"
    fi
    
    echo ""
    
    # Aplikační informace
    echo -e "${COLOR_YELLOW}📦 Aplikační informace:${COLOR_RESET}"
    echo -e "  Verze: $VERSION"
    echo -e "  Platforma: $PLATFORM"
    echo -e "  GUI nástroj: $GUI_TOOL"
    echo -e "  Kořenový adresář: $ROOT_DIR"
    
    # Stav záloh
    if [[ -d "$BACKUPS_DIR" ]]; then
        local backup_count
        backup_count=$(find "$BACKUPS_DIR" -type f 2>/dev/null | wc -l)
        local backup_size
        backup_size=$(du -sh "$BACKUPS_DIR" 2>/dev/null | cut -f1)
        echo -e "  Počet záloh: $backup_count"
        echo -e "  Velikost záloh: $backup_size"
    fi
    
    # Stav logů
    if [[ -f "$LOG_FILE" ]]; then
        local log_size
        log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1)
        local log_lines
        log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        echo -e "  Logy: $log_lines řádků ($log_size)"
    fi
    
    echo ""
    
    # Stav skriptů
    echo -e "${COLOR_YELLOW}📝 Stav skriptů:${COLOR_RESET}"
    
    local scripts=(
        "$VERSION_MANAGER_DIR/backup.sh"
        "$VERSION_MANAGER_DIR/switch.sh"
        "$VERSION_MANAGER_DIR/git_sync.sh"
        "$VERSION_MANAGER_DIR/changelog.sh"
        "$WEB_GUI_DIR/server.js"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo -e "  ✅ $(basename "$script")"
        else
            echo -e "  ❌ $(basename "$script") (chybí)"
        fi
    done
}

help_function() {
    clear
    echo -e "${COLOR_CYAN}❓ Nápověda a dokumentace...${COLOR_RESET}"
    echo ""
    
    cat << EOF
${COLOR_YELLOW}ZÁKLADNÍ POUŽITÍ:${COLOR_RESET}
  ./md_installer.sh           Spustí interaktivní menu
  ./md_installer.sh --help    Zobrazí tuto nápovědu
  ./md_installer.sh --backup  Rychlá záloha bez menu
  ./md_installer.sh --web     Spustí pouze webové rozhraní

${COLOR_YELLOW}HLAVNÍ FUNKCE:${COLOR_RESET}
  1) Zálohování - Vytváří komprimované archivy
  2) Správa verzí - Přepínání mezi verzemi
  3) Git synchronizace - Propojení s GitHub
  4) Webové rozhraní - Moderní GUI v prohlížeči
  5) Changelog - Generování přehledu změn

${COLOR_YELLOW}ADRESÁŘOVÁ STRUKTURA:${COLOR_RESET}
  ${ROOT_DIR}/
  ├── md_installer.sh          # Hlavní spouštěcí skript
  ├── version_manager/         # Jádro aplikace
  │   ├── backups/            # Uložené zálohy
  │   ├── config/             # Konfigurační soubory
  │   ├── logs/               # Logy aplikace
  │   └── *.sh                # Funkční skripty
  ├── web_gui/                # Webové rozhraní
  └── README.md               # Dokumentace

${COLOR_YELLOW}KONFIGURACE:${COLOR_RESET}
  Hlavní konfigurace: ${MAIN_CONFIG}
  Závislosti: ${DEPENDENCIES_CONFIG}
  Platformy: ${PLATFORM_CONFIG}

${COLOR_YELLOW}LOGOVÁNÍ A DEBUG:${COLOR_RESET}
  Hlavní log: ${LOG_FILE}
  Kontrola stavu: ./md_installer.sh --status

${COLOR_YELLOW}PROBLÉMY A PODPORA:${COLOR_RESET}
  1. Chybějící závislosti: ./md_installer.sh --check-deps
  2. Web GUI neběží: zkontrolujte Node.js a npm
  3. Git sync nefunguje: zkontrolujte git konfiguraci
  4. Report chyb: https://github.com/Fatalerorr69/MD_installer/issues

${COLOR_YELLOW}KLÁVESOVÉ ZKRATKY:${COLOR_RESET}
  Ctrl+C    - Ukončení aktuální operace
  Ctrl+Z    - Pozastavení procesu
  Ctrl+D    - Ukončení terminálu (exit)
EOF
}

# ============================================================================
# POMOCNÉ FUNKCE
# ============================================================================

confirm() {
    local message="${1:-Pokračovat?}"
    
    case "$GUI_TOOL" in
        "whiptail"|"dialog")
            $GUI_TOOL --title "Potvrzení" --yesno "$message" 10 60
            return $?
            ;;
        *)
            echo -en "${COLOR_YELLOW}$message [y/N]: ${COLOR_RESET}"
            read -r response
            [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
            ;;
    esac
}

pause_for_return() {
    echo ""
    echo -en "${COLOR_YELLOW}Stiskněte Enter pro návrat do menu...${COLOR_RESET}"
    read -r
}

create_basic_backup_script() {
    cat > "$VERSION_MANAGER_DIR/backup.sh" << 'EOF'
#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$BACKUP_DIR"

echo "🔄 Vytvářím zálohu..."
echo "Čas: $(date)"

# Vytvořit zálohu
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
tar -czf "$BACKUP_FILE" -C "$SCRIPT_DIR/.." .

echo "✅ Záloha vytvořena: $BACKUP_FILE"
echo "Velikost: $(du -h "$BACKUP_FILE" | cut -f1)"
EOF
    
    chmod +x "$VERSION_MANAGER_DIR/backup.sh"
    echo -e "${COLOR_GREEN}✅ Základní backup skript vytvořen${COLOR_RESET}"
}

create_basic_git_sync_script() {
    cat > "$VERSION_MANAGER_DIR/git_sync.sh" << 'EOF'
#!/usr/bin/env bash

set -e

echo "🌐 Git Synchronizace"
echo "==================="

if ! command -v git &>/dev/null; then
    echo "❌ Git není nainstalován"
    exit 1
fi

echo "1) Push změn na GitHub"
echo "2) Pull změn z GitHub"
echo "3) Zobrazit stav"
echo "4) Vytvořit tag"

read -p "Vyberte akci [1-4]: " choice

case $choice in
    1)
        git add .
        read -p "Commit message: " message
        git commit -m "${message:-Auto commit}"
        git push origin main
        echo "✅ Změny odeslány"
        ;;
    2)
        git pull origin main
        echo "✅ Změny staženy"
        ;;
    3)
        git status
        ;;
    4)
        read -p "Tag name (v1.0.0): " tag
        git tag "${tag:-v1.0.0}"
        git push --tags
        echo "✅ Tag vytvořen"
        ;;
    *)
        echo "❌ Neplatná volba"
        ;;
esac
EOF
    
    chmod +x "$VERSION_MANAGER_DIR/git_sync.sh"
    echo -e "${COLOR_GREEN}✅ Základní Git sync skript vytvořen${COLOR_RESET}"
}

create_basic_web_gui() {
    # Vytvořit základní package.json
    cat > "$WEB_GUI_DIR/package.json" << 'EOF'
{
  "name": "md-installer-web-gui",
  "version": "1.0.0",
  "description": "Webové rozhraní pro MD Installer",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    # Vytvořit základní server.js
    cat > "$WEB_GUI_DIR/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// API endpointy
app.get('/api/status', async (req, res) => {
    try {
        res.json({
            status: 'running',
            version: '1.0.0',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/backups', async (req, res) => {
    try {
        const backupsDir = path.join(__dirname, '..', 'version_manager', 'backups');
        const files = await fs.readdir(backupsDir).catch(() => []);
        
        const backups = await Promise.all(
            files.map(async file => {
                const filePath = path.join(backupsDir, file);
                const stats = await fs.stat(filePath);
                return {
                    name: file,
                    size: stats.size,
                    created: stats.birthtime
                };
            })
        );
        
        res.json(backups);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Statická stránka
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html lang="cs">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>MD Installer - Web GUI</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                h1 { color: #333; }
                .status { background: #e8f5e9; padding: 10px; border-radius: 5px; margin: 20px 0; }
                .backup-list { margin-top: 20px; }
                .backup-item { padding: 10px; border-bottom: 1px solid #eee; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>MD Installer - Web GUI</h1>
                <div class="status">
                    <h3>Stav systému</h3>
                    <p id="status">Načítání...</p>
                </div>
                <div class="backup-list">
                    <h3>Dostupné zálohy</h3>
                    <div id="backups">Načítání...</div>
                </div>
            </div>
            
            <script>
                async function loadStatus() {
                    try {
                        const response = await fetch('/api/status');
                        const data = await response.json();
                        document.getElementById('status').innerHTML = 
                            \`Verze: \${data.version}<br>
                             Čas: \${new Date(data.timestamp).toLocaleString()}\`;
                    } catch (error) {
                        document.getElementById('status').innerHTML = 'Chyba: ' + error.message;
                    }
                }
                
                async function loadBackups() {
                    try {
                        const response = await fetch('/api/backups');
                        const backups = await response.json();
                        
                        if (backups.length === 0) {
                            document.getElementById('backups').innerHTML = 'Žádné zálohy';
                            return;
                        }
                        
                        const html = backups.map(backup => \`
                            <div class="backup-item">
                                <strong>\${backup.name}</strong><br>
                                <small>Velikost: \${Math.round(backup.size / 1024)} KB |
                                 Vytvořeno: \${new Date(backup.created).toLocaleString()}</small>
                            </div>
                        \`).join('');
                        
                        document.getElementById('backups').innerHTML = html;
                    } catch (error) {
                        document.getElementById('backups').innerHTML = 'Chyba: ' + error.message;
                    }
                }
                
                // Načíst data při startu
                loadStatus();
                loadBackups();
                
                // Automatická aktualizace každých 30 vteřin
                setInterval(() => {
                    loadStatus();
                    loadBackups();
                }, 30000);
            </script>
        </body>
        </html>
    `);
});

app.listen(PORT, () => {
    console.log(\`🌐 Web GUI běží na http://localhost:\${PORT}\`);
});
EOF

    # Vytvořit public adresář s CSS
    mkdir -p "$WEB_GUI_DIR/public/css"
    cat > "$WEB_GUI_DIR/public/css/style.css" << 'EOF'
/* Základní styly pro MD Installer Web GUI */
:root {
    --primary-color: #4361ee;
    --secondary-color: #3a0ca3;
    --success-color: #4cc9f0;
    --danger-color: #f72585;
    --dark-color: #1a1b26;
    --light-color: #f8f9fa;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    margin: 0;
    padding: 20px;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    border-radius: 15px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    overflow: hidden;
}

.header {
    background: var(--primary-color);
    color: white;
    padding: 20px;
    text-align: center;
}

.header h1 {
    margin: 0;
    font-size: 2.5rem;
}

.header p {
    margin: 5px 0 0 0;
    opacity: 0.9;
}

.content {
    padding: 30px;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 30px;
}

@media (max-width: 768px) {
    .content {
        grid-template-columns: 1fr;
    }
}

.card {
    background: var(--light-color);
    border-radius: 10px;
    padding: 20px;
    box-shadow: 0 3px 10px rgba(0,0,0,0.1);
}

.card h3 {
    color: var(--primary-color);
    margin-top: 0;
    border-bottom: 2px solid var(--primary-color);
    padding-bottom: 10px;
}

.status-item {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid #eee;
}

.status-item:last-child {
    border-bottom: none;
}

.backup-item {
    background: white;
    border-left: 4px solid var(--primary-color);
    margin-bottom: 10px;
    padding: 15px;
    border-radius: 5px;
}

.backup-name {
    font-weight: bold;
    color: var(--dark-color);
}

.backup-info {
    font-size: 0.9em;
    color: #666;
    margin-top: 5px;
}

.actions {
    display: flex;
    gap: 10px;
    margin-top: 20px;
}

.btn {
    padding: 10px 20px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-weight: bold;
    transition: all 0.3s;
}

.btn-primary {
    background: var(--primary-color);
    color: white;
}

.btn-primary:hover {
    background: var(--secondary-color);
}

.btn-secondary {
    background: #6c757d;
    color: white;
}

.btn-secondary:hover {
    background: #5a6268;
}
EOF

    # Vytvořit základní HTML
    mkdir -p "$WEB_GUI_DIR/public"
    cat > "$WEB_GUI_DIR/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MD Installer - Web GUI</title>
    <link rel="stylesheet" href="/css/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-cube"></i> MD Installer</h1>
            <p>Webové rozhraní pro správu verzí</p>
        </div>
        
        <div class="content">
            <div class="card">
                <h3><i class="fas fa-tachometer-alt"></i> Stav systému</h3>
                <div id="system-status">
                    <div class="status-item">
                        <span>Verze aplikace:</span>
                        <span id="app-version">Načítání...</span>
                    </div>
                    <div class="status-item">
                        <span>Čas serveru:</span>
                        <span id="server-time">Načítání...</span>
                    </div>
                    <div class="status-item">
                        <span>Stav připojení:</span>
                        <span id="connection-status" class="status-offline">Offline</span>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <h3><i class="fas fa-database"></i> Zálohy</h3>
                <div class="actions">
                    <button class="btn btn-primary" onclick="createBackup()">
                        <i class="fas fa-plus"></i> Nová záloha
                    </button>
                    <button class="btn btn-secondary" onclick="refreshBackups()">
                        <i class="fas fa-sync"></i> Obnovit
                    </button>
                </div>
                <div id="backup-list">
                    <p>Načítání záloh...</p>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Globální proměnné
        let backups = [];
        
        // Načíst stav systému
        async function loadSystemStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                document.getElementById('app-version').textContent = data.version;
                document.getElementById('server-time').textContent = 
                    new Date(data.timestamp).toLocaleString();
                document.getElementById('connection-status').textContent = 'Online';
                document.getElementById('connection-status').className = 'status-online';
                
            } catch (error) {
                console.error('Chyba při načítání stavu:', error);
                document.getElementById('connection-status').textContent = 'Offline';
                document.getElementById('connection-status').className = 'status-offline';
            }
        }
        
        // Načíst seznam záloh
        async function loadBackups() {
            try {
                const response = await fetch('/api/backups');
                backups = await response.json();
                
                const backupList = document.getElementById('backup-list');
                
                if (backups.length === 0) {
                    backupList.innerHTML = '<p>Žádné zálohy</p>';
                    return;
                }
                
                let html = '';
                backups.forEach((backup, index) => {
                    const sizeMB = (backup.size / (1024 * 1024)).toFixed(2);
                    const date = new Date(backup.created).toLocaleString();
                    
                    html += `
                        <div class="backup-item">
                            <div class="backup-name">${backup.name}</div>
                            <div class="backup-info">
                                <i class="fas fa-hdd"></i> ${sizeMB} MB |
                                <i class="fas fa-calendar"></i> ${date}
                            </div>
                        </div>
                    `;
                });
                
                backupList.innerHTML = html;
                
            } catch (error) {
                console.error('Chyba při načítání záloh:', error);
                document.getElementById('backup-list').innerHTML = 
                    '<p>Chyba při načítání záloh</p>';
            }
        }
        
        // Vytvořit novou zálohu
        async function createBackup() {
            try {
                const response = await fetch('/api/backup', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        name: `backup_${new Date().toISOString().slice(0, 19)}`,
                        type: 'manual'
                    })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    alert('✅ Záloha vytvořena');
                    loadBackups();
                } else {
                    alert('❌ Chyba: ' + result.error);
                }
                
            } catch (error) {
                alert('❌ Chyba: ' + error.message);
            }
        }
        
        // Obnovit seznam záloh
        function refreshBackups() {
            loadBackups();
        }
        
        // Inicializace při načtení stránky
        document.addEventListener('DOMContentLoaded', () => {
            loadSystemStatus();
            loadBackups();
            
            // Automatická aktualizace každých 30 sekund
            setInterval(() => {
                loadSystemStatus();
                loadBackups();
            }, 30000);
        });
    </script>
    
    <style>
        .status-online {
            color: #28a745;
            font-weight: bold;
        }
        
        .status-offline {
            color: #dc3545;
            font-weight: bold;
        }
    </style>
</body>
</html>
EOF
    
    # Nainstalovat závislosti
    cd "$WEB_GUI_DIR" && npm install --quiet
    
    echo -e "${COLOR_GREEN}✅ Základní Web GUI vytvořeno${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}📌 Spusťte: cd web_gui && npm start${COLOR_RESET}"
}

check_backup_integrity() {
    echo -e "${COLOR_CYAN}🔍 Kontrola integrity záloh...${COLOR_RESET}"
    
    if [[ ! -d "$BACKUPS_DIR" ]]; then
        echo -e "${COLOR_RED}❌ Adresář záloh neexistuje${COLOR_RESET}"
        return 1
    fi
    
    local backup_files=("$BACKUPS_DIR"/*)
    local valid_count=0
    local total_count=0
    
    for backup in "${backup_files[@]}"; do
        if [[ -f "$backup" ]]; then
            ((total_count++))
            
            # Kontrola podle přípony
            if [[ "$backup" == *.tar.gz ]] && tar -tzf "$backup" &>/dev/null; then
                ((valid_count++))
                echo -e "  ✅ $(basename "$backup")"
            elif [[ "$backup" == *.zip ]] && unzip -t "$backup" &>/dev/null; then
                ((valid_count++))
                echo -e "  ✅ $(basename "$backup")"
            else
                echo -e "  ❌ $(basename "$backup") (poškozený)"
            fi
        fi
    done
    
    echo ""
    echo -e "${COLOR_YELLOW}Výsledky kontroly:${COLOR_RESET}"
    echo -e "  Celkem souborů: $total_count"
    echo -e "  Platné zálohy: $valid_count"
    echo -e "  Poškozené: $((total_count - valid_count))"
    
    if [[ $valid_count -eq 0 ]] && [[ $total_count -gt 0 ]]; then
        echo -e "${COLOR_RED}⚠️  Všechny zálohy jsou poškozené!${COLOR_RESET}"
    fi
}

export_configuration() {
    local export_file="$ROOT_DIR/md_installer_config_$(date +%Y%m%d_%H%M%S).json"
    
    echo -e "${COLOR_CYAN}📤 Exportuji konfiguraci...${COLOR_RESET}"
    
    cat > "$export_file" << EOF
{
  "export": {
    "timestamp": "$(date -Iseconds)",
    "version": "$VERSION",
    "platform": "$PLATFORM"
  },
  "main_config": $(cat "$MAIN_CONFIG" 2>/dev/null || echo "{}"),
  "dependencies_config": $(cat "$DEPENDENCIES_CONFIG" 2>/dev/null || echo "{}"),
  "platform_config": $(cat "$PLATFORM_CONFIG" 2>/dev/null || echo "{}")
}
EOF
    
    echo -e "${COLOR_GREEN}✅ Konfigurace exportována do: $export_file${COLOR_RESET}"
}

import_configuration() {
    echo -e "${COLOR_CYAN}📥 Import konfigurace...${COLOR_RESET}"
    
    read -p "Zadejte cestu k souboru konfigurace: " config_file
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${COLOR_RED}❌ Soubor neexistuje${COLOR_RESET}"
        return 1
    fi
    
    if confirm "Přepsat aktuální konfiguraci?"; then
        cp "$config_file" "$MAIN_CONFIG"
        echo -e "${COLOR_GREEN}✅ Konfigurace importována${COLOR_RESET}"
    fi
}

backup_configuration() {
    local backup_file="$BACKUPS_DIR/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    echo -e "${COLOR_CYAN}💾 Zálohuji konfiguraci...${COLOR_RESET}"
    
    tar -czf "$backup_file" -C "$CONFIG_DIR" .
    
    echo -e "${COLOR_GREEN}✅ Konfigurace zálohována: $backup_file${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Velikost: $(du -h "$backup_file" | cut -f1)${COLOR_RESET}"
}

monitor_resources() {
    echo -e "${COLOR_CYAN}📊 Monitorování zdrojů...${COLOR_RESET}"
    echo ""
    
    # CPU
    if command -v top &>/dev/null; then
        echo -e "${COLOR_YELLOW}CPU Využití:${COLOR_RESET}"
        top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print "  Využito: " 100 - $1 "%"}'
    fi
    
    # Paměť
    if command -v free &>/dev/null; then
        echo -e "${COLOR_YELLOW}Paměť:${COLOR_RESET}"
        free -h | awk '/^Mem:/ {print "  Celkem: " $2 " | Použito: " $3 " | Volné: " $4}'
    fi
    
    # Disk
    echo -e "${COLOR_YELLOW}Disk:${COLOR_RESET}"
    df -h . | awk 'NR==2 {print "  Použito: " $5 " | Volné: " $4 " z " $2}'
    
    # Zálohy
    echo -e "${COLOR_YELLOW}Zálohy:${COLOR_RESET}"
    if [[ -d "$BACKUPS_DIR" ]]; then
        local backup_count=$(find "$BACKUPS_DIR" -type f | wc -l)
        local backup_size=$(du -sh "$BACKUPS_DIR" 2>/dev/null | cut -f1)
        echo "  Počet: $backup_count | Velikost: $backup_size"
    else
        echo "  Žádné zálohy"
    fi
}

show_system_info() {
    echo -e "${COLOR_CYAN}🖥️  Detailní systémové informace...${COLOR_RESET}"
    echo ""
    
    # Získat více informací o systému
    echo -e "${COLOR_YELLOW}Základní informace:${COLOR_RESET}"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Architektura: $(uname -m)"
    echo "  Hostname: $(hostname)"
    echo "  Uživatel: $(whoami)"
    
    # Čas
    echo -e "${COLOR_YELLOW}Čas:${COLOR_RESET}"
    echo "  Systémový čas: $(date)"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    
    # Shell
    echo -e "${COLOR_YELLOW}Shell:${COLOR_RESET}"
    echo "  Aktuální: $SHELL"
    echo "  Verze: $BASH_VERSION"
    
    # MD Installer info
    echo -e "${COLOR_YELLOW}MD Installer:${COLOR_RESET}"
    echo "  Verze: $VERSION"
    echo "  Platforma: $PLATFORM"
    echo "  GUI nástroj: $GUI_TOOL"
    echo "  Kořenový adresář: $ROOT_DIR"
    
    # Kontrola skriptů
    echo -e "${COLOR_YELLOW}Skripty:${COLOR_RESET}"
    check_script_status "backup.sh" "$VERSION_MANAGER_DIR/backup.sh"
    check_script_status "switch.sh" "$VERSION_MANAGER_DIR/switch.sh"
    check_script_status "git_sync.sh" "$VERSION_MANAGER_DIR/git_sync.sh"
    check_script_status "changelog.sh" "$VERSION_MANAGER_DIR/changelog.sh"
    check_script_status "server.js" "$WEB_GUI_DIR/server.js"
}

check_script_status() {
    local name="$1"
    local path="$2"
    
    if [[ -f "$path" ]]; then
        if [[ -x "$path" ]] || [[ "$path" == *.js ]]; then
            echo -e "  ✅ $name (připraven)"
        else
            echo -e "  ⚠️  $name (není spustitelný)"
        fi
    else
        echo -e "  ❌ $name (chybí)"
    fi
}

# ============================================================================
# HLAVNÍ FUNKCE PRO ZPRACOVÁNÍ ARGUMENTŮ
# ============================================================================

process_arguments() {
    case "${1:-}" in
        "--help"|"-h")
            show_help_screen
            exit 0
            ;;
        "--version"|"-v")
            echo "MD Installer v$VERSION"
            exit 0
            ;;
        "--backup"|"-b")
            run_backup_function
            exit 0
            ;;
        "--web"|"-w")
            web_gui_function
            exit 0
            ;;
        "--status"|"-s")
            status_function
            exit 0
            ;;
        "--check-deps"|"-c")
            check_dependencies
            exit 0
            ;;
        "--setup"|"-i")
            echo -e "${COLOR_CYAN}🚀 Spouštím kompletní instalaci...${COLOR_RESET}"
            initialize
            echo -e "${COLOR_GREEN}✅ Instalace dokončena${COLOR_RESET}"
            exit 0
            ;;
        "--update"|"-u")
            echo -e "${COLOR_CYAN}🔄 Kontrola aktualizací...${COLOR_RESET}"
            check_for_updates
            exit 0
            ;;
        *)
            # Žádné argumenty = spustit interaktivní režim
            return
            ;;
    esac
}

show_help_screen() {
    cat << EOF
${COLOR_CYAN}MD Installer - Hlavní spouštěcí skript${COLOR_RESET}
Verze: $VERSION

${COLOR_YELLOW}Použití:${COLOR_RESET}
  ./md_installer.sh [PŘEPÍNAČ]

${COLOR_YELLOW}Přepínače:${COLOR_RESET}
  -h, --help          Zobrazí tuto nápovědu
  -v, --version       Zobrazí verzi aplikace
  -b, --backup        Rychlé vytvoření zálohy
  -w, --web           Spustit pouze webové rozhraní
  -s, --status        Zobrazit stav systému
  -c, --check-deps    Kontrola závislostí
  -i, --setup         Kompletní instalace
  -u, --update        Kontrola aktualizací

${COLOR_YELLOW}Příklady:${COLOR_RESET}
  ./md_installer.sh              # Interaktivní menu
  ./md_installer.sh --backup     # Rychlá záloha
  ./md_installer.sh --web        # Spustit web GUI
  ./md_installer.sh --status     # Systémový stav

${COLOR_YELLOW}Konfigurace:${COLOR_RESET}
  Hlavní konfigurace: $MAIN_CONFIG
  Závislosti: $DEPENDENCIES_CONFIG

${COLOR_YELLOW}Podpora:${COLOR_RESET}
  GitHub: https://github.com/Fatalerorr69/MD_installer
  Logy: $LOG_FILE
EOF
}

check_for_updates() {
    echo -e "${COLOR_CYAN}🔍 Kontrola aktualizací...${COLOR_RESET}"
    
    if ! command -v git &>/dev/null; then
        echo -e "${COLOR_RED}❌ Git není nainstalován${COLOR_RESET}"
        return 1
    fi
    
    cd "$ROOT_DIR"
    
    # Zkontrolovat vzdálené změny
    git fetch origin 2>/dev/null || {
        echo -e "${COLOR_RED}❌ Nelze kontaktovat GitHub${COLOR_RESET}"
        return 1
    }
    
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    local local_hash
    local_hash=$(git rev-parse HEAD)
    local remote_hash
    remote_hash=$(git rev-parse "origin/$current_branch")
    
    if [[ "$local_hash" == "$remote_hash" ]]; then
        echo -e "${COLOR_GREEN}✅ Máte nejnovější verzi${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}⚠️  Dostupné aktualizace${COLOR_RESET}"
        echo ""
        echo -e "  Aktuální: $local_hash"
        echo -e "  Vzdálená: $remote_hash"
        echo ""
        
        if confirm "Chcete aktualizovat na nejnovější verzi?"; then
            git pull origin "$current_branch"
            echo -e "${COLOR_GREEN}✅ Aktualizace dokončena${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}📌 Restartujte aplikaci${COLOR_RESET}"
        fi
    fi
}

# ============================================================================
# HLAVNÍ SMYČKA APLIKACE
# ============================================================================

main() {
    # Zpracovat argumenty příkazové řádky
    process_arguments "$@"
    
    # Inicializace aplikace
    initialize
    
    # Hlavní interaktivní smyčka
    show_main_menu
}

# ============================================================================
# SPUŠTĚNÍ APLIKACE
# ============================================================================

# Zajistit, že skript běží v Bash
if [ -z "$BASH_VERSION" ]; then
    echo -e "${COLOR_RED}❌ Tento skript vyžaduje Bash${COLOR_RESET}"
    exit 1
fi

# Spuštění hlavní funkce
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
