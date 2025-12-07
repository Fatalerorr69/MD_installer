#!/usr/bin/env bash
# OPRAVENÝ BACKUP SKRIPT

set -euo pipefail

# Načtení konfigurace
CONFIG_FILE="$(dirname "$0")/config/config.json"
if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    COMPRESSION=$(jq -r '.backup.compression // "tar.gz"' "$CONFIG_FILE")
    RETENTION_DAYS=$(jq -r '.backup.retention_days // 30' "$CONFIG_FILE")
else
    COMPRESSION="tar.gz"
    RETENTION_DAYS=30
fi

# Adresáře
VM_DIR="$(dirname "$0")"
BACKUP_DIR="$VM_DIR/backups"
LOG_FILE="$VM_DIR/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Vytvoření adresářů
mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

# Funkce pro logování
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Hlavní funkce backupu
create_backup() {
    local backup_type="${1:-stable}"
    local backup_name="backup_${TIMESTAMP}_${backup_type}"
    
    log "🚀 Začínám zálohu: $backup_name"
    
    # 1. Zkontrolovat dostatek místa
    local free_space=$(df -Pk "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 1048576 ]]; then  # Méně než 1GB
        log "❌ Nedostatek místa pro zálohu"
        return 1
    fi
    
    # 2. Vytvořit seznam souborů k zálohování
    local files_to_backup=(
        "../*.sh"
        "../*.md"
        "../version_manager/*.sh"
    )
    
    # 3. Vytvořit archiv
    case "$COMPRESSION" in
        "tar.gz")
            local archive="${BACKUP_DIR}/${backup_name}.tar.gz"
            tar -czf "$archive" "${files_to_backup[@]}" 2>/dev/null || {
                log "❌ Chyba při vytváření TAR archivu"
                return 1
            }
            ;;
        "zip")
            local archive="${BACKUP_DIR}/${backup_name}.zip"
            zip -qr "$archive" "${files_to_backup[@]}" || {
                log "❌ Chyba při vytváření ZIP archivu"
                return 1
            }
            ;;
        *)
            log "❌ Neznámý typ komprese: $COMPRESSION"
            return 1
            ;;
    esac
    
    # 4. Vypočítat velikost a hash
    local size=$(du -h "$archive" | cut -f1)
    local hash=$(sha256sum "$archive" | cut -d' ' -f1)
    
    # 5. Aktualizovat stav
    update_state "$backup_name" "$backup_type" "$size" "$hash"
    
    # 6. Vyčistit staré zálohy
    cleanup_old_backups
    
    log "✅ Záloha úspěšně vytvořena: $archive ($size)"
    echo "$archive"
}

update_state() {
    local name="$1"
    local type="$2"
    local size="$3"
    local hash="$4"
    
    local state_file="$VM_DIR/state/backup_state.json"
    local state_dir="$(dirname "$state_file")"
    
    mkdir -p "$state_dir"
    
    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" << EOF
{
  "backups": [],
  "last_backup": null,
  "total_backups": 0
}
EOF
    fi
    
    if command -v jq &>/dev/null; then
        jq --arg name "$name" \
           --arg type "$type" \
           --arg size "$size" \
           --arg hash "$hash" \
           --arg timestamp "$(date -Iseconds)" \
           '.backups += [{
             name: $name,
             type: $type,
             size: $size,
             hash: $hash,
             timestamp: $timestamp
           }] | 
           .last_backup = $timestamp |
           .total_backups = (.backups | length)' \
           "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    fi
}

cleanup_old_backups() {
    log "🧹 Čistím staré zálohy (starší než $RETENTION_DAYS dní)"
    
    find "$BACKUP_DIR" -name "backup_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
}

# Interaktivní menu
if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
    echo "🎯 Vyberte typ zálohy:"
    echo "1) Stable (stabilní verze)"
    echo "2) Beta (testovací verze)"
    echo "3) Custom (vlastní nastavení)"
    
    read -p "Vaše volba [1-3]: " choice
    
    case "$choice" in
        1) create_backup "stable" ;;
        2) create_backup "beta" ;;
        3)
            read -p "Zadejte název zálohy: " custom_name
            create_backup "$custom_name"
            ;;
        *)
            echo "❌ Neplatná volba"
            exit 1
            ;;
    esac
else
    create_backup "${1:-stable}"
fi
