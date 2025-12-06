#!/usr/bin/env bash
# integrate_web_gui.sh

echo "🔧 Integrace Web GUI do MD Installer"
echo "===================================="

# 1. Vytvoř adresáře
mkdir -p version_manager/web_gui/public

# 2. Zkopíruj všechny vytvořené soubory
cp server.js version_manager/web_gui/
cp package.json version_manager/web_gui/
cp public/* version_manager/web_gui/public/

# 3. Uprav manager.sh
echo "📝 Aktualizuji manager.sh..."
sed -i '/7) Konec/a\8) Web GUI' version_manager/manager.sh

# 4. Vytvoř startovací skript
cat > version_manager/web_gui/start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
npm start
EOF

chmod +x version_manager/web_gui/start.sh

echo "✅ Hotovo! Spusťte:"
echo "   cd version_manager/web_gui && npm install && npm start"
echo "   nebo bash version_manager/manager.sh"
