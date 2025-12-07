#!/usr/bin/env bash
# SYSTEM MONITOR PLUGIN - Monitorování systému

PLUGIN_NAME="system_monitor"
PLUGIN_VERSION="1.5.0"
PLUGIN_DESCRIPTION="Monitorování systému a zasílání alertů"

source "$(dirname "$0")/../../plugin_api.sh"

# Inicializace
plugin_init() {
    register_plugin "$PLUGIN_NAME" "$PLUGIN_VERSION" "$PLUGIN_DESCRIPTION"
    
    register_hook "system_startup" "start_monitoring"
    register_hook "system_shutdown" "stop_monitoring"
    
    create_default_config
    log_message "INFO" "System Monitor plugin inicializován"
}

# Monitorování systému
start_monitoring() {
    # Spustit monitoring v pozadí
    monitor_cpu &
    monitor_memory &
    monitor_disk &
    monitor_network &
    
    echo "System monitoring started at $(date)" >> "/tmp/system_monitor.log"
}

# Sbírat metriky
collect_metrics() {
    local metrics_file="/tmp/system_metrics.json"
    
    cat > "$metrics_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "cpu": {
    "usage": "$(get_cpu_usage)",
    "load": "$(get_cpu_load)"
  },
  "memory": {
    "total": "$(get_memory_total)",
    "used": "$(get_memory_used)",
    "free": "$(get_memory_free)",
    "percentage": "$(get_memory_percentage)"
  },
  "disk": {
    "total": "$(get_disk_total)",
    "used": "$(get_disk_used)",
    "free": "$(get_disk_free)",
    "percentage": "$(get_disk_percentage)"
  },
  "system": {
    "uptime": "$(get_uptime)",
    "processes": "$(get_process_count)"
  }
}
EOF
    
    # Odeslat metriky do Web GUI
    send_websocket_message "metrics" "$(cat "$metrics_file")"
}

# Získat statistiky CPU
get_cpu_usage() {
    if command -v mpstat &>/dev/null; then
        mpstat 1 1 | awk '/Average:/ {print 100 - $NF"%"}'
    elif [[ -f "/proc/stat" ]]; then
        # Výpočet z /proc/stat
        echo "TODO: Calculate from /proc/stat"
    else
        echo "N/A"
    fi
}
