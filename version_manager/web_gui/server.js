const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const fs = require('fs').promises;
const chokidar = require('chokidar');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const PORT = process.env.PORT || 3000;
const PROJECT_ROOT = path.join(__dirname, '..');
const VM_DIR = path.join(PROJECT_ROOT, 'version_manager');

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.use(cors());

// API endpointy
app.get('/api/status', async (req, res) => {
    try {
        const status = await getSystemStatus();
        res.json(status);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/backups', async (req, res) => {
    try {
        const backups = await getBackups();
        res.json(backups);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/backup', async (req, res) => {
    try {
        const { name, type } = req.body;
        const result = await createBackup(name, type);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// WebSocket
io.on('connection', (socket) => {
    console.log('Nový klient připojen');
    
    socket.on('get-status', async () => {
        const status = await getSystemStatus();
        socket.emit('status-update', status);
    });
    
    socket.on('disconnect', () => {
        console.log('Klient odpojen');
    });
});

// Pomocné funkce
async function getSystemStatus() {
    const stateFile = path.join(VM_DIR, 'state', 'backup_state.json');
    
    try {
        const data = await fs.readFile(stateFile, 'utf8');
        const state = JSON.parse(data);
        
        return {
            version: '1.0.0',
            lastBackup: state.last_backup,
            totalBackups: state.total_backups,
            backups: state.backups || [],
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        return {
            version: '1.0.0',
            lastBackup: null,
            totalBackups: 0,
            backups: [],
            error: error.message
        };
    }
}

async function getBackups() {
    const backupsDir = path.join(VM_DIR, 'backups');
    
    try {
        const files = await fs.readdir(backupsDir);
        const backups = [];
        
        for (const file of files) {
            const filePath = path.join(backupsDir, file);
            const stats = await fs.stat(filePath);
            
            backups.push({
                name: file,
                size: formatBytes(stats.size),
                created: stats.birthtime,
                modified: stats.mtime
            });
        }
        
        return backups.sort((a, b) => b.created - a.created);
    } catch (error) {
        return [];
    }
}

async function createBackup(name, type = 'stable') {
    // Zavolá bash skript pro vytvoření zálohy
    const { exec } = require('child_process');
    const util = require('util');
    const execAsync = util.promisify(exec);
    
    const backupScript = path.join(VM_DIR, 'backup.sh');
    
    try {
        const { stdout, stderr } = await execAsync(`bash "${backupScript}" "${type}"`);
        return {
            success: true,
            message: 'Záloha vytvořena',
            output: stdout,
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        throw new Error(`Chyba při zálohování: ${error.message}`);
    }
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Spuštění serveru
server.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════════╗
║           MD INSTALLER WEB GUI                       ║
║           ======================                     ║
║                                                      ║
║  🌐 Server běží na: http://localhost:${PORT}         ║
║  📁 Sleduji změny v: ${VM_DIR}                       ║
║  ⚡ WebSocket: ws://localhost:${PORT}                 ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
    `);
});
