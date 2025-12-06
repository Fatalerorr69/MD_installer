# ... existující kód ...

# Detekce Web GUI
check_web_gui() {
    if [ -f "$VM/web_gui/server.js" ]; then
        return 0  # Web GUI je nainstalováno
    else
        return 1  # Web GUI není nainstalováno
    fi
}

# Start Web GUI
start_web_gui() {
    echo "🌐 Spouštím Web GUI..."
    cd "$VM/web_gui"
    
    # Kontrola závislostí
    if [ ! -d "node_modules" ]; then
        echo "📦 Instaluji závislosti..."
        npm install > /dev/null 2>&1
    fi
    
    # Spuštění serveru na pozadí
    npm start &
    SERVER_PID=$!
    
    echo "✅ Server běží na http://localhost:3000"
    echo "   PID: $SERVER_PID"
    echo ""
    
    # Počkej 2 sekundy a pak otevři prohlížeč
    sleep 2
    
    # Otevři prohlížeč
    if command -v xdg-open > /dev/null 2>&1; then
        xdg-open "http://localhost:3000" 2>/dev/null
    elif command -v open > /dev/null 2>&1; then
        open "http://localhost:3000" 2>/dev/null
    elif command -v start > /dev/null 2>&1; then
        start "http://localhost:3000" 2>/dev/null
    fi
    
    echo "Stiskněte Enter pro návrat do menu..."
    read
    kill $SERVER_PID 2>/dev/null
}

# Instalace Web GUI
install_web_gui() {
    echo "📦 Instalace Web GUI..."
    echo ""
    
    # 1. Kontrola Node.js
    if ! command -v node > /dev/null 2>&1; then
        echo "❌ Node.js není nainstalován!"
        echo ""
        echo "Instalace Node.js:"
        echo "• Ubuntu/Debian: sudo apt install nodejs npm"
        echo "• Fedora: sudo dnf install nodejs"
        echo "• macOS: brew install node"
        echo "• Windows: https://nodejs.org"
        echo ""
        return 1
    fi
    
    echo "✅ Node.js: $(node --version)"
    echo "✅ npm: $(npm --version)"
    echo ""
    
    # 2. Vytvoř adresářovou strukturu
    echo "📁 Vytvářím strukturu..."
    mkdir -p "$VM/web_gui/public" "$VM/web_gui/api"
    
    # 3. Vytvoř soubory (použijeme zde dokumenty z předchozího kroku)
    echo "📝 Vytvářím soubory..."
    
    # server.js
    cat > "$VM/web_gui/server.js" << 'EOF'
// VLOŽTE OBSAH server.js ZDE
EOF

    # package.json
    cat > "$VM/web_gui/package.json" << 'EOF'
// VLOŽTE OBSAH package.json ZDE
EOF

    # ... a tak dále pro všechny soubory
    
    echo "✅ Web GUI nainstalováno!"
    echo "Spusťte: bash $VM/manager.sh a vyberte 'Spustit Web GUI'"
}

# Přidání volby do menu
add_web_gui_option() {
    if check_web_gui; then
        echo "8 Spustit Web GUI"
    else
        echo "8 Nainstalovat Web GUI"
    fi
}

# Hlavní menu s Web GUI
case "$GUI" in
    "fzf")
        # Přidat Web GUI do FZF options
        options=(
            "1 Zálohovat aktuální verzi"
            "2 Seznam verzí"
            "3 Přepnout verzi"
            "4 Synchronizace s Git (tagy)"
            "5 Generovat Changelog"
            "6 Zobrazit aktuální stav"
            "7 Konec"
            "$(add_web_gui_option)"
        )
        
        selection=$(printf '%s\n' "${options[@]}" | fzf_menu)
        ;;
    "whiptail"|"dialog")
        # Klasické menu
        if check_web_gui; then
            gui_option="8" 
            gui_text="Spustit Web GUI"
        else
            gui_option="8"
            gui_text="Nainstalovat Web GUI"
        fi
        
        selection=$($GUI --title "MD INSTALLER – Version Manager 6.0" \
            --menu "Vyber akci:" 20 60 11 \
            "1" "Zálohovat aktuální verzi" \
            "2" "Seznam verzí" \
            "3" "Přepnout verzi" \
            "4" "Synchronizace s Git (tagy)" \
            "5" "Generovat Changelog" \
            "6" "Zobrazit aktuální stav" \
            "7" "Konec" \
            "$gui_option" "$gui_text" \
            3>&1 1>&2 2>&3)
        ;;
    "text")
        clear
        echo "╔══════════════════════════════════════╗"
        echo "║   MD INSTALLER – Version Manager 6.0 ║"
        echo "╚══════════════════════════════════════╝"
        echo ""
        echo "1) Zálohovat aktuální verzi"
        echo "2) Seznam verzí"
        echo "3) Přepnout verzi"
        echo "4) Synchronizace s Git (tagy)"
        echo "5) Generovat Changelog"
        echo "6) Zobrazit aktuální stav"
        echo "7) Konec"
        
        if check_web_gui; then
            echo "8) Spustit Web GUI"
        else
            echo "8) Nainstalovat Web GUI"
        fi
        
        echo ""
        read -p "Vyber možnost [1-8]: " selection
        ;;
esac

# Zpracování výběru
case "$selection" in
    1|"1")
        bash "$VM/backup.sh"
        ;;
    2|"2")
        list_versions
        ;;
    3|"3")
        VERSION=$(select_version_menu)
        if [ -n "$VERSION" ]; then
            bash "$VM/switch.sh" use "$VERSION"
        fi
        ;;
    4|"4")
        bash "$VM/git_sync.sh"
        ;;
    5|"5")
        bash "$VM/changelog.sh"
        ;;
    6|"6")
        show_state
        ;;
    7|"7"|"")
        exit 0
        ;;
    8|"8")
        if check_web_gui; then
            start_web_gui
        else
            install_web_gui
            read -p "Stiskněte Enter pro pokračování..."
        fi
        ;;
esac
