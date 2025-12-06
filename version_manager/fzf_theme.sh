#!/usr/bin/env bash
# fzf_theme.sh – vlastní barevné téma

export FZF_DEFAULT_OPTS='
  --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
  --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff
  --color=info:#7aa2f7,prompt:#7dcfff,pointer:#bb9af7
  --color=marker:#73daca,spinner:#bb9af7,header:#73daca
  --color=border:#3b4261
  --height=50%
  --reverse
  --border=rounded
  --margin=1
  --padding=1
  --info=inline
  --prompt="🔧 "
  --pointer="▶"
  --marker="✓ "
'

# Použití ve skriptech:
# fzf --theme=md-installer
