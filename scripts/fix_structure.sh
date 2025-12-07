#!/usr/bin/env bash
# MD INSTALLER - RESTRUKTURACE PROJEKTU (OPRAVENÁ VERZE)

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
        "DEBUG")   [[ "$DRY_RUN" == true ]] && echo -e "${COLOR_CYAN}🔧 [DRY-RUN] ${message}${COLOR_RESET}" || echo -e "${COLOR_CYAN}🔧 ${message}${COLOR_RESET}" ;;
    esac
}

dry_run_check() {
    if [[ "$DRY_RUN" == true ]]; then
        log_message "DEBUG" "DRY-RUN: $1"
        return 1
    fi
    return 0
}

# ============================================================================
# ZÁLOHA
# ============================================================================

create_backup() {
    log_message "INFO" "Vytvářím zálohu stávající struktury..."
    
    if dry_run_check "Vytvořil bych zálohu v: $BACKUP_DIR"; then
        mkdir -p "$BACKUP_DIR"
        
        # Zálohovat důležité soubory
        [[ -d "$PROJECT_ROOT/version_manager" ]] && cp -r "$PROJECT_ROOT/version_manager" "$BACKUP_DIR/"
        [[ -d "$PROJECT_ROOT/web_gui" ]] && cp -r "$PROJECT_ROOT/web_gui" "$BACKUP_DIR/"
        [[ -f "$PROJECT_ROOT/md_installer.sh" ]] && cp "$PROJECT_ROOT/md_installer.sh" "$BACKUP_DIR/"
        [[ -f "$PROJECT_ROOT/package.json" ]] && cp "$PROJECT_ROOT/package.json" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    log_message "SUCCESS" "Záloha připravena: $BACKUP_DIR"
}

# ============================================================================
# NOVÁ STRUKTURA ADRESÁŘŮ
# ============================================================================

create_new_structure() {
    log_message "INFO" "Vytvářím novou adresářovou strukturu..."
    
    # Odstranit staré problémy (pouze v reálném režimu)
    if dry_run_check "Odstranil bych duplicitní node_modules"; then
        safe_remove "$PROJECT_ROOT/web_gui/node_modules"
        [[ -d "$PROJECT_ROOT/version_manager/web_gui" ]] && safe_remove "$PROJECT_ROOT/version_manager/web_gui"
    fi
    
    # Hlavní adresáře
    local dirs=(
        "core"
        "installers"
        "docs"
        "tests"
        "tests/unit"
        "tests/integration"
        "tests/performance"
        "tests/fixtures"
        "examples"
        "contrib"
        "etc"
        
        # Version Manager
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
        
        # Web GUI
        "version_manager/web"
        "version_manager/web/public"
        "version_manager/web/api"
        "version_manager/web/middleware"
    )
    
    for dir in "${dirs[@]}"; do
        if ! dry_run_check "Vytvořil bych adresář: $dir"; then
            mkdir -p "$PROJECT_ROOT/$dir"
        fi
    done
    
    log_message "SUCCESS" "Nová adresářová struktura připravena"
}

# ============================================================================
# PŘESUN A REORGANIZACE SOUBORŮ
# ============================================================================

reorganize_files() {
    log_message "INFO" "Reorganizuji soubory..."
    
    # 1. Core soubory
    if [[ -f "$PROJECT_ROOT/version_manager/manager.sh" ]] && ! dry_run_check "Přesunul bych manager.sh do core/"; then
        cp "$PROJECT_ROOT/version_manager/manager.sh" "$PROJECT_ROOT/core/bootstrap.sh"
        chmod +x "$PROJECT_ROOT/core/bootstrap.sh"
    fi
    
    # 2. Přesun skriptů do modules
    move_to_module "backup.sh" "backup"
    move_to_module "restore.sh" "backup"
    move_to_module "cleanup.sh" "backup"
    move_to_module "system_backup.sh" "backup"
    
    move_to_module "switch.sh" "switch"
    move_to_module "changelog.sh" "switch"
    
    move_to_module "diagnostics.sh" "diagnostics"
    
    move_to_module "upgrade.sh" "upgrade"
    
    # 3. Web GUI - sloučit obě verze
    merge_web_gui
    
    # 4. Symbolický odkaz pro zpětnou kompatibilitu
    create_symlink
    
    log_message "SUCCESS" "Soubory reorganizovány"
}

