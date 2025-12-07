#!/usr/bin/env bash
# PLUGIN API - Rozhraní pro tvorbu pluginů

set -euo pipefail

# ============================================================================
# GLOBÁLNÍ PROMĚNNÉ PLUGIN API
# ============================================================================

readonly PLUGIN_API_VERSION="2.0.0"
readonly PLUGIN_HOOKS_DIR="/tmp/md_installer_hooks"
readonly PLUGIN_EVENTS=(
    "pre_backup"
    "post_backup"
    "pre_restore"
    "post_restore"
    "system_startup"
    "system_shutdown"
    "error_occurred"
    "backup_created"
    "version_switched"
)

# ============================================================================
# ZÁKLADNÍ PLUGIN FUNKCE
# ============================================================================

# Registrace pluginu
register_plugin() {
    local plugin_name="$1"
    local plugin_version="$2"
    local plugin_description="${3:-No description}"
    
    log_message "PLUGIN" "Plugin registrován: $plugin_name v$plugin_version"
    
    # Uložit informace o pluginu
    local plugin_info="$PLUGINS_DIR/.registry/$plugin_name.info"
    cat > "$plugin_info" << EOF
name="$plugin_name"
version="$plugin_version"
description="$plugin_description"
registered="$(date -Iseconds)"
active="true"
EOF
}

# Registrace hooku
register_hook() {
    local hook_name="$1"
    local plugin_function="$2"
    
    # Kontrola, zda hook existuje
    if [[ ! " ${PLUGIN_EVENTS[@]} " =~ " ${hook_name} " ]]; then
        log_message "ERROR" "Neplatný hook: $hook_name"
        return 1
    fi
    
    # Vytvořit hook soubor
    local hook_file="$PLUGIN_HOOKS_DIR/${hook_name}.d/${plugin_function}.sh"
    mkdir -p "$(dirname "$hook_file")"
    
    cat > "$hook_file" << EOF
#!/usr/bin/env bash
# Hook: $hook_name
# Plugin: $plugin_function
# Created: $(date)

source "$PLUGINS_DIR/plugin_api.sh"
$plugin_function "\$@"
EOF
    
    chmod +x "$hook_file"
    log_message "DEBUG" "Hook registrovan: $hook_name -> $plugin_function"
}

