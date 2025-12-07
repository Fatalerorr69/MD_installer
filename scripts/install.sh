#!/usr/bin/env bash
# Kompletní instalační skript pro MD Installer

set -euo pipefail

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           MD INSTALLER - INSTALACE                   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                OS="$NAME"
                VER="$VERSION_ID"
            elif [[ -d /data/data/com.termux ]]; then
                OS="Termux"
                VER="Android"
            else
                OS="Linux"
                VER=""
            fi
            ;;
        Darwin*) OS="macOS" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) OS="Windows" ;;
        *) OS="Neznámý" ;;
    esac
    
    echo -e "${GREEN}✅ Platforma: $OS $VER${NC}"
}

install_dependencies() {
    echo -e "${YELLOW}📦 Instalace závislostí...${NC}"
    
    case "$OS" in
        "Ubuntu"|"Debian"*)
            sudo apt update
            sudo apt install -y bash tar gzip whiptail dialog git curl jq
            ;;
        "Fedora"|"CentOS"*|"RHEL"*)
            sudo dnf install -y bash tar gzip newt dialog git curl jq
            ;;
        "Termux")
            pkg update
            pkg install -y bash tar gzip dialog git curl jq
            ;;
        "macOS")
            if ! command -v brew &>/dev/null; then
                echo -e "${YELLOW}Instalace Homebrew...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install bash coreutils gnu-tar dialog git curl jq
            ;;
        "Windows")
            echo -e "${YELLOW}Pro Windows použijte Git Bash${NC}"
            ;;
        *)
            echo -e "${RED}❌ Nepodporovaná platforma${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Závislosti nainstalovány${NC}"
}

setup_application() {
    echo -e "${YELLOW}⚙️  Nastavení aplikace...${NC}"
    
    # Udělat skripty spustitelnými
    chmod +x md_installer.sh
    chmod +x version_manager/*.sh 2>/dev/null || true
    chmod +x scripts/*.sh 2>/dev/null || true
    
    # Vytvořit potřebné adresáře
    mkdir -p version_manager/{backups,logs,config,plugins}
    mkdir -p web_gui/public
    
    # Vytvořit základní konfiguraci pokud neexistuje
    if [[ ! -f "version_manager/config/main.json" ]]; then
        cp config_templates/main.json version_manager/config/main.json 2>/dev/null || \
        echo '{"application": {"name": "MD Installer"}}' > version_manager/config/main.json
    fi
    
    echo -e "${GREEN}✅ Aplikace nastavena${NC}"
}

setup_web_gui() {
    echo -e "${YELLOW}🖥️  Nastavení Web GUI...${NC}"
    
    if [[ -d "web_gui" ]]; then
        if command -v node &>/dev/null && command -v npm &>/dev/null; then
            cd web_gui
            npm install --quiet
            cd ..
            echo -e "${GREEN}✅ Web GUI nastaveno${NC}"
        else
            echo -e "${YELLOW}⚠️  Node.js nenalezen, Web GUI přeskočeno${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Adresář web_gui neexistuje${NC}"
    fi
}

create_aliases() {
    echo -e "${YELLOW}🔗 Vytvářím aliasy...${NC}"
    
    local alias_cmd="alias md-installer='$(pwd)/md_installer.sh'"
    
    # Přidat do .bashrc pokud ještě neexistuje
    if ! grep -q "alias md-installer" ~/.bashrc 2>/dev/null; then
        echo "$alias_cmd" >> ~/.bashrc
        echo -e "${GREEN}✅ Alias přidán do ~/.bashrc${NC}"
    fi
    
    # Přidat do .zshrc pokud existuje
    if [[ -f ~/.zshrc ]] && ! grep -q "alias md-installer" ~/.zshrc; then
        echo "$alias_cmd" >> ~/.zshrc
        echo -e "${GREEN}✅ Alias přidán do ~/.zshrc${NC}"
    fi
    
    echo -e "${YELLOW}📝 Použijte 'md-installer' pro spuštění${NC}"
}

test_installation() {
    echo -e "${YELLOW}🧪 Testuji instalaci...${NC}"
    
    # Test základních funkcí
    if ./md_installer.sh --version; then
        echo -e "${GREEN}✅ Hlavní skript funguje${NC}"
    else
        echo -e "${RED}❌ Hlavní skript selhal${NC}"
    fi
    
    # Test adresářů
    if [[ -d "version_manager/backups" ]]; then
        echo -e "${GREEN}✅ Adresářová struktura OK${NC}"
    fi
}

show_summary() {
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✅ INSTALACE ÚSPĚŠNĚ DOKONČENA!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${YELLOW}📋 Další kroky:${NC}"
    echo "  1. Spusťte aplikaci: ./md_installer.sh"
    echo "  2. Nebo použijte alias: md-installer"
    echo "  3. Pro Web GUI: cd web_gui && npm start"
    echo ""
    echo -e "${YELLOW}📁 Struktura:${NC}"
    echo "  📂 version_manager/ - Jádro aplikace"
    echo "  📂 web_gui/         - Webové rozhraní"
    echo "  📂 scripts/         - Pomocné skripty"
    echo ""
    echo -e "${YELLOW}🆘 Nápověda:${NC}"
    echo "  ./md_installer.sh --help"
    echo "  cat README.md"
}

main() {
    print_header
    detect_platform
    install_dependencies
    setup_application
    setup_web_gui
    create_aliases
    test_installation
    show_summary
}

main "$@"