move_to_module() {
    local file="$1"
    local module="$2"
    
    if [[ -f "$PROJECT_ROOT/version_manager/$file" ]] && ! dry_run_check "Přesunul bych $file → modules/$module/"; then
        mv "$PROJECT_ROOT/version_manager/$file" "$PROJECT_ROOT/version_manager/modules/$module/"
    fi
}

merge_web_gui() {
    log_message "INFO" "Sloučím Web GUI..."
    
    local source_gui="$PROJECT_ROOT/web_gui"
    local dest_gui="$PROJECT_ROOT/version_manager/web"
    
    if [[ -d "$source_gui" ]] && ! dry_run_check "Sloučil bych Web GUI z $source_gui do $dest_gui"; then
        # Přesunout obsah kořenového web_gui
        if [[ -f "$source_gui/package.json" ]]; then
            cp "$source_gui/package.json" "$dest_gui/"
        fi
        
        if [[ -f "$source_gui/server.js" ]]; then
            cp "$source_gui/server.js" "$dest_gui/"
        fi
        
        if [[ -d "$source_gui/public" ]]; then
            cp -r "$source_gui/public/"* "$dest_gui/public/" 2>/dev/null || true
        fi
        
        # Zachovat důležité soubory
        find "$source_gui" -type f \( -name "*.js" -o -name "*.html" -o -name "*.css" -o -name "*.json" \) \
            -exec cp {} "$dest_gui/" 2>/dev/null \;
    fi
}

create_symlink() {
    log_message "INFO" "Vytvářím symbolické odkazy..."
    
    if ! dry_run_check "Vytvořil bych symbolický odkaz web_gui → version_manager/web"; then
        # Odstranit starý web_gui (pokud není odkaz)
        if [[ ! -L "$PROJECT_ROOT/web_gui" ]] && [[ -e "$PROJECT_ROOT/web_gui" ]]; then
            rm -rf "$PROJECT_ROOT/web_gui"
        fi
        
        # Vytvořit nový symbolický odkaz
        ln -sfn "version_manager/web" "$PROJECT_ROOT/web_gui"
    fi
}

# ============================================================================
# OPRAVA CEST V SOUBORECH
# ============================================================================

fix_file_paths() {
    log_message "INFO" "Opravuji cesty v souborech..."
    
    if dry_run_check "Opravil bych cesty v souborech"; then
        return
    fi
    
    # Hlavní spouštěč
    if [[ -f "$PROJECT_ROOT/md_installer.sh" ]]; then
        sed -i 's|version_manager/web_gui|version_manager/web|g' "$PROJECT_ROOT/md_installer.sh"
        sed -i 's|\./backup\.sh|./version_manager/modules/backup/backup.sh|g' "$PROJECT_ROOT/md_installer.sh"
        sed -i 's|\./switch\.sh|./version_manager/modules/switch/switch.sh|g' "$PROJECT_ROOT/md_installer.sh"
        sed -i 's|\./cleanup\.sh|./version_manager/modules/backup/cleanup.sh|g' "$PROJECT_ROOT/md_installer.sh"
        sed -i 's|\./restore\.sh|./version_manager/modules/backup/restore.sh|g' "$PROJECT_ROOT/md_installer.sh"
    fi
    
    log_message "SUCCESS" "Cesty opraveny"
}

# ============================================================================
# VYTVOŘENÍ CHYBĚJÍCÍCH SOUBORŮ
# ============================================================================

