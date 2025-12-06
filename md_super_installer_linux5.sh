#!/usr/bin/env bash
set -euo pipefail

# ===============================================================
# MD SUPER INSTALLER 5.0 – Linux/WSL Edition
# GUI + AI poradce + auto generátor projektů
# ===============================================================

# ------------------------------
# Zenity check
# ------------------------------
if ! command -v zenity &>/dev/null; then
    echo "[INFO] Zenity nebyl nalezen, instaluji..."
    sudo apt update -y
    sudo apt install -y zenity
fi

# ------------------------------
# AI poradce
# ------------------------------
ai() {
    zenity --info --title="AI Poradce – MD Installer" --text="$1"
}

# ------------------------------
# Úvodní dialog
# ------------------------------
zenity --question \
    --title="MD SUPER INSTALLER 5.0" \
    --text="Vítej v instalátoru MD Toolkit Generator 5.0.\nChceš pokračovat?"

ai "Začínáme! Provedu tě celou instalací krok po kroku."

# ------------------------------
# Výběr cílové cesty
# ------------------------------
TARGET=$(zenity --file-selection --directory --title="Vyber složku pro instalaci")

if [ -z "$TARGET" ]; then
    zenity --error --text="Nebyla vybrána žádná složka."
    exit 1
fi

ai "Vybral jsi cestu: $TARGET"

ROOT="$TARGET/MD-Toolkit-Generator"
TOOLS="$ROOT/tools"

mkdir -p "$ROOT"
mkdir -p "$TOOLS"

# ------------------------------
# PROGRESS BAR – start
# ------------------------------
(
echo "5"; sleep 0.2
echo "# Vytvářím strukturu složek..."; sleep 0.3

mkdir -p "$ROOT"/{docs,modules,tests,config,SRC,FILES}
echo "15"; sleep 0.3

# ------------------------------
# Generátor projektů
# ------------------------------
echo "# Generuji hlavní project generator..."; sleep 0.3

cat > "$TOOLS/generator.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Použití: $0 <nazev_projektu>"
    exit 1
fi

PROJECT="$1"
VERSION="2.0.0"

mkdir -p "$PROJECT"/{SRC,docs,FILES,modules,tools,tests,config}

echo "# Projekt: $PROJECT" > "$PROJECT/README.md"
echo "TODO" > "$PROJECT/TODO.md"

cat > "$PROJECT/SRC/run.sh" << EOB
#!/usr/bin/env bash
echo '[INFO] Bash script running...'
EOB
chmod +x "$PROJECT/SRC/run.sh"

echo "print('[INFO] Python script running...')" > "$PROJECT/SRC/run.py"
echo "Write-Host '[INFO] PowerShell script running...'" > "$PROJECT/SRC/run.ps1"

(cd "$PROJECT"; git init -q; git add .; git commit -m "Initial auto-generated commit" -q)
EOF

chmod +x "$TOOLS/generator.sh"

echo "40"; sleep 0.3

# ------------------------------
# Dokumentace
# ------------------------------
echo "# Generuji dokumentaci..."; sleep 0.4

cat > "$ROOT/README.md" << 'EOF'
# MD Toolkit Generator 5.0 – Linux/WSL Edition
Tento nástroj vytváří kompletní MD projektovou strukturu.
EOF

cat > "$ROOT/CHANGELOG.md" << 'EOF'
# Changelog – MD Generator 5.0
- Initial release
EOF

cat > "$ROOT/NOTES.md" << 'EOF'
# Notes
Poznámky k projektu.
EOF

cat > "$ROOT/TODO.md" << 'EOF'
# TODO
- Rozšířit generátor
EOF

echo "65"; sleep 0.3

# ------------------------------
# Konfigurační soubory
# ------------------------------
echo "# Generuji konfiguraci..."; sleep 0.3

cat > "$ROOT/config/config.yaml" << 'EOF'
project:
  name: default
  version: 1.0
settings:
  logging: true
  debug: false
EOF

echo "75"; sleep 0.3

# -----
