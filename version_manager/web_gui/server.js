class MDInstallerApp {
    constructor() {
        this.socket = null;
        this.currentPage = 'dashboard';
        this.user = null;
        this.token = localStorage.getItem('md_installer_token');
        this.config = {
            theme: localStorage.getItem('theme') || 'dark',
            notifications: true,
            autoRefresh: true,
            refreshInterval: 30000
        };
        
        this.init();
    }
    
    async init() {
        // Načíst konfiguraci
        this.loadConfig();
        
        // Nastavit motiv
        this.setTheme(this.config.theme);
        
        // Inicializovat UI
        this.initUI();
        
        // Připojit se k WebSocket
        this.connectWebSocket();
        
        // Načíst uživatele
        await this.loadUser();
        
        // Načíst aktuální stránku
        this.loadPage(this.currentPage);
        
        // Spustit auto refresh
        if (this.config.autoRefresh) {
            this.startAutoRefresh();
        }
        
        // Aktualizovat čas
        this.updateClock();
        setInterval(() => this.updateClock(), 1000);
    }
    
    initUI() {
        // Breadcrumb navigace
        this.setupBreadcrumb();
        
        // Rychlé akce
        document.getElementById('quick-backup')?.addEventListener('click', () => this.createBackup());
        document.getElementById('refresh-all')?.addEventListener('click', () => this.refreshAll());
        document.getElementById('system-check')?.addEventListener('click', () => this.runSystemCheck());
        
        // Navigace
        document.querySelectorAll('[data-page]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const page = e.target.closest('[data-page]').dataset.page;
                this.loadPage(page);
            });
        });
        
        // Tlačítko pro přepnutí motivu
        document.getElementById('theme-toggle')?.addEventListener('click', () => {
            this.toggleTheme();
        });
        
        // Odhlášení
        document.getElementById('logout-btn')?.addEventListener('click', () => {
            this.logout();
        });
        
        // Notifikace
        this.initNotifications();
    }
    
    async loadUser() {
        if (!this.token) {
            // Přesměrovat na login, pokud není token
            this.loadPage('login');
            return;
        }
        
        try {
            const response = await fetch('/api/auth/verify', {
                headers: {
                    'Authorization': `Bearer ${this.token}`
                }
            });
            
            if (response.ok) {
                const userData = await response.json();
                this.user = userData;
                this.updateUserUI();
            } else {
                // Neplatný token - smazat a přesměrovat na login
                localStorage.removeItem('md_installer_token');
                this.token = null;
                this.loadPage('login');
            }
        } catch (error) {
            console.error('Chyba při načítání uživatele:', error);
            this.showNotification('Chyba připojení k serveru', 'error');
        }
    }
    
    updateUserUI() {
        if (this.user) {
            const usernameEl = document.getElementById('username');
            if (usernameEl) {
                usernameEl.textContent = this.user.username || 'Uživatel';
            }
        }
    }
    
    connectWebSocket() {
        this.socket = io();
        
        this.socket.on('connect', () => {
            this.updateConnectionStatus(true);
            this.showNotification('Připojeno k serveru', 'success');
            
            // Autentizovat přes WebSocket
            if (this.token) {
                this.socket.emit('authenticate', this.token);
            }
        });
        
        this.socket.on('auth_success', (data) => {
            console.log('WebSocket autentizace úspěšná:', data);
            this.socket.emit('subscribe', 'monitoring');
            this.socket.emit('subscribe', 'backups');
            this.socket.emit('subscribe', 'notifications');
        });
        
        this.socket.on('auth_error', (data) => {
            console.error('WebSocket autentizace selhala:', data);
        });
        
        this.socket.on('system_metrics', (metrics) => {
            this.updateSystemMetrics(metrics);
        });
        
        this.socket.on('backup_update', (backups) => {
            this.updateBackupInfo(backups);
        });
        
        this.socket.on('plugin_event', (data) => {
            this.handlePluginEvent(data);
        });
        
        this.socket.on('notification', (notification) => {
            this.addNotification(notification);
        });
        
        this.socket.on('disconnect', () => {
            this.updateConnectionStatus(false);
            this.showNotification('Odpojeno od serveru', 'error');
        });
    }
    
    async loadPage(pageName) {
        this.currentPage = pageName;
        
        // Aktualizovat breadcrumb
        this.updateBreadcrumb(pageName);
        
        // Aktualizovat aktivní odkaz v navigaci
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[data-page="${pageName}"]`)?.classList.add('active');
        
        // Načíst obsah stránky
        try {
            const response = await fetch(`/pages/${pageName}.html`);
            
            if (!response.ok) {
                throw new Error(`Stránka ${pageName} nenalezena`);
            }
            
            const html = await response.text();
            document.getElementById('page-content').innerHTML = html;
            
            // Načíst JavaScript pro stránku
            await this.loadPageScript(pageName);
            
            // Inicializovat stránku
            if (window[`${pageName}Page`]) {
                window[`${pageName}Page`].init(this);
            }
            
            // Scroll na začátek
            window.scrollTo(0, 0);
            
        } catch (error) {
            console.error('Chyba při načítání stránky:', error);
            document.getElementById('page-content').innerHTML = `
                <div class="alert alert-danger">
                    <h4><i class="fas fa-exclamation-triangle"></i> Chyba</h4>
                    <p>Stránku nelze načíst: ${error.message}</p>
                    <button class="btn btn-primary mt-2" onclick="app.loadPage('dashboard')">
                        <i class="fas fa-home"></i> Zpět na dashboard
                    </button>
                </div>
            `;
        }
    }
    
    async loadPageScript(pageName) {
        // Odstranit staré scripty
        const oldScripts = document.querySelectorAll(`script[data-page="${pageName}"]`);
        oldScripts.forEach(script => script.remove());
        
        try {
            // Načíst nový script
            const script = document.createElement('script');
            script.src = `/js/pages/${pageName}.js`;
            script.setAttribute('data-page', pageName);
            script.async = true;
            
            await new Promise((resolve, reject) => {
                script.onload = resolve;
                script.onerror = reject;
                document.body.appendChild(script);
            });
            
        } catch (error) {
            console.warn(`Script pro stránku ${pageName} nelze načíst:`, error);
        }
    }
    
    updateSystemMetrics(metrics) {
        // Aktualizovat progress bary
        const cpuPercent = parseFloat(metrics.cpu.usage[0]) || 0;
        const ramPercent = parseFloat(metrics.memory.percentage) || 0;
        const diskPercent = parseFloat(metrics.disk.percentage) || 0;
        
        document.getElementById('cpu-bar').style.width = `${cpuPercent}%`;
        document.getElementById('cpu-text').textContent = `${cpuPercent.toFixed(1)}%`;
        
        document.getElementById('ram-bar').style.width = `${ramPercent}%`;
        document.getElementById('ram-text').textContent = `${ramPercent.toFixed(1)}%`;
        
        document.getElementById('disk-bar').style.width = `${diskPercent}%`;
        document.getElementById('disk-text').textContent = `${diskPercent.toFixed(1)}%`;
        
        // Aktualizovat informace
        document.getElementById('system-hostname').textContent = metrics.platform || 'N/A';
        
        const uptime = this.formatUptime(metrics.uptime);
        document.getElementById('system-uptime').textContent = uptime;
        
        // Barvy podle vytížení
        this.updateProgressColor('cpu-bar', cpuPercent);
        this.updateProgressColor('ram-bar', ramPercent);
        this.updateProgressColor('disk-bar', diskPercent);
    }
    
    updateProgressColor(elementId, percent) {
        const element = document.getElementById(elementId);
        if (!element) return;
        
        if (percent > 80) {
            element.className = 'progress-bar bg-danger';
        } else if (percent > 60) {
            element.className = 'progress-bar bg-warning';
        } else if (percent > 40) {
            element.className = 'progress-bar bg-info';
        } else {
            element.className = 'progress-bar bg-success';
        }
    }
    
    updateBackupInfo(backups) {
        document.getElementById('backup-count').textContent = backups.count || 0;
    }
    
    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('connection-status');
        const serverStatus = document.getElementById('server-status');
        
        if (connected) {
            statusElement.textContent = 'Online';
            statusElement.className = 'badge bg-success';
            serverStatus.textContent = 'Connected';
        } else {
            statusElement.textContent = 'Offline';
            statusElement.className = 'badge bg-danger';
            serverStatus.textContent = 'Disconnected';
        }
    }
    
    updateClock() {
        const now = new Date();
        const timeString = now.toLocaleTimeString('cs-CZ');
        document.getElementById('current-time').textContent = timeString;
    }
    
    formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        
        if (days > 0) {
            return `${days}d ${hours}h`;
        } else if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else {
            return `${minutes}m`;
        }
    }
    
    setupBreadcrumb() {
        const breadcrumb = document.getElementById('breadcrumb');
        if (!breadcrumb) return;
        
        // Základní breadcrumb
        breadcrumb.innerHTML = `
            <li class="breadcrumb-item"><a href="#dashboard" data-page="dashboard">Dashboard</a></li>
        `;
    }
    
    updateBreadcrumb(pageName) {
        const breadcrumb = document.getElementById('breadcrumb');
        if (!breadcrumb) return;
        
        const pageTitles = {
            'dashboard': 'Dashboard',
            'backups': 'Zálohy',
            'plugins': 'Pluginy',
            'monitoring': 'Monitoring',
            'settings': 'Nastavení',
            'api': 'API Dokumentace',
            'logs': 'Logy',
            'profile': 'Profil',
            'login': 'Přihlášení'
        };
        
        const title = pageTitles[pageName] || pageName;
        
        // Pokud už breadcrumb obsahuje tuto stránku, odstranit vše za ní
        const items = Array.from(breadcrumb.querySelectorAll('.breadcrumb-item'));
        const existingIndex = items.findIndex(item => 
            item.textContent.trim() === title || 
            item.querySelector(`[data-page="${pageName}"]`)
        );
        
        if (existingIndex !== -1) {
            items.slice(existingIndex + 1).forEach(item => item.remove());
        } else {
            // Přidat novou položku
            const newItem = document.createElement('li');
            newItem.className = 'breadcrumb-item active';
            newItem.setAttribute('aria-current', 'page');
            newItem.innerHTML = `<a href="#${pageName}" data-page="${pageName}">${title}</a>`;
            breadcrumb.appendChild(newItem);
        }
    }
    
    setTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('theme', theme);
        
        // Aktualizovat ikonu tlačítka
        const themeIcon = document.querySelector('#theme-toggle i');
        if (themeIcon) {
            themeIcon.className = theme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
        }
    }
    
    toggleTheme() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        this.setTheme(newTheme);
    }
    
    loadConfig() {
        const savedConfig = localStorage.getItem('md_installer_config');
        if (savedConfig) {
            try {
                this.config = { ...this.config, ...JSON.parse(savedConfig) };
            } catch (error) {
                console.error('Chyba při načítání konfigurace:', error);
            }
        }
    }
    
    saveConfig() {
        localStorage.setItem('md_installer_config', JSON.stringify(this.config));
    }
    
    async createBackup() {
        try {
            const response = await fetch('/api/backups', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    name: `manual_${new Date().toISOString().slice(0, 19)}`,
                    type: 'manual'
                })
            });
            
            if (response.ok) {
                this.showNotification('Záloha vytvořena', 'success');
                this.refreshAll();
            } else {
                throw new Error('Chyba při vytváření zálohy');
            }
        } catch (error) {
            this.showNotification(`Chyba: ${error.message}`, 'error');
        }
    }
    
    refreshAll() {
        // Znovu načíst aktuální stránku
        this.loadPage(this.currentPage);
        
        // Požádat o aktualizaci metrik
        if (this.socket?.connected) {
            this.socket.emit('get_status');
        }
        
        this.showNotification('Data obnovena', 'info');
    }
    
    async runSystemCheck() {
        try {
            const response = await fetch('/api/system/check', {
                headers: {
                    'Authorization': `Bearer ${this.token}`
                }
            });
            
            const result = await response.json();
            
            if (response.ok) {
                this.showNotification('Kontrola systému dokončena', 'success');
                
                // Zobrazit výsledky
                this.showModal('Kontrola systému', `
                    <div class="system-check-results">
                        <h5>Výsledky kontroly:</h5>
                        <ul class="list-group">
                            ${result.checks?.map(check => `
                                <li class="list-group-item d-flex justify-content-between align-items-center">
                                    ${check.name}
                                    <span class="badge ${check.status === 'OK' ? 'bg-success' : 'bg-danger'}">
                                        ${check.status}
                                    </span>
                                </li>
                            `).join('') || '<li class="list-group-item">Žádné výsledky</li>'}
                        </ul>
                    </div>
                `);
            } else {
                throw new Error(result.error || 'Chyba při kontrole systému');
            }
        } catch (error) {
            this.showNotification(`Chyba: ${error.message}`, 'error');
        }
    }
    
    initNotifications() {
        // Inicializace systému notifikací
        window.notificationSystem = {
            notifications: [],
            add: (notification) => {
                this.addNotification(notification);
            },
            clear: () => {
                this.clearNotifications();
            }
        };
    }
    
    addNotification(notification) {
        const notifications = JSON.parse(localStorage.getItem('md_notifications') || '[]');
        notifications.push({
            ...notification,
            id: Date.now(),
            read: false,
            timestamp: new Date().toISOString()
        });
        
        localStorage.setItem('md_notifications', JSON.stringify(notifications));
        this.updateNotificationBadge();
        
        // Zobrazit toast notifikaci
        this.showToastNotification(notification);
    }
    
    showToastNotification(notification) {
        const toastContainer = document.getElementById('toast-container') || this.createToastContainer();
        
        const toastId = `toast-${Date.now()}`;
        const toast = document.createElement('div');
        toast.className = `toast align-items-center border-0 ${this.getNotificationClass(notification.type)}`;
        toast.id = toastId;
        toast.setAttribute('role', 'alert');
        toast.setAttribute('aria-live', 'assertive');
        toast.setAttribute('aria-atomic', 'true');
        
        toast.innerHTML = `
            <div class="d-flex">
                <div class="toast-body">
                    <i class="${this.getNotificationIcon(notification.type)} me-2"></i>
                    ${notification.message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
            </div>
        `;
        
        toastContainer.appendChild(toast);
        
        const bsToast = new bootstrap.Toast(toast, {
            autohide: true,
            delay: 5000
        });
        
        bsToast.show();
        
        toast.addEventListener('hidden.bs.toast', () => {
            toast.remove();
        });
    }
    
    getNotificationClass(type) {
        const classes = {
            'success': 'bg-success text-white',
            'error': 'bg-danger text-white',
            'warning': 'bg-warning text-dark',
            'info': 'bg-info text-white'
        };
        
        return classes[type] || 'bg-primary text-white';
    }
    
    getNotificationIcon(type) {
        const icons = {
            'success': 'fas fa-check-circle',
            'error': 'fas fa-exclamation-circle',
            'warning': 'fas fa-exclamation-triangle',
            'info': 'fas fa-info-circle'
        };
        
        return icons[type] || 'fas fa-bell';
    }
    
    updateNotificationBadge() {
        const notifications = JSON.parse(localStorage.getItem('md_notifications') || '[]');
        const unreadCount = notifications.filter(n => !n.read).length;
        
        const badge = document.getElementById('notification-count');
        if (badge) {
            if (unreadCount > 0) {
                badge.textContent = unreadCount;
                badge.classList.remove('d-none');
            } else {
                badge.classList.add('d-none');
            }
        }
    }
    
    clearNotifications() {
        localStorage.setItem('md_notifications', '[]');
        this.updateNotificationBadge();
        
        const notificationsList = document.getElementById('notifications-list');
        if (notificationsList) {
            notificationsList.innerHTML = `
                <div class="text-center py-3">
                    <i class="fas fa-bell-slash fa-2x text-muted"></i>
                    <p class="mt-2">Žádné notifikace</p>
                </div>
            `;
        }
    }
    
    createToastContainer() {
        const container = document.createElement('div');
        container.id = 'toast-container';
        container.className = 'toast-container position-fixed top-0 end-0 p-3';
        container.style.zIndex = '9999';
        document.body.appendChild(container);
        return container;
    }
    
    showModal(title, content) {
        // Odstranit existující modaly
        const existingModal = document.getElementById('app-modal');
        if (existingModal) {
            existingModal.remove();
        }
        
        const modal = document.createElement('div');
        modal.id = 'app-modal';
        modal.className = 'modal fade';
        modal.tabIndex = -1;
        modal.innerHTML = `
            <div class="modal-dialog modal-dialog-centered">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">${title}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        ${content}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Zavřít</button>
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        
        const bsModal = new bootstrap.Modal(modal);
        bsModal.show();
        
        modal.addEventListener('hidden.bs.modal', () => {
            modal.remove();
        });
    }
    
    showNotification(message, type = 'info') {
        this.addNotification({
            message,
            type,
            title: type.charAt(0).toUpperCase() + type.slice(1)
        });
    }
    
    handlePluginEvent(data) {
        console.log('Plugin event:', data);
        
        // Zde může aplikace reagovat na plugin events
        switch (data.plugin) {
            case 'auto_backup':
                this.showNotification(`Auto Backup: ${data.action}`, 'info');
                break;
            case 'system_monitor':
                if (data.action === 'alert') {
                    this.showNotification(`System Monitor: ${data.data.message}`, 'warning');
                }
                break;
        }
    }
    
    startAutoRefresh() {
        setInterval(() => {
            if (this.config.autoRefresh && this.socket?.connected) {
                this.socket.emit('get_status');
            }
        }, this.config.refreshInterval);
    }
    
    logout() {
        localStorage.removeItem('md_installer_token');
        this.token = null;
        this.user = null;
        
        if (this.socket) {
            this.socket.disconnect();
        }
        
        this.loadPage('login');
    }
}

// Inicializace aplikace
let app;

document.addEventListener('DOMContentLoaded', () => {
    app = new MDInstallerApp();
    window.app = app;
});

// Globální helper funkce
function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('cs-CZ');
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}
