#!/usr/bin/env bash

set -euo pipefail

echo "🚀 MD Installer - Kompletní instalace"
echo "======================================"

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Funkce pro logování
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Kontrola, zda jsme v kořenovém adresáři projektu
if [[ ! -f "md_installer.sh" ]] && [[ ! -f "version_manager/manager.sh" ]]; then
    echo -e "${RED}❌ Nejste v kořenovém adresáři MD Installer projektu${NC}"
    echo "Přejděte do složky, kde je md_installer.sh nebo version_manager/"
    exit 1
fi

# 1. Udělat skripty spustitelnými
log "${YELLOW}1. Nastavuji oprávnění skriptů...${NC}"
chmod +x md_installer.sh 2>/dev/null || true
chmod +x version_manager/*.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

echo -e "${GREEN}✅ Oprávnění nastavena${NC}"

# 2. Vytvořit adresářovou strukturu
log "${YELLOW}2. Vytvářím adresářovou strukturu...${NC}"

mkdir -p version_manager/{backups,logs,config,state,plugins}
mkdir -p scripts
mkdir -p docs

echo -e "${GREEN}✅ Adresáře vytvořeny${NC}"

# 3. Kontrola závislostí
log "${YELLOW}3. Kontrola závislostí...${NC}"

missing_deps=()

check_dep() {
    if ! command -v "$1" &>/dev/null; then
        missing_deps+=("$1")
        echo -e "  ${RED}❌ Chybí: $1${NC}"
    else
        echo -e "  ${GREEN}✅ OK: $1${NC}"
    fi
}

echo "Základní závislosti:"
check_dep "bash"
check_dep "tar"
check_dep "gzip"

echo -e "\nGUI závislosti:"
gui_found=false
check_dep "whiptail" && gui_found=true
check_dep "dialog" && gui_found=true
check_dep "fzf" && gui_found=true

if [[ "$gui_found" == false ]]; then
    echo -e "  ${YELLOW}⚠️  Žádný GUI nástroj nenalezen${NC}"
    echo "    Instalace:"
    echo "    - Ubuntu: sudo apt install whiptail dialog fzf"
    echo "    - Fedora: sudo dnf install newt dialog fzf"
    echo "    - Termux: pkg install dialog"
fi

echo -e "\nVolitelné závislosti:"
check_dep "git"
check_dep "jq"
check_dep "curl"
check_dep "node"
check_dep "npm"

# 4. Nabídnout instalaci chybějících závislostí
if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Chybějící závislosti: ${missing_deps[*]}${NC}"
    
    if [[ "$gui_found" == true ]]; then
        read -p "Chcete nainstalovat chybějící závislosti? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            source ./md_installer.sh --check-deps
        fi
    fi
fi

# 5. Web GUI setup
if [[ -d "web_gui" ]] && command -v npm &>/dev/null; then
    log "${YELLOW}4. Nastavuji Web GUI...${NC}"
    
    cd web_gui
    if [[ -f "package.json" ]]; then
        echo "Instaluji npm závislosti..."
        npm install --quiet
        echo -e "${GREEN}✅ Web GUI závislosti nainstalovány${NC}"
    else
        echo -e "${YELLOW}⚠️  package.json nebyl nalezen, vytvářím základní...${NC}"
        cat > package.json << 'EOF'
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
    "express": "^4.18.2",
    "socket.io": "^4.7.2"
  }
}
EOF
        npm init -y --quiet
        npm install express socket.io --save
    fi
    cd ..
else
    echo -e "${YELLOW}⚠️  Web GUI nelze nastavit (chybí npm nebo adresář)${NC}"
fi

# 6. Testovací spuštění
log "${YELLOW}5. Testovací spuštění...${NC}"

if [[ -f "md_installer.sh" ]]; then
    echo "Testuji hlavní skript..."
    if ./md_installer.sh --version; then
        echo -e "${GREEN}✅ Hlavní skript funguje${NC}"
    else
        echo -e "${RED}❌ Hlavní skript selhal${NC}"
    fi
fi

# 7. Vytvořit konfiguraci
log "${YELLOW}6. Vytvářím výchozí konfiguraci...${NC}"

CONFIG_FILE="version_manager/config/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
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
    "retention_days": 30,
    "max_backups": 50
  },
  "gui": {
    "default": "auto",
    "theme": "dark"
  }
}
EOF
    echo -e "${GREEN}✅ Konfigurace vytvořena${NC}"
else
    echo -e "${GREEN}✅ Konfigurace již existuje${NC}"
fi

# Závěr
echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}✅ INSTALACE DOKONČENA ÚSPĚŠNĚ!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}📋 Další kroky:${NC}"
echo "1. Spusťte aplikaci: ./md_installer.sh"
echo "2. Pro Web GUI: cd web_gui && npm start"
echo "3. Dokumentace: viz docs/ složka"
echo ""
echo -e "${YELLOW}🆘 Nápověda:${NC}"
echo "./md_installer.sh --help"
