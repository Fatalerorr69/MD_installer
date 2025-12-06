#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ======================================================================
# MD SUPER INSTALLER 5.0 – TERMUX EDITION
# GUI (dialog), AI poradce, generátor projektů, auto struktura
# ======================================================================

# -----------------------------
# Kontrola dialog
# -----------------------------
if ! command -v dialog &>/dev/null; then
    echo "[INFO] Instalace dialog..."
    pkg update -y
    pkg install dialog -y
fi

# -----------------------------
# AI Poradce
# -----------------------------
ai() {
    dialog --title "AI Poradce – MD Installer" --msgbox "$1" 12 60
}

# -----------------------------
# Uvítání
# -----------------------------
dialog --title "MD SUPER INSTALLER 5.0 – TERMUX" \
--yesno "Vítej v interaktivním MD Toolkit Generator instalátoru.\nChceš pokračovat?" 10 60

if [ $? -ne 0 ]; then
    exit 1
fi

ai "Tento instalátor vytvoří kompletní MD Toolkit Generator strukturu pro Termux.\n\
Neboj, všechno udělám za tebe krok po kroku."

# -----------------------------
# Výběr cílové složky
# -----------------------------
TARGET=$(dialog --stdout --inputbox "Zadej cestu pro instalaci:\nNapř.: /data/data/com.termux/files/home/MD" 10 60)

if [ -z "$TARGET" ]; then
    dialog --msgbox "Nebyla zadána žádná cesta." 8 40
    exit 1
fi

ROOT="$TARGET/MD-Toolkit-Generator"
TOOLS="$ROOT/tools"

mkdir -p "$ROOT"
mkdir -p "$TOOLS"

ai "Instaluji do: $ROOT"

# -----------------------------
# PROGRESS BAR – simulace
# -----------------------------
(
sleep 0.2; echo "5"
sleep 0.2; echo "10"
sleep 0.2; echo "15"
) | dialog --title "Příprava instalace..." --gauge "Startuji..." 10 60 0

# ======================================================================
# Vytvoření struktury
# ======================================================================

(
mkdir -p "$ROOT"/{docs,modules,tests,config,SRC,FILES}

echo "20"; sleep 0.2
echo "Vytvářím projektový generátor..." >&2

# -----------------------------
# GENERÁTOR PROJEKTŮ
# -----------------------------
cat > "$TOOLS/generator.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Použití: $0 <nazev_projektu>"
    exit 1
fi

PROJECT="$1"
VERSION="2.0.0"

mkdir -p "$PROJECT"/{SRC,docs,FILES,modules,tools,tests,config}

# Dokumentace
echo "# Projekt: $PROJECT" > "$PROJECT/README.md"
echo "- první použití" > "$PROJECT/TODO.md"

# Bash script
cat > "$PROJECT/SRC/run.sh" << EOB
#!/data/data/com.termux/files/usr/bin/bash
echo '[INFO] Bash script running...'
EOB
chmod +x "$PROJECT/SRC/run.sh"

# Python script
echo "print('[INFO] Python script running...')" > "$PROJECT/SRC/run.py"

# PowerShell placeholder
echo "Write-Host '[INFO] PowerShell script running...'" > "$PROJECT/SRC/run.ps1"

# Git init (pokud existuje)
if command -v git &>/dev/null; then
    (cd "$PROJECT"; git init -q; git add .; git commit -m "Init" -q)
fi
EOF

chmod +x "$TOOLS/generator.sh"

echo "50"; sleep 0.2
echo "Generuji dokumentaci..." >&2

# -----------------------------
# Dokumentace
# -----------------------------
cat > "$ROOT/README.md" << 'EOF'
# MD Toolkit Generator 5.0 – Termux Edition
Kompletní generátor projektů pro Android Termux.
EOF

cat > "$ROOT/CHANGELOG.md" << 'EOF'
# Changelog – Termux Edition
- First Release 5.0
EOF

cat > "$ROOT/NOTES.md" << 'EOF'
# Notes
Poznámky k projektu.
EOF

cat > "$ROOT/TODO.md" << 'EOF'
# TODO
- Rozšířit generátor
EOF

echo "70"; sleep 0.2
echo "Generuji konfiguraci..." >&2

cat > "$ROOT/config/config.yaml" << 'EOF'
project:
  name: default
  version: 1.0
settings:
  logging: true
  debug: false
EOF

echo "100"; sleep 0.3
) | dialog --title "Instalace probíhá..." --gauge "Instaluji MD Toolkit Generator 5.0..." 10 60 0

# ======================================================================
# FINÁLE
# ======================================================================

ai "Instalace dokončena!\n\
Tvůj generátor projektů je zde:\n\
$ROOT/tools/generator.sh\n\
\nNový projekt vytvoříš příkazem:\n\
./tools/generator.sh MujProjekt"

dialog --title "Hotovo!" \
--msgbox "MD SUPER INSTALLER 5.0 – TERMUX EDITION byl úspěšně dokončen." 10 60
