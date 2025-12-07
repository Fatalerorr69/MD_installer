#!/usr/bin/env bash
# PLUGIN MANAGER - Správce pluginů pro MD Installer

set -euo pipefail

# ============================================================================
# KONFIGURACE
# ============================================================================

readonly PLUGINS_DIR="$(dirname "$0")"
readonly PLUGIN_API="$PLUGINS_DIR/plugin_api.sh"
readonly PLUGIN_REGISTRY="$PLUGINS_DIR/.registry"
readonly PLUGIN_TEMPLATES="$PLUGINS_DIR/templates"

# ============================================================================
# INICIALIZACE
# ============================================================================

init_plugin_system() {
    echo -e "${COLOR_CYAN}🔌 Inicializace plugin systému...${COLOR_RESET}"
    
    # Vytvořit potřebné adresáře
    mkdir -p "$PLUGIN_REGISTRY"
    mkdir -p "$PLUGIN_HOOKS_DIR"
    mkdir -p "$PLUGINS_DIR/templates"
    
    # Vytvořit hook adresáře pro každou událost
    for event in "${PLUGIN_EVENTS[@]}"; do
        mkdir -p "$PLUGIN_HOOKS_DIR/${event}.d"
    done
    
    # Načíst plugin API
    if [[ -f "$PLUGIN_API" ]]; then
        source "$PLUGIN_API"
    else
        echo -e "${COLOR_RED}❌ Plugin API nenalezeno${COLOR_RESET}"
        return 1
    fi
    
    echo -e "${COLOR_GREEN}✅ Plugin systém inicializován${COLOR_RESET}"
}

# ============================================================================
# SPRÁVA PLUGINŮ
# ============================================================================