create_missing_files() {
    log_message "INFO" "Vytvářím chybějící systémové soubory..."
    
    # Core bootstrap (pokud neexistuje)
    if [[ ! -f "$PROJECT_ROOT/core/bootstrap.sh" ]] && ! dry_run_check "Vytvořil bych core/bootstrap.sh"; then
        cat > "$PROJECT_ROOT/core/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
# MD INSTALLER - CORE BOOTSTRAP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/version_manager/config/main.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Load modules
load_modules() {
    local module_dir="$PROJECT_ROOT/version_manager/modules"
    
    for module in "$module_dir"/*; do
        if [[ -d "$module" ]]; then
            for script in "$module"/*.sh; do
                if [[ -f "$script" ]]; then
                    source "$script"
                fi
            done
        fi
    done
}

# Initialize system
init_system() {
    echo "🚀 Initializing MD Installer..."
    load_modules
    echo "✅ System initialized"
}

# Main entry point
main() {
    init_system
    
    # Handle command line arguments
    case "${1:-}" in
        backup)
            backup_main "${@:2}"
            ;;
        restore)
            restore_main "${@:2}"
            ;;
        switch)
            switch_main "${@:2}"
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
    
    # Makefile
    if [[ ! -f "$PROJECT_ROOT/Makefile" ]] && ! dry_run_check "Vytvořil bych Makefile"; then
        cat > "$PROJECT_ROOT/Makefile" << 'EOF'
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
    
    log_message "SUCCESS" "Chybějící soubory připraveny"
}

# ============================================================================
# AKTUALIZACE NODE.JS ZÁVISLOSTÍ
# ============================================================================

update_dependencies() {
    log_message "INFO" "Aktualizuji Node.js závislosti..."
    
    local web_dir="$PROJECT_ROOT/version_manager/web"
    
    if [[ -f "$web_dir/package.json" ]]; then
        if dry_run_check "Aktualizoval bych Node.js závislosti v $web_dir"; then
            return
        fi
        
        cd "$web_dir"
        
        # Backup původního package.json
        if [[ -f "package.json" ]]; then
            cp "package.json" "package.json.backup"
        fi
        
        # Vytvořit/aktualizovat package.json
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
            
            # Remove old node_modules if exists
            [[ -d "node_modules" ]] && rm -rf node_modules
            
            # Install dependencies
            npm install --production
            log_message "SUCCESS" "Závislosti nainstalovány"
        else
            log_message "WARNING" "NPM není nainstalován, přeskočeno"
        fi
        
        cd "$PROJECT_ROOT"
    else
        log_message "WARNING" "package.json nenalezen, přeskočeno"
    fi
}

# ============================================================================
# BEZPEČNÉ ODSTRANĚNÍ
# ============================================================================

safe_remove() {
    local target="$1"
    
    if [[ -e "$target" ]] && ! dry_run_check "Odstranil bych: $target"; then
        rm -rf "$target"
    fi
}

# ============================================================================
# VALIDACE VÝSLEDKŮ
# ============================================================================

validate_structure() {
    log_message "INFO" "Validuji novou strukturu..."
    
    local errors=0
    
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
            else
                log_message "ERROR" "Chybí adresář: $dir"
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_message "SUCCESS" "Struktura validována"
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
    
    if dry_run_check "Vygeneroval bych report: $report_file"; then
        return
    fi
    
    cat > "$report_file" << EOF
# MD INSTALLER - REPORT RESTRUKTURACE

## 📅 Datum
$(date)

## 📊 Přehled
- **Režim:** ${DRY_RUN:-false}
- **Záloha:** ${BACKUP_DIR:-žádná}
- **Log soubor:** ${LOG_FILE}
- **Stav:** Úspěšně dokončeno

## 📁 Nová struktura
\`\`\`
$(find "$PROJECT_ROOT" -maxdepth 3 -type d | sort | sed 's|'$PROJECT_ROOT'/||' | grep -v '^$')
\`\`\`

## ✅ Kontrolní seznam
- [$(if [[ -d "$PROJECT_ROOT/core" ]]; then echo "x"; else echo " "; fi)] Core adresář
- [$(if [[ -d "$PROJECT_ROOT/version_manager/modules" ]]; then echo "x"; else echo " "; fi)] Moduly
- [$(if [[ -d "$PROJECT_ROOT/version_manager/web" ]]; then echo "x"; else echo " "; fi)] Web GUI
- [$(if [[ -L "$PROJECT_ROOT/web_gui" ]] || [[ -d "$PROJECT_ROOT/web_gui" ]]; then echo "x"; else echo " "; fi)] Symbolický odkaz
- [$(if [[ -f "$PROJECT_ROOT/version_manager/web/package.json" ]]; then echo "x"; else echo " "; fi)] package.json

## 🚀 Další kroky
1. Otestujte aplikaci: \`./md_installer.sh\`
2. Spusťte Web GUI: \`cd version_manager/web && npm start\`
3. Nainstalujte závislosti: \`make install\`

## ⚠️ Důležité
Záloha je k dispozici v: \`${BACKUP_DIR}\`

EOF
    
    log_message "SUCCESS" "Report vygenerován: $report_file"
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
  --no-backup   Neprováděj zálohu

Příklady:
  $0 --dry-run          # Simuluj změny
  $0                    # Proveď skutečné změny
EOF
}

main() {
    # Zpracovat argumenty
    for arg in "$@"; do
        case "$arg" in
            --dry-run)
                DRY_RUN=true
                log_message "INFO" "Spouštím v režimu DRY-RUN (žádné změny nebudou provedeny)"
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
    else
        log_message "INFO" "Přeskakuji instalaci závislostí (dry-run nebo npm není dostupný)"
    fi
    
    # 7. Validace
    if validate_structure; then
        # 8. Report
        generate_report
        
        echo ""
        echo -e "${COLOR_GREEN}══════════════════════════════════════════════════════${COLOR_RESET}"
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${COLOR_GREEN}✅ SIMULACE ÚSPĚŠNĚ DOKONČENA${COLOR_RESET}"
            echo -e "${COLOR_GREEN}   Žádné změny nebyly provedeny${COLOR_RESET}"
        else
            echo -e "${COLOR_GREEN}🎉 RESTRUKTURACE ÚSPĚŠNĚ DOKONČENA!${COLOR_RESET}"
        fi
        echo -e "${COLOR_GREEN}══════════════════════════════════════════════════════${COLOR_RESET}"
        echo ""
        
        if [[ "$DRY_RUN" == false ]]; then
            echo "📋 Co bylo provedeno:"
            echo "  1. ✅ Záloha vytvořena: $BACKUP_DIR"
            echo "  2. ✅ Nová struktura adresářů"
            echo "  3. ✅ Soubory reorganizovány"
            echo "  4. ✅ Cesty opraveny"
            echo "  5. ✅ Chybějící soubory vytvořeny"
            [[ "$(command -v npm)" ]] && echo "  6. ✅ Závislosti aktualizovány"
            echo "  7. ✅ Struktura validována"
            echo ""
            echo "🚀 Další kroky:"
            echo "  • Zkontrolujte report: cat restructure_report.md"
            echo "  • Otestujte: ./md_installer.sh"
            echo "  • Spusťte Web GUI: cd version_manager/web && npm start"
        fi
    else
        echo ""
        echo -e "${COLOR_RED}❌ RESTRUKTURACE SELHALA!${COLOR_RESET}"
        echo "Zkontrolujte log: $LOG_FILE"
        
        if [[ "$DRY_RUN" == false ]] && [[ -d "$BACKUP_DIR" ]]; then
            echo ""
            echo "🔄 Pro obnovení zálohy použijte:"
            echo "   cp -r $BACKUP_DIR/* ."
        fi
        
        exit 1
    fi
}

# Spustit hlavní funkci
main "$@"
