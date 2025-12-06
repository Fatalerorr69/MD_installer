#!/usr/bin/env node

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const util = require('util');
const chokidar = require('chokidar');

const execAsync = util.promisify(exec);

class VersionManagerServer {
    constructor() {
        this.app = express();
        this.server = http.createServer(this.app);
        this.io = socketIo(this.server);
        this.port = process.env.PORT || 3000;
        this.rootDir = path.join(__dirname, '..', '..');
        this.vmDir = path.join(this.rootDir, 'version_manager');
        this.backupsDir = path.join(this.vmDir, 'backups');
        
        this.setupMiddleware();
        this.setupRoutes();
        this.setupSocket();
        this.setupFileWatcher();
    }

    setupMiddleware() {
        this.app.use(express.json());
        this.app.use(express.static(path.join(__dirname, 'public')));
        this.app.use('/api', (req, res, next) => {
            res.header('Access-Control-Allow-Origin', '*');
            res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
            next();
        });
    }

    setupRoutes() {
        // API endpointy
        this.app.get('/api/status', async (req, res) => {
            try {
                const status = await this.getSystemStatus();
                res.json(status);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        this.app.get('/api/versions', async (req, res) => {
            try {
                const versions = await this.getVersions();
                res.json(versions);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        this.app.post('/api/backup', async (req, res) => {
            try {
                const { name, type = 'stable' } = req.body;
                const result = await this.createBackup(name, type);
                res.json(result);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        this.app.post('/api/switch', async (req, res) => {
            try {
                const { version } = req.body;
                const result = await this.switchVersion(version);
                res.json(result);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        this.app.get('/api/changelog/:version1/:version2', async (req, res) => {
            try {
                const { version1, version2 } = req.params;
                const changelog = await this.generateChangelog(version1, version2);
                res.json(changelog);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        this.app.get('/api/restore-points', async (req, res) => {
            try {
                const points = await this.getRestorePoints();
                res.json(points);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        // WebSocket test
        this.app.get('/ws-test', (req, res) => {
            res.sendFile(path.join(__dirname, 'public', 'ws-test.html'));
        });
    }

    setupSocket() {
        this.io.on('connection', (socket) => {
            console.log('Nový klient připojen:', socket.id);

            socket.on('get-status', async () => {
                const status = await this.getSystemStatus();
                socket.emit('status-update', status);
            });

            socket.on('create-backup', async (data) => {
                socket.emit('backup-started', { message: 'Zálohování zahájeno...' });
                
                try {
                    const result = await this.createBackup(data.name, data.type);
                    socket.emit('backup-completed', result);
                    
                    // Aktualizovat všechny klienty
                    const versions = await this.getVersions();
                    this.io.emit('versions-updated', versions);
                } catch (error) {
                    socket.emit('backup-error', { error: error.message });
                }
            });

            socket.on('switch-version', async (version) => {
                try {
                    const result = await this.switchVersion(version);
                    socket.emit('switch-completed', result);
                    
                    const status = await this.getSystemStatus();
                    this.io.emit('status-update', status);
                } catch (error) {
                    socket.emit('switch-error', { error: error.message });
                }
            });

            socket.on('disconnect', () => {
                console.log('Klient odpojen:', socket.id);
            });
        });
    }

    setupFileWatcher() {
        // Sledování změn v adresáři se zálohami
        const watcher = chokidar.watch(this.backupsDir, {
            persistent: true,
            ignoreInitial: true
        });

        watcher.on('add', async (path) => {
            console.log('Nová záloha přidána:', path);
            const versions = await this.getVersions();
            this.io.emit('versions-updated', versions);
        });

        watcher.on('unlink', async (path) => {
            console.log('Záloha odstraněna:', path);
            const versions = await this.getVersions();
            this.io.emit('versions-updated', versions);
        });
    }

    // API metody
    async getSystemStatus() {
        const stateFile = path.join(this.vmDir, 'state.json');
        
        try {
            const data = await fs.readFile(stateFile, 'utf8');
            const state = JSON.parse(data);
            
            // Získat systémové informace
            const { stdout: diskUsage } = await execAsync('df -h . | tail -1');
            const { stdout: memory } = await execAsync('free -m | head -2 | tail -1');
            
            return {
                currentVersion: state.current_version || 'N/A',
                lastBackup: state.last_backup || 'N/A',
                totalBackups: (await this.getVersions()).length,
                diskUsage: diskUsage.trim(),
                memory: memory.trim().split(/\s+/)[2] + ' MB used',
                timestamp: new Date().toISOString(),
                platform: process.platform
            };
        } catch (error) {
            return {
                currentVersion: 'N/A',
                lastBackup: 'N/A',
                totalBackups: 0,
                error: error.message
            };
        }
    }

    async getVersions() {
        try {
            const files = await fs.readdir(this.backupsDir);
            const versions = [];

            for (const file of files) {
                const filePath = path.join(this.backupsDir, file);
                const stats = await fs.stat(filePath);
                
                versions.push({
                    name: file,
                    displayName: file.replace('installer_', '').replace('.tar.gz', '').replace('.zip', ''),
                    path: filePath,
                    size: this.formatBytes(stats.size),
                    created: stats.birthtime,
                    type: file.includes('stable') ? 'stable' : 'beta',
                    format: file.endsWith('.zip') ? 'zip' : 'tar.gz'
                });
            }

            // Seřadit od nejnovějšího
            return versions.sort((a, b) => b.created - a.created);
        } catch (error) {
            console.error('Chyba při čtení verzí:', error);
            return [];
        }
    }

    async createBackup(name, type = 'stable') {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupName = name || `backup_${timestamp}`;
        
        // Spustit bash skript pro zálohu
        const scriptPath = path.join(this.vmDir, 'backup.sh');
        
        try {
            const { stdout, stderr } = await execAsync(
                `bash "${scriptPath}" --name "${backupName}" --type "${type}"`
            );

            return {
                success: true,
                message: 'Záloha úspěšně vytvořena',
                backupName: `${backupName}_${type}`,
                output: stdout,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`Chyba při zálohování: ${error.message}`);
        }
    }

    async switchVersion(version) {
        const scriptPath = path.join(this.vmDir, 'switch.sh');
        
        try {
            const { stdout, stderr } = await execAsync(
                `bash "${scriptPath}" use "${version}"`
            );

            return {
                success: true,
                message: `Úspěšně přepnuto na verzi: ${version}`,
                output: stdout,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`Chyba při přepínání: ${error.message}`);
        }
    }

    async generateChangelog(version1, version2) {
        // Implementace generování changelogu
        return {
            version1,
            version2,
            changes: ["Implementováno webové GUI", "Přidáno REST API", "Real-time aktualizace"],
            timestamp: new Date().toISOString()
        };
    }

    async getRestorePoints() {
        try {
            const gitPath = path.join(this.rootDir, '.git');
            const hasGit = await fs.access(gitPath).then(() => true).catch(() => false);

            if (!hasGit) {
                return [];
            }

            const { stdout } = await execAsync('git tag --sort=-creatordate');
            const tags = stdout.trim().split('\n').filter(tag => tag);

            return tags.map(tag => ({
                type: 'git_tag',
                name: tag,
                description: `Git tag: ${tag}`,
                timestamp: null
            }));
        } catch (error) {
            return [];
        }
    }

    formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 Bytes';
        
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }

    start() {
        this.server.listen(this.port, () => {
            console.log(`
╔══════════════════════════════════════════════════════╗
║        MD INSTALLER - WEB GUI SERVER                ║
║        =================================            ║
║                                                     ║
║  🌐 Server běží na: http://localhost:${this.port}       ║
║  📁 Root directory: ${this.rootDir}                 ║
║  ⚡ WebSocket: ws://localhost:${this.port}           ║
║                                                     ║
║  Otevři prohlížeč a přejdi na výše uvedenou adresu. ║
║                                                     ║
╚══════════════════════════════════════════════════════╝
            `);

            // Automaticky otevřít prohlížeč (pokud je to možné)
            if (process.platform === 'win32') {
                exec(`start http://localhost:${this.port}`);
            } else if (process.platform === 'darwin') {
                exec(`open http://localhost:${this.port}`);
            } else {
                exec(`xdg-open http://localhost:${this.port} 2>/dev/null`);
            }
        });
    }
}

// Spuštění serveru
const server = new VersionManagerServer();
server.start();

// Zpracování ukončení
process.on('SIGINT', () => {
    console.log('\n🔴 Vypínám server...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🔴 Vypínám server...');
    process.exit(0);
});
