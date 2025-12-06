class VersionManagerGUI {
    constructor() {
        this.socket = null;
        this.currentView = 'dashboard';
        this.versions = [];
        this.status = {};
        this.init();
    }

    init() {
        this.connectWebSocket();
        this.setupEventListeners();
        this.loadInitialData();
        this.setupViewSwitching();
    }

    connectWebSocket() {
        this.socket = io();
        
        this.socket.on('connect', () => {
            this.updateConnectionStatus(true);
            this.showToast('✅ Připojeno k serveru', 'success');
            this.socket.emit('get-status');
        });
        
        this.socket.on('disconnect', () => {
            this.updateConnectionStatus(false);
            this.showToast('❌ Odpojeno od serveru', 'error');
        });
        
        this.socket.on('status-update', (status) => {
            this.updateStatus(status);
        });
        
        this.socket.on('versions-updated', (versions) => {
            this.versions = versions;
            this.updateVersionsList();
            this.updateRecentBackups();
            this.updateVersionSelects();
        });
        
        this.socket.on('backup-started', (data) => {
            this.showBackupModal(data.message);
        });
        
        this.socket.on('backup-completed', (data) => {
            this.hideBackupModal();
            this.showToast('✅ Záloha úspěšně vytvořena', 'success');
        });
        
        this.socket.on('backup-error', (data) => {
            this.hideBackupModal();
            this.showToast(`❌ Chyba: ${data.error}`, 'error');
        });
        
        this.socket.on('switch-completed', (data) => {
            this.showToast(`✅ ${data.message}`, 'success');
        });
        
        this.socket.on('switch-error', (data) => {
            this.showToast(`❌ ${data.error}`, 'error');
        });
    }

    setupEventListeners() {
        // Rychlé akce
        document.getElementById('quickBackup').addEventListener('click', () => {
            this.createBackup();
        });
        
        document.getElementById('refreshAll').addEventListener('click', () => {
            this.refreshAll();
        });
        
        // Vytvoření zálohy
        document.getElementById('createBackupBtn').addEventListener('click', () => {
            this.createBackup();
        });
        
        // Generování changelogu
        document.getElementById('generateChangelogBtn').addEventListener('click', () => {
            this.generateChangelog();
        });
        
        // Nastavení
        document.getElementById('saveSettings').addEventListener('click', () => {
            this.saveSettings();
        });
        
        document.getElementById('resetSettings').addEventListener('click', () => {
            this.resetSettings();
        });
        
        // Restart serveru
        document.getElementById('restartServer').addEventListener('click', () => {
            this.restartServer();
        });
        
        // Modální okno
        document.querySelectorAll('.modal-close').forEach(btn => {
            btn.addEventListener('click', () => {
                this.hideBackupModal();
            });
        });
        
        // Klávesové zkratky
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'b') {
                e.preventDefault();
                this.createBackup();
            }
            if (e.ctrlKey && e.key === 'r') {
                e.preventDefault();
                this.refreshAll();
            }
            if (e.key === 'Escape') {
                this.hideBackupModal();
            }
        });
    }

    setupViewSwitching() {
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const view = e.currentTarget.dataset.view;
                this.switchView(view);
            });
        });
    }

    switchView(viewName) {
        // Skrýt všechny pohledy
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        
        // Zobrazit vybraný pohled
        document.getElementById(`${viewName}View`).classList.add('active');
        
        // Aktualizovat aktivní tlačítko v navigaci
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.classList.remove('active');
            if (btn.dataset.view === viewName) {
                btn.classList.add('active');
            }
        });
        
        this.currentView = viewName;
        
        // Načíst data pro daný pohled
        switch(viewName) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'backups':
                this.loadBackupsData();
                break;
            case 'versions':
                this.loadVersionsData();
                break;
            case 'changelog':
                this.loadChangelogData();
                break;
        }
    }

    async loadInitialData() {
        try {
            // Načíst status
            const statusResponse = await fetch('/api/status');
            this.status = await statusResponse.json();
            this.updateStatusDisplay();
            
            // Načíst verze
            const versionsResponse = await fetch('/api/versions');
            this.versions = await versionsResponse.json();
            this.updateVersionsList();
            this.updateRecentBackups();
            this.updateVersionSelects();
            
            // Načíst restore points
            const restoreResponse = await fetch('/api/restore-points');
            this.restorePoints = await restoreResponse.json();
            
        } catch (error) {
            console.error('Chyba při načítání dat:', error);
            this.showToast('❌ Chyba při načítání dat', 'error');
        }
    }

    updateStatus(status) {
        this.status = status;
        this.updateStatusDisplay();
        this.updateLastRefresh();
    }

    updateStatusDisplay() {
        // Aktualizovat dashboard
        document.getElementById('currentVersion').textContent = this.status.currentVersion;
        document.getElementById('totalBackups').textContent = this.status.totalBackups;
        document.getElementById('diskUsage').textContent = this.status.diskUsage?.split(/\s+/)[2] || 'N/A';
        document.getElementById('memoryUsage').textContent = this.status.memory || 'N/A';
        document.getElementById('platformInfo').textContent = this.status.platform || 'N/A';
        document.getElementById('lastUpdate').textContent = new Date(this.status.timestamp).toLocaleString('cs-CZ');
        
        // Aktualizovat stav serveru
        const serverStatus = document.getElementById('serverStatus');
        if (this.socket.connected) {
            serverStatus.innerHTML = '<i class="fas fa-circle"></i> Online';
            serverStatus.className = 'status-badge online';
        } else {
            serverStatus.innerHTML = '<i class="fas fa-circle"></i> Offline';
            serverStatus.className = 'status-badge offline';
        }
    }

    updateVersionsList() {
        const tableBody = document.getElementById('backupsTableBody');
        const versionCards = document.getElementById('versionCards');
        
        if (this.versions.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="5" class="empty-cell">
                        <i class="fas fa-inbox"></i>
                        Žádné zálohy
                    </td>
                </tr>
            `;
            
            versionCards.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-inbox"></i>
                    <p>Žádné dostupné verze</p>
                </div>
            `;
            return;
        }
        
        // Tabulka záloh
        tableBody.innerHTML = this.versions.map(version => `
            <tr>
                <td>
                    <div class="version-name-cell">
                        <i class="fas fa-${version.format === 'zip' ? 'file-archive' : 'file-alt'}"></i>
                        <span>${version.displayName}</span>
                    </div>
                </td>
                <td>
                    <span class="version-badge badge-${version.type}">
                        ${version.type === 'stable' ? 'Stable' : 'Beta'}
                    </span>
                </td>
                <td>${version.size}</td>
                <td>${new Date(version.created).toLocaleString('cs-CZ')}</td>
                <td>
                    <div class="table-actions">
                        <button class="btn-small btn-primary" onclick="app.switchToVersion('${version.displayName}')">
                            <i class="fas fa-play"></i> Přepnout
                        </button>
                        <button class="btn-small btn-secondary" onclick="app.downloadBackup('${version.name}')">
                            <i class="fas fa-download"></i> Stáhnout
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');
        
        // Karty verzí
        versionCards.innerHTML = this.versions.map(version => `
            <div class="version-card ${version.type}">
                <div class="version-header">
                    <div class="version-name">${version.displayName}</div>
                    <span class="version-badge badge-${version.type}">
                        ${version.type === 'stable' ? 'Stable' : 'Beta'}
                    </span>
                </div>
                
                <div class="version-info">
                    <div class="version-info-item">
                        <i class="fas fa-hdd"></i>
                        <span>Velikost: ${version.size}</span>
                    </div>
                    <div class="version-info-item">
                        <i class="fas fa-calendar"></i>
                        <span>Vytvořeno: ${new Date(version.created).toLocaleDateString('cs-CZ')}</span>
                    </div>
                    <div class="version-info-item">
                        <i class="fas fa-file-${version.format === 'zip' ? 'archive' : 'alt'}"></i>
                        <span>Formát: ${version.format}</span>
                    </div>
                </div>
                
                <div class="version-actions">
                    <button class="btn-small btn-primary" onclick="app.switchToVersion('${version.displayName}')">
                        <i class="fas fa-play"></i> Aktivovat
                    </button>
                    <button class="btn-small btn-secondary" onclick="app.downloadBackup('${version.name}')">
                        <i class="fas fa-download"></i> Stáhnout
                    </button>
                    <button class="btn-small btn-danger" onclick="app.deleteBackup('${version.name}')">
                        <i class="fas fa-trash"></i> Smazat
                    </button>
                </div>
            </div>
        `).join('');
    }

    updateRecentBackups() {
        const recentBackups = document.getElementById('recentBackups');
        const recent = this.versions.slice(0, 3);
        
        if (recent.length === 0) {
            recentBackups.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-inbox"></i>
                    <p>Žádné nedávné zálohy</p>
                </div>
            `;
            return;
        }
        
        recentBackups.innerHTML = recent.map(version => `
            <div class="backup-item">
                <div class="backup-item-header">
                    <i class="fas fa-${version.format === 'zip' ? 'file-archive' : 'file-alt'}"></i>
                    <span class="backup-name">${version.displayName}</span>
                    <span class="backup-badge badge-${version.type}">${version.type}</span>
                </div>
                <div class="backup-item-info">
                    <span>${version.size}</span>
                    <span>•</span>
                    <span>${new Date(version.created).toLocaleDateString('cs-CZ')}</span>
                </div>
            </div>
        `).join('');
    }

    updateVersionSelects() {
        const versionFrom = document.getElementById('versionFrom');
        const versionTo = document.getElementById('versionTo');
        
        versionFrom.innerHTML = '<option value="">Vyberte první verzi</option>';
        versionTo.innerHTML = '<option value="">Vyberte druhou verzi</option>';
        
        this.versions.forEach(version => {
            const option1 = document.createElement('option');
            option1.value = version.displayName;
            option1.textContent = version.displayName;
            
            const option2 = document.createElement('option');
            option2.value = version.displayName;
            option2.textContent = version.displayName;
            
            versionFrom.appendChild(option1.cloneNode(true));
            versionTo.appendChild(option2.cloneNode(true));
        });
    }

    updateConnectionStatus(connected) {
        const indicator = document.getElementById('statusIndicator');
        const connectionStatus = document.getElementById('connectionStatus');
        
        if (connected) {
            indicator.innerHTML = '<i class="fas fa-circle"></i><span>Online</span>';
            indicator.style.color = '#28a745';
            connectionStatus.innerHTML = '<i class="fas fa-wifi"></i> Připojeno';
        } else {
            indicator.innerHTML = '<i class="fas fa-circle"></i><span>Offline</span>';
            indicator.style.color = '#dc3545';
            connectionStatus.innerHTML = '<i class="fas fa-wifi-slash"></i> Odpojeno';
        }
    }

    updateLastRefresh() {
        const lastRefresh = document.getElementById('lastRefresh');
        lastRefresh.textContent = `Naposledy aktualizováno: ${new Date().toLocaleTimeString('cs-CZ')}`;
    }

    async createBackup() {
        const nameInput = document.getElementById('backupName');
        const backupType = document.querySelector('input[name="backupType"]:checked');
        
        const name = nameInput.value.trim() || `backup_${new Date().toISOString().slice(0, 10)}`;
        const type = backupType ? backupType.value : 'stable';
        
        try {
            const response = await fetch('/api/backup', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ name, type })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showToast(`✅ Záloha "${name}" vytvořena`, 'success');
                nameInput.value = '';
                this.socket.emit('get-status');
            } else {
                this.showToast(`❌ Chyba: ${result.error}`, 'error');
            }
        } catch (error) {
            this.showToast(`❌ Chyba při vytváření zálohy: ${error.message}`, 'error');
        }
    }

    async switchToVersion(versionName) {
        if (!confirm(`Opravdu chcete přepnout na verzi "${versionName}"?`)) {
            return;
        }
        
        try {
            const response = await fetch('/api/switch', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ version: versionName })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showToast(`✅ Přepnuto na verzi: ${versionName}`, 'success');
                this.socket.emit('get-status');
            } else {
                this.showToast(`❌ Chyba: ${result.error}`, 'error');
            }
        } catch (error) {
            this.showToast(`❌ Chyba při přepínání: ${error.message}`, 'error');
        }
    }

    async generateChangelog() {
        const versionFrom = document.getElementById('versionFrom').value;
        const versionTo = document.getElementById('versionTo').value;
        
        if (!versionFrom || !versionTo) {
            this.showToast('❌ Vyberte obě verze pro porovnání', 'warning');
            return;
        }
        
        if (versionFrom === versionTo) {
            this.showToast('❌ Vyberte různé verze', 'warning');
            return;
        }
        
        try {
            const response = await fetch(`/api/changelog/${encodeURIComponent(versionFrom)}/${encodeURIComponent(versionTo)}`);
            const changelog = await response.json();
            
            const output = document.getElementById('changelogOutput');
            output.innerHTML = `
                <div class="changelog-header">
                    <h4><i class="fas fa-code-compare"></i> Porovnání verzí</h4>
                    <div class="changelog-versions">
                        <span class="version-from">${changelog.version1}</span>
                        <i class="fas fa-arrow-right"></i>
                        <span class="version-to">${changelog.version2}</span>
                    </div>
                </div>
                <div class="changelog-content">
                    <h5>Změny:</h5>
                    <ul>
                        ${changelog.changes.map(change => `<li><i class="fas fa-check-circle"></i> ${change}</li>`).join('')}
                    </ul>
                </div>
                <div class="changelog-footer">
                    <small>Vygenerováno: ${new Date(changelog.timestamp).toLocaleString('cs-CZ')}</small>
                </div>
            `;
            
            this.showToast('✅ Changelog vygenerován', 'success');
        } catch (error) {
            this.showToast(`❌ Chyba při generování: ${error.message}`, 'error');
        }
    }

    async downloadBackup(filename) {
        try {
            const response = await fetch(`/backups/${encodeURIComponent(filename)}`);
            if (response.ok) {
                const blob = await response.blob();
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = filename;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
                this.showToast('✅ Stahování zahájeno', 'success');
            } else {
                throw new Error('Soubor nenalezen');
            }
        } catch (error) {
            this.showToast(`❌ Chyba při stahování: ${error.message}`, 'error');
        }
    }

    async deleteBackup(filename) {
        if (!confirm(`Opravdu chcete smazat zálohu "${filename}"? Tato akce je nevratná.`)) {
            return;
        }
        
        try {
            const response = await fetch(`/api/backup/${encodeURIComponent(filename)}`, {
                method: 'DELETE'
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showToast('✅ Záloha smazána', 'success');
                this.socket.emit('get-status');
            } else {
                this.showToast(`❌ Chyba: ${result.error}`, 'error');
            }
        } catch (error) {
            this.showToast(`❌ Chyba při mazání: ${error.message}`, 'error');
        }
    }

    showBackupModal(message) {
        const modal = document.getElementById('backupModal');
        const logOutput = document.getElementById('backupLog');
        
        modal.classList.add('active');
        logOutput.innerHTML = `<div class="log-entry">${message}</div>`;
        
        // Simulace postupu
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 10;
            if (progress > 100) progress = 100;
            
            document.getElementById('backupProgress').style.width = `${progress}%`;
            document.getElementById('backupProgressText').textContent = `${Math.round(progress)}%`;
            
            if (progress >= 100) {
                clearInterval(interval);
            }
        }, 300);
    }

    hideBackupModal() {
        const modal = document.getElementById('backupModal');
        modal.classList.remove('active');
    }

    showToast(message, type = 'info') {
        const toastContainer = document.getElementById('toastContainer');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
            <span>${message}</span>
        `;
        
        toastContainer.appendChild(toast);
        
        // Automatické odstranění
        setTimeout(() => {
            toast.style.animation = 'slideOut 0.3s ease forwards';
            setTimeout(() => {
                toastContainer.removeChild(toast);
            }, 300);
        }, 3000);
    }

    refreshAll() {
        this.socket.emit('get-status');
        this.showToast('🔄 Aktualizuji data...', 'info');
    }

    saveSettings() {
        // Zde by se ukládala nastavení
        this.showToast('✅ Nastavení uloženo', 'success');
    }

    resetSettings() {
        if (confirm('Opravdu chcete obnovit výchozí nastavení?')) {
            // Reset nastavení
            this.showToast('✅ Nastavení obnoveno', 'success');
        }
    }

    restartServer() {
        if (confirm('Opravdu chcete restartovat server? Bude chvíli nedostupný.')) {
            this.showToast('🔄 Restartuji server...', 'warning');
            // Zde by se volal API endpoint pro restart
        }
    }

    loadDashboardData() {
        // Načíst data specifická pro dashboard
        this.socket.emit('get-status');
    }

    loadBackupsData() {
        // Načíst data specifická pro zálohy
        // Již máme data z WebSocket
    }

    loadVersionsData() {
        // Načíst data specifická pro verze
        // Již máme data z WebSocket
    }

    loadChangelogData() {
        // Načíst data specifická pro changelog
        // Již máme data z WebSocket
    }
}

// Inicializace aplikace
const app = new VersionManagerGUI();

// Zpřístupnění globálně pro inline onclick
window.app = app;

// CSS pro animace
const style = document.createElement('style');
style.textContent = `
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    
    .empty-cell {
        text-align: center;
        padding: 2rem;
        color: #6c757d;
    }
    
    .empty-cell i {
        font-size: 2rem;
        margin-bottom: 1rem;
        display: block;
        opacity: 0.5;
    }
    
    .version-name-cell {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .table-actions {
        display: flex;
        gap: 0.5rem;
    }
    
    .btn-danger {
        background: var(--danger-color);
        color: white;
    }
    
    .btn-danger:hover {
        background: #e1156a;
    }
    
    .backup-item {
        background: white;
        padding: 1rem;
        border-radius: var(--border-radius);
        margin-bottom: 0.5rem;
        border-left: 3px solid var(--primary-color);
    }
    
    .backup-item-header {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 0.5rem;
    }
    
    .backup-name {
        font-weight: 600;
        flex: 1;
    }
    
    .backup-item-info {
        display: flex;
        gap: 0.5rem;
        color: var(--gray-color);
        font-size: 0.9rem;
    }
    
    .changelog-header {
        background: white;
        padding: 1rem;
        border-radius: var(--border-radius) var(--border-radius) 0 0;
        border-bottom: 1px solid #e9ecef;
    }
    
    .changelog-versions {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 1rem;
        margin: 1rem 0;
        font-size: 1.1rem;
    }
    
    .version-from, .version-to {
        padding: 0.5rem 1rem;
        background: #f8f9fa;
        border-radius: var(--border-radius);
        font-weight: 600;
    }
    
    .changelog-content {
        background: white;
        padding: 1rem;
    }
    
    .changelog-content ul {
        list-style: none;
        padding: 0;
    }
    
    .changelog-content li {
        padding: 0.5rem 0;
        border-bottom: 1px solid #f8f9fa;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .changelog-footer {
        background: #f8f9fa;
        padding: 1rem;
        border-radius: 0 0 var(--border-radius) var(--border-radius);
        text-align: center;
        color: var(--gray-color);
    }
`;
document.head.appendChild(style);
