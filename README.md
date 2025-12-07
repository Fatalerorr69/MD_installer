# 🚀 MD Installer - Version Manager

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Termux-green)
![License](https://img.shields.io/badge/license-MIT-orange)

## 📖 Obsah
- [Úvod](#úvod)
- [Funkce](#funkce)
- [Rychlý start](#rychlí-start)
- [Instalace](#instalace)
- [Použití](#použití)
- [Struktura projektu](#struktura-projektu)
- [Konfigurace](#konfigurace)
- [Webové rozhraní](#webové-rozhraní)
- [Podpora](#podpora)

## 🎯 Úvod

MD Installer je **komplexní správce verzí** pro vaše projekty. Umožňuje snadné zálohování, správu verzí a synchronizaci mezi zařízeními.

## ✨ Funkce

### ✅ Základní funkce
- **Zálohování** - Komprimované archivy (TAR.GZ, ZIP)
- **Správa verzí** - Přepínání mezi verzemi
- **Git synchronizace** - Automatická sync s GitHub
- **Changelog** - Generování přehledu změn

### 🎨 Uživatelská rozhraní
- **Moderní TUI** - Whiptail, Dialog, FZF
- **Web GUI** - Moderní webové rozhraní
- **CLI** - Příkazová řádka

### 🌐 Multiplatformní podpora
- **Linux** (Ubuntu, Debian, Fedora, Arch)
- **macOS** 
- **Windows** (Git Bash, WSL)
- **Android** (Termux)

## 🚀 Rychlý start

### Základní použití:
```bash
# Naklonujte repozitář
git clone https://github.com/Fatalerorr69/MD_installer.git
cd MD_installer

# Instalace
chmod +x scripts/install.sh
./scripts/install.sh

# Spuštění
./md_installer.sh


MD_installer/
├── md_installer.sh              # HLAVNÍ SPOUŠTĚCÍ SKRIPT
├── README.md                    # Tato dokumentace
├── version_manager/             # Jádro aplikace
│   ├── backup.sh               # Zálohovací skript
│   ├── switch.sh               # Přepínač verzí
│   ├── git_sync.sh             # Git synchronizace
│   ├── changelog.sh            # Generátor changelogu
│   ├── config/                 # Konfigurace
│   │   ├── main.json
│   │   ├── dependencies.json
│   │   └── platforms.json
│   ├── backups/                # Uložené zálohy
│   ├── logs/                   # Logy aplikace
│   └── plugins/                # Uživatelské pluginy
├── web_gui/                    # Webové rozhraní
│   ├── server.js
│   ├── package.json
│   └── public/
│       ├── index.html
│       └── css/
├── scripts/                    # Pomocné skripty
│   ├── install.sh
│   └── update.sh
└── docs/                       # Dokumentace
    ├── user_guide.md
    └── api_reference.md
