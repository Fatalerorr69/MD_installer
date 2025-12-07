#!/usr/bin/env bash
# Příklad pluginu pro MD Installer

PLUGIN_NAME="Příklad Pluginu"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Ukázkový plugin pro demonstraci funkcí"

# Funkce, která se volá při načtení pluginu
plugin_init() {
    echo "🔌 Plugin '$PLUGIN_NAME' v$PLUGIN_VERSION načten"
    log_message "INFO" "Plugin $PLUGIN_NAME inicializován"
}

# Hlavní funkce pluginu
run_example_task() {
    echo "🎯 Spouštím příklad úlohy..."
    
    # Zde může být jakákoliv logika
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "   Čas: $timestamp"
    echo "   Uživatel: $(whoami)"
    echo "   Adresář: $(pwd)"
    
    log_message "INFO" "Příklad úloha dokončena"
}

# Registrace do systému
register_plugin() {
    # Tato funkce se volá automaticky
    echo "📝 Registruji plugin..."
    
    # Můžete zde registrovat své funkce pro hooky
    # např.: register_hook "pre_backup" "run_example_task"
    
    return 0
}

# Hlavní spuštění
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Pokud je skript spuštěn přímo
    plugin_init
    run_example_task
else
    # Pokud je načten jako plugin
    register_plugin
fi
