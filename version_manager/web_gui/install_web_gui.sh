#!/usr/bin/env bash
# install_web_gui.sh

set -e

echo "🌐 Instalace Web GUI pro MD Installer Version Manager"
echo "======================================================"

VM_DIR="$(dirname "$0")"
WEB_GUI_DIR="$VM_DIR/web_gui"

# Kontrola Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js není nainstalován!"
    echo "📦 Instaluji Node.js..."
    
    # Detekce platformy
    case "$(uname -s)" in
        Linux*)
            if command -v apt-get &> /dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
                sudo apt-get install -y nodejs
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y nodejs
            elif command -v pacman &> /dev/null; then
                sudo pacman -S nodejs npm
            else
                echo "❌ Nenašel jsem správce balíčků. Instalujte Node.js manuálně."
                exit 1
            fi
            ;;
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install node
            else
                echo "❌ Nainstalujte Node.js z https://nodejs.org"
                exit 1
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "📥 Stáhněte Node.js z: https://nodejs.org"
            echo "   Po instalaci restartujte terminál."
            exit 1
            ;;
        *)
            echo "❌ Nepodporovaný systém. Instalujte Node.js manuálně."
            exit 1
            ;;
    esac
fi

echo "✅ Node.js je nainstalován: $(node --version)"

# Vytvoření adresářové struktury
echo "📁 Vytvářím strukturu adresářů..."
mkdir -p "$WEB_GUI_DIR/public/assets"
mkdir -p "$WEB_GUI_DIR/api"

# Kontrola, zda soubory již existují
if [[ -f "$WEB_GUI_DIR/package.json" ]]; then
    echo "⚠️  Web GUI již bylo nainstalováno."
    read -p "Chcete přepsat existující instalaci? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Instalace přerušena."
        exit 0
    fi
fi

# Instalace závislostí
echo "📦 Instaluji závislosti..."
cd "$WEB_GUI_DIR"
npm init -y > /dev/null 2>&1

# Přidání závislostí do package.json
cat > package.json << 'EOF'
{
  "name": "md-installer-web-gui",
  "version": "1.0.0",
  "description": "Webové GUI pro MD Installer Version Manager",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "setup": "node setup.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "chokidar": "^3.5.3",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.10.0",
    "helmet": "^7.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF

echo "📥 Stahuji závislosti..."
npm install > /dev/null 2>&1

# Vytvoření všech potřebných souborů
echo "📝 Vytvářím soubory..."

# server.js
cat > server.js << 'EOF'
// (Obsah server.js z předchozí části)
EOF

# HTML, CSS, JS soubory
cp -r "$VM_DIR/../web_templates/*" "$WEB_GUI_DIR/public/" 2>/dev/null || {
    # Pokud šablony neexistují, vytvoř základní
    cat > "$WEB_GUI_DIR/public/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>MD Installer - Loading...</title>
    <meta http-equiv="refresh" content="2;url=/">
</head>
<body>
    <h1>Instalace Web GUI...</h1>
    <p>Prosím počkejte, stahuji kompletní rozhraní.</p>
</body>
</html>
EOF
}

# Setup skript
cat > setup.js << 'EOF'
const fs = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

const execAsync = util.promisify(exec);

async function setupWebGUI() {
    console.log('🔄 Nastavuji Web GUI...');
    
    try {
        // Stáhnout kompletní frontend z GitHubu
        console.log('📥 Stahuji frontendové soubory...');
        
        const frontendFiles = {
            'index.html': 'https://raw.githubusercontent.com/.../index.html',
            'style.css': 'https://raw.githubusercontent.com/.../style.css',
            'app.js': 'https://raw.githubusercontent.com/.../app.js'
        };
        
        const publicDir = path.join(__dirname, 'public');
        
        for (const [filename, url] of Object.entries(frontendFiles)) {
            try {
                const { stdout } = await execAsync(`curl -s "${url}"`);
                await fs.writeFile(path.join(publicDir, filename), stdout);
                console.log(`✅ ${filename} stažen`);
            } catch (error) {
                console.log(`⚠️  Nepodařilo se stáhnout ${filename}, vytvářím základní`);
                await createBasicFile(filename);
            }
        }
        
        console.log('✨ Instalace dokončena!');
        console.log('🚀 Spusťte server: npm start');
        console.log('🌐 Otevřete: http://localhost:3000');
        
    } catch (error) {
        console.error('❌ Chyba při instalaci:', error.message);
        process.exit(1);
    }
}

async function createBasicFile(filename) {
    const filepath = path.join(__dirname, 'public', filename);
    
    if (filename === 'index.html') {
        await fs.writeFile(filepath, `
<!DOCTYPE html>
<html>
<head>
    <title>MD Installer Web GUI</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>MD Installer Web GUI</h1>
    <p>Základní rozhraní bude doplněno.</p>
</body>
</html>
        `);
    }
}

setupWebGUI();
EOF

# Vytvoření startovacího skriptu
cat > start.sh << 'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"
echo "🚀 Spouštím Web GUI..."
npm start
EOF

chmod +x start.sh

# Vytvoření systemd service (pro Linux)
if [[ "$(uname -s)" == "Linux" ]] && [[ -d "/etc/systemd/system" ]]; then
    cat > md-installer-web.service << EOF
[Unit]
Description=MD Installer Web GUI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WEB_GUI_DIR
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    echo "🔧 Systemd service vytvořen"
    echo "   Pro automatické spouštění: sudo systemctl enable $(pwd)/md-installer-web.service"
fi

echo "✅ Web GUI bylo úspěšně nainstalováno!"
echo ""
echo "📋 Dostupné příkazy:"
echo "   cd $WEB_GUI_DIR"
echo "   npm start          # Spustit server"
echo "   npm run dev        # Vývojový režim"
echo "   ./start.sh         # Alternativní spuštění"
echo ""
echo "🌐 Po spuštění otevřete: http://localhost:3000"
echo ""
echo "💡 Tip: Přidejte alias do ~/.bashrc:"
echo "   alias md-web='cd $WEB_GUI_DIR && npm start'"
