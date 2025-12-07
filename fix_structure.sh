#!/usr/bin/env bash
# MD INSTALLER - RESTRUKTURACE PROJEKTU (OPRAVENÁ VERZE 2)

set -euo pipefail

# ============================================================================
# KONFIGURACE
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_DIR}"
readonly BACKUP_DIR="/tmp/md_installer_backup_$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${PROJECT_ROOT}/restructure.log"

# Barvy pro výstup
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Dry run flag
DRY_RUN=false

# ============================================================================
# POMOCNÉ FUNKCE
# ============================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "[${timestamp}] ${level}: ${message}" | tee -a "$LOG_FILE" >&2
    
    case "$level" in
        "INFO")    echo -e "${COLOR_BLUE}${message}${COLOR_RESET}" ;;
        "SUCCESS") echo -e "${COLOR_GREEN}✅ ${message}${COLOR_RESET}" ;;
        "WARNING") echo -e "${COLOR_YELLOW}⚠️  ${message}${COLOR_RESET}" ;;
        "ERROR")   echo -e "${COLOR_RED}❌ ${message}${COLOR_RESET}" ;;
        "DEBUG")   echo -e "${COLOR_CYAN}🔧 ${message}${COLOR_RESET}" ;;
    esac
}

# Funkce pro kontrolu dry-run režimu
should_execute() {
    if [[ "$DRY_RUN" == true ]]; then
        log_message "DEBUG" "[DRY-RUN] $1"
        return 1
    fi
    return 0
}

# ============================================================================
# ZÁLOHA
# ============================================================================

create_backup() {
    log_message "INFO" "Vytvářím zálohu stávající struktury..."
    
    if should_execute "Vytvořil bych zálohu v: $BACKUP_DIR"; then
        mkdir -p "$BACKUP_DIR"
        
        # Zálohovat důležité soubory
        [[ -d "$PROJECT_ROOT/version_manager" ]] && cp -r "$PROJECT_ROOT/version_manager" "$BACKUP_DIR/"
        [[ -d "$PROJECT_ROOT/web_gui" ]] && cp -r "$PROJECT_ROOT/web_gui" "$BACKUP_DIR/"
        [[ -f "$PROJECT_ROOT/md_installer.sh" ]] && cp "$PROJECT_ROOT/md_installer.sh" "$BACKUP_DIR/"
    fi
    
    log_message "SUCCESS" "Záloha připravena: $BACKUP_DIR"
}

# ============================================================================
# NOVÁ STRUKTURA ADRESÁŘŮ
# ============================================================================

create_new_structure() {
    log_message "INFO" "Vytvářím novou adresářovou strukturu..."
    
    if should_execute "Odstranil bych duplicitní node_modules"; then
        [[ -d "$PROJECT_ROOT/web_gui/node_modules" ]] && rm -rf "$PROJECT_ROOT/web_gui/node_modules"
        [[ -d "$PROJECT_ROOT/version_manager/web_gui" ]] && rm -rf "$PROJECT_ROOT/version_manager/web_gui"
    fi
    
    # Seznam adresářů k vytvoření
    local dirs=(
        "core"
        "installers"
        "docs"
        "tests/unit"
        "tests/integration"
        "tests/performance"
        "tests/fixtures"
        "examples"
        "contrib"
        "etc"
        "version_manager/modules/backup"
        "version_manager/modules/switch"
        "version_manager/modules/config"
        "version_manager/modules/diagnostics"
        "version_manager/modules/upgrade"
        "version_manager/plugins/official"
        "version_manager/plugins/community"
        "version_manager/plugins/templates"
        "version_manager/data/backups"
        "version_manager/data/state"
        "version_manager/data/cache"
        "version_manager/data/tmp"
        "version_manager/config"
        "version_manager/web/public"
        "version_manager/web/api"
        "version_manager/web/middleware"
    )
    
    for dir in "${dirs[@]}"; do
        if should_execute "Vytvořil bych adresář: $dir"; then
            mkdir -p "$PROJECT_ROOT/$dir"
        fi
    done
    
    log_message "SUCCESS" "Nová adresářová struktura vytvořena"
}

# ============================================================================
# PŘESUN A REORGANIZACE SOUBORŮ
# ============================================================================

reorganize_files() {
    log_message "INFO" "Reorganizuji soubory..."
    
    # 1. Přesun skriptů do modules
    move_to_module "backup.sh" "backup"
    move_to_module "restore.sh" "backup"
    move_to_module "cleanup.sh" "backup"
    move_to_module "system_backup.sh" "backup"
    move_to_module "switch.sh" "switch"
    move_to_module "changelog.sh" "switch"
    move_to_module "diagnostics.sh" "diagnostics"
    move_to_module "upgrade.sh" "upgrade"
    
    # 2. Přesun web_gui
    merge_web_gui
    
    # 3. Vytvořit symbolický odkaz
    create_symlink
    
    log_message "SUCCESS" "Soubory reorganizovány"
}