load_all_plugins() {
    echo -e "${COLOR_BLUE}📂 Načítám pluginy...${COLOR_RESET}"
    
    local loaded_count=0
    local error_count=0
    
    # Najít všechny plugin složky
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        if [[ -d "$plugin_dir" ]]; then
            local plugin_name=$(basename "$plugin_dir")
            
            # Přeskočit systémové adresáře
            if [[ "$plugin_name" == "templates" ]] || [[ "$plugin_name" == ".registry" ]]; then
                continue
            fi
            
            # Načíst plugin
            if load_plugin "$plugin_name"; then
                ((loaded_count++))
            else
                ((error_count++))
            fi
        fi
    done
    
    echo -e "${COLOR_GREEN}✅ Načteno $loaded_count pluginů${COLOR_RESET}"
    if [[ $error_count -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}⚠️  $error_count pluginů se nepodařilo načíst${COLOR_RESET}"
    fi
    
    return $loaded_count
}

load_plugin() {
    local plugin_name="$1"
    local plugin_dir="$PLUGINS_DIR/$plugin_name"
    
    # Kontrola existence
    if [[ ! -d "$plugin_dir" ]]; then
        log_message "ERROR" "Plugin $plugin_name neexistuje"
        return 1
    fi
    
    # Najít hlavní plugin soubor
    local plugin_file=""
    if [[ -f "$plugin_dir/$plugin_name.sh" ]]; then
        plugin_file="$plugin_dir/$plugin_name.sh"
    elif [[ -f "$plugin_dir/main.sh" ]]; then
        plugin_file="$plugin_dir/main.sh"
    else
        # Hledat jakýkoliv .sh soubor
        local sh_files=("$plugin_dir"/*.sh)
        if [[ ${#sh_files[@]} -gt 0 ]] && [[ -f "${sh_files[0]}" ]]; then
            plugin_file="${sh_files[0]}"
        else
            log_message "ERROR" "Plugin $plugin_name nemá spustitelný soubor"
            return 1
        fi
    fi
    
    # Kontrola spustitelnosti
    if [[ ! -x "$plugin_file" ]]; then
        chmod +x "$plugin_file"
    fi
    
    # Načíst konfiguraci
    local config_file="$plugin_dir/config.json"
    local enabled=true
    
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        enabled=$(jq -r '.plugin.enabled // true' "$config_file")
    fi
    
    if [[ "$enabled" != "true" ]]; then
        log_message "INFO" "Plugin $plugin_name je vypnutý - přeskočen"
        return 0
    fi
    
    # Načíst plugin
    log_message "INFO" "Načítám plugin: $plugin_name"
    
    if source "$plugin_file" 2>/dev/null; then
        log_message "SUCCESS" "Plugin $plugin_name úspěšně načten"
        return 0
    else
        log_message "ERROR" "Chyba při načítání pluginu $plugin_name"
        return 1
    fi
}

# ============================================================================
# PLUGIN MENU
# ============================================================================

show_plugin_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}"
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║              SPRÁVA PLUGINŮ                         ║"
        echo "╠══════════════════════════════════════════════════════╣"
        echo "║  1) 📋 Seznam pluginů                              ║"
        echo "║  2) 🚀 Spustit plugin                              ║"
        echo "║  3) 📥 Instalovat plugin                           ║"
        echo "║  4) 🛠️  Vytvořit nový plugin                       ║"
        echo "║  5) ⚙️  Nastavení pluginů                          ║"
        echo "║  6) 🔄 Aktualizovat pluginy                        ║"
        echo "║  7) 📊 Statistiky pluginů                          ║"
        echo "║  8) 🚪 Zpět do hlavního menu                       ║"
        echo "╚══════════════════════════════════════════════════════╝"
        echo -e "${COLOR_RESET}"
        
        read -p "Vyberte možnost [1-8]: " choice
        
        case "$choice" in
            1) list_plugins ;;
            2) run_plugin_menu ;;
            3) install_plugin_menu ;;
            4) create_plugin_menu ;;
            5) plugin_settings_menu ;;
            6) update_plugins_menu ;;
            7) plugin_statistics ;;
            8) return ;;
            *) echo -e "${COLOR_RED}❌ Neplatná volba${COLOR_RESET}"; sleep 1 ;;
        esac
    done
}

list_plugins() {
    clear
    echo -e "${COLOR_CYAN}📋 Seznam pluginů${COLOR_RESET}"
    echo ""
    
    local plugins_count=0
    
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        if [[ -d "$plugin_dir" ]]; then
            local plugin_name=$(basename "$plugin_dir")
            
            # Přeskočit systémové adresáře
            if [[ "$plugin_name" == "templates" ]] || [[ "$plugin_name" == ".registry" ]]; then
                continue
            fi
            
            ((plugins_count++))
            
            # Získat informace o pluginu
            local plugin_info=""
            local config_file="$plugin_dir/config.json"
            
            if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
                local display_name=$(jq -r '.plugin.name // empty' "$config_file")
                local version=$(jq -r '.plugin.version // empty' "$config_file")
                local enabled=$(jq -r '.plugin.enabled // true' "$config_file")
                
                if [[ -z "$display_name" ]]; then
                    display_name="$plugin_name"
                fi
                
                local status_color="${COLOR_GREEN}"
                local status_icon="✅"
                if [[ "$enabled" != "true" ]]; then
                    status_color="${COLOR_RED}"
                    status_icon="❌"
                fi
                
                echo -e "  ${status_icon} ${COLOR_WHITE}${display_name}${COLOR_RESET}"
                echo -e "     📦 Verze: ${COLOR_CYAN}$version${COLOR_RESET}"
                echo -e "     📁 Adresář: ${COLOR_YELLOW}$plugin_name${COLOR_RESET}"
                echo -e "     🚀 Stav: ${status_color}$enabled${COLOR_RESET}"
                echo ""
            else
                echo -e "  ⚠️  ${COLOR_WHITE}$plugin_name${COLOR_RESET} (základní)"
                echo ""
            fi
        fi
    done
    
    if [[ $plugins_count -eq 0 ]]; then
        echo -e "${COLOR_YELLOW}⚠️  Žádné pluginy nenalezeny${COLOR_RESET}"
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}Celkem pluginů: $plugins_count${COLOR_RESET}"
    pause_for_return
}

# ============================================================================
# UKÁZKOVÉ OFICIÁLNÍ PLUGINY
# ============================================================================

### **Plugin 1: Auto Backup**
**Soubor:** `version_manager/plugins/official/auto_backup/auto_backup.sh`
```bash
#!/usr/bin/env bash
# AUTO BACKUP PLUGIN - Automatické zálohování

PLUGIN_NAME="auto_backup"
PLUGIN_VERSION="2.0.0"
PLUGIN_DESCRIPTION="Automatické zálohování podle plánu"

# Načíst API
source "$(dirname "$0")/../../plugin_api.sh"

# Konfigurace
CONFIG_FILE="$(dirname "$0")/config.json"
SCHEDULE_FILE="$(dirname "$0")/schedule.json"
LOG_FILE="$(dirname "$0")/backup.log"

# Inicializace pluginu
plugin_init() {
    register_plugin "$PLUGIN_NAME" "$PLUGIN_VERSION" "$PLUGIN_DESCRIPTION"
    
    # Registrace hooků
    register_hook "system_startup" "start_scheduler"
    register_hook "system_shutdown" "stop_scheduler"
    
    # Vytvořit výchozí konfiguraci
    create_default_config
    
    log_message "INFO" "Auto Backup plugin inicializován"
}

# Vytvořit výchozí konfiguraci
create_default_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
{
  "plugin": {
    "name": "Auto Backup",
    "version": "$PLUGIN_VERSION",
    "enabled": true,
    "auto_start": true
  },
  "backup": {
    "schedule": "0 2 * * *",  # Denně ve 2:00
    "type": "auto",
    "retention_days": 7,
    "max_backups": 10,
    "notify_on_success": true,
    "notify_on_error": true
  },
  "compression": {
    "method": "tar.gz",
    "level": 6
  }
}
EOF
    fi
    
    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        cat > "$SCHEDULE_FILE" << EOF
{
  "schedules": [
    {
      "name": "daily",
      "cron": "0 2 * * *",
      "enabled": true,
      "type": "full"
    },
    {
      "name": "weekly",
      "cron": "0 3 * * 0",
      "enabled": true,
      "type": "full"
    },
    {
      "name": "monthly",
      "cron": "0 4 1 * *",
      "enabled": true,
      "type": "full"
    }
  ]
}
EOF
    fi
}

# Spustit scheduler
start_scheduler() {
    local enabled=$(get_plugin_config "$PLUGIN_NAME" "plugin.enabled" "true")
    
    if [[ "$enabled" != "true" ]]; then
        log_message "INFO" "Auto Backup plugin je vypnutý"
        return 0
    fi
    
    log_message "INFO" "Spouštím Auto Backup scheduler"
    
    # Zde by se implementoval skutečný scheduler (cron, systemd timer, atd.)
    # Pro demonstraci jen logování
    echo "Auto Backup scheduler spuštěn: $(date)" >> "$LOG_FILE"
    
    show_plugin_message "Auto Backup" "Scheduler spuštěn" "success"
}

# Zastavit scheduler
stop_scheduler() {
    log_message "INFO" "Zastavuji Auto Backup scheduler"
    echo "Auto Backup scheduler zastaven: $(date)" >> "$LOG_FILE"
}

# Spustit naplánovanou zálohu
run_scheduled_backup() {
    local schedule_name="$1"
    local backup_type="$2"
    
    log_message "INFO" "Spouštím naplánovanou zálohu: $schedule_name"
    
    # Vytvořit zálohu
    local backup_result=$(create_backup_from_plugin "$PLUGIN_NAME" "$backup_type")
    
    if [[ $? -eq 0 ]]; then
        # Úspěch - odeslat notifikaci
        send_notification "✅ Naplánovaná záloha dokončena" "Záloha $schedule_name byla úspěšně vytvořena"
        
        # Vyčistit staré zálohy
        cleanup_old_backups
        
        log_message "SUCCESS" "Naplánovaná záloha $schedule_name dokončena"
    else
        # Chyba - odeslat notifikaci
        send_notification "❌ Chyba při zálohování" "Naplánovaná záloha $schedule_name selhala"
        log_message "ERROR" "Naplánovaná záloha $schedule_name selhala"
    fi
}

# Vyčistit staré zálohy
cleanup_old_backups() {
    local retention_days=$(get_plugin_config "$PLUGIN_NAME" "backup.retention_days" "7")
    local max_backups=$(get_plugin_config "$PLUGIN_NAME" "backup.max_backups" "10")
    
    log_message "INFO" "Čištění starých záloh (starší než $retention_days dní, max $max_backups)"
    
    # Implementace čištění
    # ...
}

# Odeslat notifikaci
send_notification() {
    local title="$1"
    local message="$2"
    
    # Zde by se implementovalo odesílání notifikací
    # (email, Slack, Discord, atd.)
    
    log_message "NOTIFY" "$title: $message"
    
    # Prozatím jen log
    echo "[$(date)] $title: $message" >> "$LOG_FILE"
}

# Hlavní funkce pluginu (volaná uživatelem)
run_plugin() {
    clear
    echo -e "${COLOR_CYAN}🔄 Auto Backup Plugin${COLOR_RESET}"
    echo ""
    
    echo "1) Spustit zálohu nyní"
    echo "2) Zobrazit plán"
    echo "3) Upravit nastavení"
    echo "4) Zobrazit logy"
    echo "5) Testovat notifikace"
    
    read -p "Vyberte akci [1-5]: " choice
    
    case $choice in
        1)
            echo "Spouštím zálohu..."
            run_scheduled_backup "manual" "full"
            ;;
        2)
            echo "Plán záloh:"
            cat "$SCHEDULE_FILE" | jq . 2>/dev/null || cat "$SCHEDULE_FILE"
            ;;
        3)
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        4)
            echo "Logy:"
            tail -20 "$LOG_FILE"
            ;;
        5)
            echo "Testování notifikací..."
            send_notification "Test" "Toto je testovací notifikace"
            ;;
    esac
}

# Načíst plugin
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Pokud je volán přímo
    plugin_init
    run_plugin
else
    # Pokud je načten jako modul
    plugin_init
fi
