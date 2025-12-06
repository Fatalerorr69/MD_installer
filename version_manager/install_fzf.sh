#!/usr/bin/env bash
# install_fzf.sh – automatická instalace FZF

install_fzf() {
    echo "📦 Instalace FZF (fuzzy finder)..."
    
    if command -v git >/dev/null; then
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all --no-bash --no-fish --no-zsh
        echo "✅ FZF nainstalován"
    else
        echo "❌ Git není dostupný pro instalaci FZF"
        return 1
    fi
}

# Detekce platformy
case "$(uname -s)" in
    Linux*)
        if command -v apt-get >/dev/null; then
            sudo apt-get update && sudo apt-get install -y fzf
        elif command -v dnf >/dev/null; then
            sudo dnf install -y fzf
        elif command -v pacman >/dev/null; then
            sudo pacman -S fzf
        else
            install_fzf
        fi
        ;;
    Darwin*)
        if command -v brew >/dev/null; then
            brew install fzf
        else
            install_fzf
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Windows Git Bash
        install_fzf
        ;;
    *)
        install_fzf
        ;;
esac