move_to_module() {
    local file="$1"
    local module="$2"
    
    local source="$PROJECT_ROOT/version_manager/$file"
    local target="$PROJECT_ROOT/version_manager/modules/$module/$file"
    
    if [[ -f "$source" ]]; then
        if should_execute "Přesunul bych $file → modules/$module/"; then
            mv "$source" "$target"
        fi
    fi
}

merge_web_gui() {
    log_message "INFO" "Sloučím Web GUI..."
    
    local source_gui="$PROJECT_ROOT/web_gui"
    local dest_gui="$PROJECT_ROOT/version_manager/web"
    
    if [[ -d "$source_gui" ]]; then
        if should_execute "Sloučil bych Web GUI z $source_gui do $dest_gui"; then
            # Přesunout package.json
            [[ -f "$source_gui/package.json" ]] && cp "$source_gui/package.json" "$dest_gui/"
            
            # Přesunout server.js
            [[ -f "$source_gui/server.js" ]] && cp "$source_gui/server.js" "$dest_gui/"
            
            # Přesunout public složku
            if [[ -d "$source_gui/public" ]]; then
                mkdir -p "$dest_gui/public"
                cp -r "$source_gui/public/"* "$dest_gui/public/" 2>/dev/null || true
            fi
            
            # Přesunout další důležité soubory
            for file in "$source_gui"/*; do
                if [[ -f "$file" ]] && [[ "$file" =~ \.(js|json|html|css)$ ]]; then
                    cp "$file" "$dest_gui/"
                fi
            done
        fi
    fi
}

create_symlink() {
    log_message "INFO" "Vytvářím symbolické odkazy..."
    
    if should_execute "Vytvořil bych symbolický odkaz web_gui → version_manager/web"; then
        # Odstranit starý web_gui pokud existuje
        [[ -e "$PROJECT_ROOT/web_gui" ]] && rm -rf "$PROJECT_ROOT/web_gui"
        
        # Vytvořit symbolický odkaz
        ln -sfn "version_manager/web" "$PROJECT_ROOT/web_gui"
    fi
}

# ============================================================================
# OPRAVA CEST V SOUBORECH
# ============================================================================

fix_file_paths() {
    log_message "INFO" "Opravuji cesty v souborech..."
    
    if should_execute "Opravil bych cesty v souborech"; then
        # Hlavní spouštěč
        if [[ -f "$PROJECT_ROOT/md_installer.sh" ]]; then
            sed -i 's|version_manager/web_gui|version_manager/web|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./backup\.sh|./version_manager/modules/backup/backup.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./switch\.sh|./version_manager/modules/switch/switch.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./cleanup\.sh|./version_manager/modules/backup/cleanup.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./restore\.sh|./version_manager/modules/backup/restore.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./system_backup\.sh|./version_manager/modules/backup/system_backup.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./diagnostics\.sh|./version_manager/modules/diagnostics/diagnostics.sh|g' "$PROJECT_ROOT/md_installer.sh"
            sed -i 's|\./upgrade\.sh|./version_manager/modules/upgrade/upgrade.sh|g' "$PROJECT_ROOT/md_installer.sh"
        fi
        
        # Aktualizovat skripty v modules
        for script in "$PROJECT_ROOT/version_manager/modules"/*/*.sh; do
            if [[ -f "$script" ]]; then
                sed -i 's|\.\./backups|../data/backups|g' "$script"
                sed -i 's|\.\./logs|../data/tmp|g' "$script"
                sed -i 's|\.\./config/|../config/|g' "$script"
                sed -i 's|\.\./plugins/|../plugins/|g' "$script"
            fi
        done
    fi
    
    log_message "SUCCESS" "Cesty opraveny"
}

# ============================================================================
# VYTVOŘENÍ CHYBĚJÍCÍCH SOUBORŮ
# ============================================================================