# Spustit všechny hooky pro událost
execute_hooks() {
    local hook_name="$1"
    shift
    local args=("$@")
    
    local hook_dir="$PLUGIN_HOOKS_DIR/${hook_name}.d"
    
    if [[ -d "$hook_dir" ]]; then
        for hook_file in "$hook_dir"/*.sh; do
            if [[ -f "$hook_file" ]]; then
                log_message "DEBUG" "Spouštím hook: $(basename "$hook_file")"
                bash "$hook_file" "${args[@]}" || true
            fi
        done
    fi
}

# ============================================================================
# PLUGIN HELPER FUNKCE
# ============================================================================

# Získat konfiguraci pluginu
get_plugin_config() {
    local plugin_name="$1"
    local key="$2"
    local default="$3"
    
    local config_file="$PLUGINS_DIR/$plugin_name/config.json"
    
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r ".$key // \"$default\"" "$config_file" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Uložit konfiguraci pluginu
set_plugin_config() {
    local plugin_name="$1"
    local key="$2"
    local value="$3"
    
    local config_file="$PLUGINS_DIR/$plugin_name/config.json"
    mkdir -p "$(dirname "$config_file")"
    
    if [[ ! -f "$config_file" ]]; then
        echo "{}" > "$config_file"
    fi
    
    if command -v jq &>/dev/null; then
        local temp_file="${config_file}.tmp"
        jq ".$key = \"$value\"" "$config_file" > "$temp_file" && mv "$temp_file" "$config_file"
    fi
}

# Zobrazit zprávu v GUI
show_plugin_message() {
    local title="$1"
    local message="$2"
    local type="${3:-info}"
    
    case "$type" in
        "info")
            echo -e "ℹ️  $title: $message"
            ;;
        "success")
            echo -e "✅ $title: $message"
            ;;
        "warning")
            echo -e "⚠️  $title: $message"
            ;;
        "error")
            echo -e "❌ $title: $message"
            ;;
    esac
}

# Získat systémové informace
get_system_info() {
    cat << EOF
{
  "platform": "$PLATFORM",
  "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
  "user": "$(whoami)",
  "timestamp": "$(date -Iseconds)",
  "md_installer_version": "$VERSION"
}
EOF
}

# ============================================================================
# BACKUP API PRO PLUGINY
# ============================================================================

# Získat seznam záloh
get_backup_list() {
    find "$BACKUPS_DIR" -type f -name "*.tar.gz" -o -name "*.zip" | sort -r
}

# Získat informace o zálohě
get_backup_info() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        echo "{}"
        return 1
    fi
    
    local filename=$(basename "$backup_file")
    local size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file")
    local modified=$(stat -c%y "$backup_file" 2>/dev/null || stat -f%Sm "$backup_file")
    
    cat << EOF
{
  "filename": "$filename",
  "path": "$backup_file",
  "size_bytes": $size,
  "size_human": "$(numfmt --to=iec $size 2>/dev/null || echo ${size}B)",
  "modified": "$modified",
  "type": "${filename##*.}"
}
EOF
}

# Vytvořit novou zálohu (pro pluginy)
create_backup_from_plugin() {
    local plugin_name="$1"
    local backup_type="${2:-plugin}"
    
    log_message "INFO" "Plugin $plugin_name vytváří zálohu"
    
    # Spustit standardní backup skript
    if [[ -f "$VERSION_MANAGER_DIR/backup.sh" ]]; then
        bash "$VERSION_MANAGER_DIR/backup.sh" --type "$backup_type" --name "plugin_${plugin_name}_$(date +%Y%m%d_%H%M%S)"
    else
        log_message "ERROR" "Backup skript nenalezen"
        return 1
    fi
}

# ============================================================================
# WEB GUI API PRO PLUGINY
# ============================================================================

# Přidat stránku do Web GUI
add_web_gui_page() {
    local plugin_name="$1"
    local page_title="$2"
    local html_content="$3"
    
    local plugin_web_dir="$WEB_GUI_DIR/plugin_pages/$plugin_name"
    mkdir -p "$plugin_web_dir"
    
    # Vytvořit HTML stránku
    cat > "$plugin_web_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$page_title - MD Installer</title>
    <link rel="stylesheet" href="/css/plugin.css">
    <style>
        .plugin-container {
            padding: 20px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .plugin-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .plugin-content {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="plugin-container">
        <div class="plugin-header">
            <h1><i class="fas fa-plug"></i> $page_title</h1>
            <p>Plugin: $plugin_name</p>
        </div>
        <div class="plugin-content">
            $html_content
        </div>
    </div>
    
    <script src="/js/plugin_api.js"></script>
</body>
</html>
EOF
    
    log_message "INFO" "Web stránka vytvořena pro plugin: $plugin_name"
}

# Přidat widget do dashboardu
add_dashboard_widget() {
    local plugin_name="$1"
    local widget_title="$2"
    local widget_content="$3"
    local widget_type="${4:-info}"  # info, success, warning, error
    
    local widget_file="$WEB_GUI_DIR/widgets/${plugin_name}_widget.json"
    mkdir -p "$(dirname "$widget_file")"
    
    cat > "$widget_file" << EOF
{
  "plugin": "$plugin_name",
  "title": "$widget_title",
  "content": "$widget_content",
  "type": "$widget_type",
  "timestamp": "$(date -Iseconds)",
  "refresh_interval": 60
}
EOF
    
    log_message "DEBUG" "Dashboard widget přidán: $widget_title"
}

# ============================================================================
# EVENT SYSTEM PRO PLUGINY
# ============================================================================

# Odeslat událost všem pluginům
emit_event() {
    local event_name="$1"
    shift
    local event_data="$*"
    
    log_message "EVENT" "Událost: $event_name - $event_data"
    
    # Spustit hooky pro tuto událost
    execute_hooks "$event_name" "$event_data"
    
    # Odeslat do Web GUI přes WebSocket (pokud běží)
    if [[ -S "/tmp/md_installer_ws.sock" ]] || [[ -f "/tmp/md_installer_ws.pid" ]]; then
        send_websocket_message "event" "{\"type\":\"$event_name\",\"data\":\"$event_data\",\"timestamp\":\"$(date -Iseconds)\"}"
    fi
}

# Odeslat WebSocket zprávu
send_websocket_message() {
    local message_type="$1"
    local message_data="$2"
    
    # Toto by se integrovalo s WebSocket serverem
    local ws_message="{\"type\":\"$message_type\",\"data\":$message_data}"
    
    # Uložit do fronty pro WebSocket server
    echo "$ws_message" >> "/tmp/md_installer_ws_queue.txt"
}

# ============================================================================
# PLUGIN TEMPLATES
# ============================================================================

# Vytvořit základní plugin
create_basic_plugin() {
    local plugin_name="$1"
    local plugin_dir="$PLUGINS_DIR/$plugin_name"
    
    mkdir -p "$plugin_dir"
    
    # Hlavní plugin soubor
    cat > "$plugin_dir/$plugin_name.sh" << 'EOF'
#!/usr/bin/env bash
# Template: Základní plugin pro MD Installer

PLUGIN_NAME="my_plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Můj první plugin"

# Načíst API
source "$(dirname "$0")/../plugin_api.sh"

# Funkce, která se volá při načtení pluginu
plugin_init() {
    register_plugin "$PLUGIN_NAME" "$PLUGIN_VERSION" "$PLUGIN_DESCRIPTION"
    
    # Registrace hooků
    register_hook "system_startup" "on_system_startup"
    register_hook "pre_backup" "on_pre_backup"
    register_hook "post_backup" "on_post_backup"
    
    log_message "INFO" "Plugin $PLUGIN_NAME inicializován"
}

# Hook: Při startu systému
on_system_startup() {
    show_plugin_message "System Startup" "Plugin $PLUGIN_NAME je připraven" "info"
}

# Hook: Před zálohováním
on_pre_backup() {
    local backup_type="$1"
    show_plugin_message "Pre Backup" "Příprava zálohy typu: $backup_type" "info"
    
    # Zde může plugin provést nějakou akci před zálohou
    return 0
}

# Hook: Po zálohování
on_post_backup() {
    local backup_file="$1"
    show_plugin_message "Post Backup" "Záloha vytvořena: $backup_file" "success"
    
    # Zde může plugin provést nějakou akci po záloze
    return 0
}

# Hlavní funkce pluginu (volaná uživatelem)
run_plugin() {
    echo "🎯 Spouštím plugin: $PLUGIN_NAME"
    echo "📅 Verze: $PLUGIN_VERSION"
    echo "📝 Popis: $PLUGIN_DESCRIPTION"
    
    # Získat systémové informace
    local sys_info=$(get_system_info)
    echo "💻 Systém: $(echo "$sys_info" | jq -r '.platform')"
    
    # Ukázka práce se zálohami
    local backup_count=$(get_backup_list | wc -l)
    echo "📦 Počet záloh: $backup_count"
}

# Pokud je skript volán přímo
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    plugin_init
    run_plugin
else
    # Pokud je načten jako modul
    plugin_init
fi
EOF
    
    # Konfigurační soubor
    cat > "$plugin_dir/config.json" << EOF
{
  "plugin": {
    "name": "$plugin_name",
    "version": "1.0.0",
    "author": "$(whoami)",
    "enabled": true,
    "auto_start": false
  },
  "settings": {
    "option1": "default_value",
    "option2": 100,
    "notifications": true
  }
}
EOF
    
    # Dokumentace
    cat > "$plugin_dir/README.md" << EOF
# $plugin_name

Plugin pro MD Installer

## Funkce
- Základní příklad pluginu
- Ukázka hooků
- Konfigurovatelné nastavení

## Použití
1. Plugin se automaticky načte při startu MD Installer
2. Použijte \`run_plugin\` pro manuální spuštění
3. Konfigurace: upravte config.json

## Hooky
- system_startup: při startu aplikace
- pre_backup: před zálohováním
- post_backup: po zálohování

## Autor
Vytvořeno $(date +%Y-%m-%d)
EOF
    
    chmod +x "$plugin_dir/$plugin_name.sh"
    echo -e "${COLOR_GREEN}✅ Plugin vytvořen: $plugin_dir${COLOR_RESET}"
}