create_missing_files() {
    log_message "INFO" "Vytvářím chybějící systémové soubory..."
    
    if should_execute "Vytvořil bych core/bootstrap.sh"; then
        # Core bootstrap
        cat > "$PROJECT_ROOT/core/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
# MD INSTALLER - CORE BOOTSTRAP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load core utilities
source "$PROJECT_ROOT/core/utils.sh" 2>/dev/null || {
    echo "❌ Cannot load core utilities"
    exit 1
}

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/version_manager/config/main.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Load modules
load_module() {
    local module="$1"
    local module_path="$PROJECT_ROOT/version_manager/modules/$module"
    
    if [[ -f "$module_path.sh" ]]; then
        source "$module_path.sh"
    elif [[ -d "$module_path" ]]; then
        for script in "$module_path"/*.sh; do
            [[ -f "$script" ]] && source "$script"
        done
    fi
}

# Initialize system
init_system() {
    log_info "🚀 Initializing MD Installer..."
    
    # Load core modules
    load_module "backup"
    load_module "switch"
    load_module "config"
    load_module "diagnostics"
    load_module "upgrade"
    
    log_success "✅ System initialized"
}

# Main entry point
main() {
    init_system
    
    # Handle command line arguments
    case "${1:-}" in
        backup|restore|switch|diagnostics|upgrade)
            # Call the appropriate function
            "${1}_main" "${@:2}"
            ;;
        *)
            echo "Usage: $0 {backup|restore|switch|diagnostics|upgrade}"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
        chmod +x "$PROJECT_ROOT/core/bootstrap.sh"
    fi
    
    if should_execute "Vytvořil bych core/utils.sh"; then
        # Core utilities
        cat > "$PROJECT_ROOT/core/utils.sh" << 'EOF'
#!/usr/bin/env bash
# CORE UTILITY FUNCTIONS

log_info() { echo -e "ℹ️  $1"; }
log_success() { echo -e "✅ $1"; }
log_warning() { echo -e "⚠️  $1"; }
log_error() { echo -e "❌ $1" >&2; }

validate_path() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    return 0
}

backup_file() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_info "Backup created: $backup"
    fi
}

is_command_available() {
    command -v "$1" &>/dev/null
}

ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

safe_remove() {
    local target="$1"
    if [[ -e "$target" ]]; then
        rm -rf "$target"
        log_info "Removed: $target"
    fi
}
EOF
        chmod +x "$PROJECT_ROOT/core/utils.sh"
    fi
    
    if should_execute "Vytvořil bych Makefile"; then
        # Makefile
        cat > "$PROJECT_ROOT/Makefile" << 'EOF'
# MD INSTALLER MAKEFILE

.PHONY: install build test clean

install:
	@echo "Installing dependencies..."
	cd version_manager/web && npm install --production
	chmod +x md_installer.sh core/*.sh version_manager/modules/*/*.sh

build:
	@echo "Building..."

test:
	@echo "Testing..."
	@echo "No tests configured yet"

clean:
	@echo "Cleaning up..."
	rm -rf version_manager/data/cache/*
	rm -rf version_manager/data/tmp/*
EOF
    fi
    
    log_message "SUCCESS" "Chybějící soubory vytvořeny"
}

# ============================================================================
# AKTUALIZACE NODE.JS ZÁVISLOSTÍ
# ============================================================================

update_dependencies() {
    log_message "INFO" "Aktualizuji Node.js závislosti..."
    
    local web_dir="$PROJECT_ROOT/version_manager/web"
    
    if [[ ! -d "$web_dir" ]]; then
        log_message "WARNING" "Web directory not found: $web_dir"
        return
    fi
    
    if should_execute "Aktualizoval bych Node.js závislosti"; then
        cd "$web_dir"
        
        # Pokud už existuje package.json, vytvořit zálohu
        if [[ -f "package.json" ]]; then
            cp "package.json" "package.json.backup"
        fi
        
        # Vytvořit nový package.json
        cat > "package.json" << 'EOF'
{
  "name": "md-installer-web-gui",
  "version": "2.0.0",
  "description": "Web GUI for MD Installer",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo 'No tests yet'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF
        
        # Nainstalovat závislosti
        if command -v npm &>/dev/null; then
            log_message "INFO" "Installing npm dependencies..."
            
            # Odstranit staré node_modules pokud existují
            [[ -d "node_modules" ]] && rm -rf node_modules
            
            # Nainstalovat
            npm install --production
            log_message "SUCCESS" "Závislosti nainstalovány"
        else
            log_message "WARNING" "NPM není nainstalován, přeskočeno"
        fi
        
        cd "$PROJECT_ROOT"
    fi
}

# ============================================================================
# VALIDACE VÝSLEDKŮ
# ============================================================================

validate_structure() {
    log_message "INFO" "Validuji novou strukturu..."
    
    local errors=0
    local warnings=0
    
    # Kontrola povinných adresářů
    local required_dirs=(
        "core"
        "version_manager/modules"
        "version_manager/data"
        "version_manager/web"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_message "WARNING" "DRY-RUN: Chyběl by adresář: $dir"
                ((warnings++))
            else
                log_message "ERROR" "Chybí adresář: $dir"
                ((errors++))
            fi
        fi
    done
    
    # Kontrola povinných souborů
    local required_files=(
        "md_installer.sh"
        "core/bootstrap.sh"
        "core/utils.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_message "WARNING" "DRY-RUN: Chyběl by soubor: $file"
                ((warnings++))
            else
                log_message "ERROR" "Chybí soubor: $file"
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_message "SUCCESS" "DRY-RUN: Validace úspěšná - $warnings varování"
        else
            log_message "SUCCESS" "Struktura validována - žádné chyby"
        fi
        return 0
    else
        log_message "ERROR" "Nalezeno $errors chyb v nové struktuře"
        return 1
    fi
}

# ============================================================================
# VYTVOŘENÍ REPORTU
# ============================================================================

generate_report() {
    log_message "INFO" "Generuji report..."
    
    local report_file="$PROJECT_ROOT/restructure_report.md"
    
    if should_execute "Vygeneroval bych report"; then
        cat > "$report_file" << EOF
# MD INSTALLER - REPORT RESTRUKTURACE

## 📅 Datum
$(date)

## 📊 Přehled
- **Režim:** ${DRY_RUN:-false}
- **Záloha:** ${BACKUP_DIR}
- **Log soubor:** ${LOG_FILE}
- **Stav:** Úspěšně dokončeno

## 📁 Nová struktura (první 3 úrovně)
\`\`\`
$(find "$PROJECT_ROOT" -maxdepth 3 -type d | sort | sed 's|'$PROJECT_ROOT'/||' | grep -v '^$' | head -30)
\`\`\`

## ✅ Kontrolní seznam
- [$(if [[ -d "$PROJECT_ROOT/core" ]]; then echo "x"; else echo " "; fi)] Core adresář
- [$(if [[ -d "$PROJECT_ROOT/version_manager/modules" ]]; then echo "x"; else echo " "; fi)] Moduly
- [$(if [[ -d "$PROJECT_ROOT/version_manager/web" ]]; then echo "x"; else echo " "; fi)] Web GUI
- [$(if [[ -L "$PROJECT_ROOT/web_gui" ]] || [[ -d "$PROJECT_ROOT/web_gui" ]]; then echo "x"; else echo " "; fi)] Symbolický odkaz
- [$(if [[ -f "$PROJECT_ROOT/md_installer.sh" ]]; then echo "x"; else echo " "; fi)] Hlavní skript
- [$(if [[ -f "$PROJECT_ROOT/version_manager/web/package.json" ]]; then echo "x"; else echo " "; fi)] package.json

## 🚀 Další kroky
1. Otestujte aplikaci: \`./md_installer.sh\`
2. Spusťte Web GUI: \`cd version_manager/web && npm start\`
3. Nainstalujte závislosti: \`make install\`

## ⚠️ Důležité
Záloha je k dispozici v: \`${BACKUP_DIR}\`

EOF
        log_message "SUCCESS" "Report vygenerován: $report_file"
    fi
}

# ============================================================================
# HLAVNÍ FUNKCE
# ============================================================================

show_help() {
    cat << EOF
Použití: $0 [OPTIONS]

Restrukturalizuje MD Installer projekt

Options:
  --dry-run     Simuluj změny bez provedení
  --help        Zobraz tuto nápovědu

Příklady:
  $0 --dry-run          # Simuluj změny
  $0                    # Proveď skutečné změny
EOF
}

main() {
    # Zpracovat argumenty
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--dryrun|-d)
                DRY_RUN=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
        esac
    done
    
    echo -e "${COLOR_CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       MD INSTALLER - RESTRUKTURACE PROJEKTU         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${COLOR_YELLOW}⚠️  REŽIM DRY-RUN: Žádné skutečné změny nebudou provedeny${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   (pouze simulace)${COLOR_RESET}"
        echo ""
    fi
    
    # 1. Záloha
    create_backup
    
    # 2. Nová struktura
    create_new_structure
    
    # 3. Reorganizace souborů
    reorganize_files
    
    # 4. Oprava cest
    fix_file_paths
    
    # 5. Vytvoření chybějících souborů
    create_missing_files
    
    # 6. Aktualizace závislostí (pouze pokud není dry-run a npm je dostupný)
    if [[ "$DRY_RUN" == false ]] && command -v npm &>/dev/null; then
        update_dependencies
    elif [[ "$DRY_RUN" == true ]]; then
        log_message "INFO" "DRY-RUN: Přeskakuji instalaci závislostí"
    else
        log_message "WARNING" "NPM není nainstalován, přeskočeno instalaci závislostí"
    fi
    
    # 7. Validace
    if validate_structure; then
        # 8. Report
        generate_report
        
        echo ""
        echo -e "${COLOR_GREEN}══════════════════════════════════════════════════════${COLOR_RESET}"
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${COLOR_GREEN}✅ SIMULACE ÚSPĚŠNĚ DOKONČENA${COLOR_RESET}"
            echo -e "${COLOR_GREEN}   Žá
