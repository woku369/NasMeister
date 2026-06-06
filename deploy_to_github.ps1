# NasMeister – Deploy-Script für Windows
# Legt alle Projektdateien an und pusht zu GitHub.
# Ausführen: Rechtsklick → "Mit PowerShell ausführen"
# Voraussetzung: Git installiert, GitHub-Account angemeldet

$targetDir = "C:\Users\wolfg\Desktop\NasMeister"
$repoUrl   = "https://github.com/woku369/NasMeister.git"

Write-Host "=== NasMeister Setup ===" -ForegroundColor Cyan

# Zielverzeichnis anlegen
if (Test-Path $targetDir) {
    Write-Host "Verzeichnis existiert bereits: $targetDir" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
    Write-Host "Verzeichnis erstellt: $targetDir" -ForegroundColor Green
}

Set-Location $targetDir

# ── .gitignore ─────────────────────────────────────────────────────────────
@"
node_modules/
server.log
*.log
"@ | Set-Content ".gitignore" -Encoding UTF8

# ── package.json ────────────────────────────────────────────────────────────
@"
{
  "name": "nasmeister",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
"@ | Set-Content "package.json" -Encoding UTF8

# ── config.json ─────────────────────────────────────────────────────────────
@"
{
  "apps": [
    { "name": "zeiterfassung",     "port": 3000, "dir": "/volume1/Gurktaler/zeiterfassung/backend", "startScript": "server.js", "healthPath": "/api/health", "color": "#1565C0" },
    { "name": "TerminMeister",     "port": 3001, "dir": "/volume1/Gurktaler/TerminMeister",         "startScript": "server.js", "healthPath": "/api/health", "color": "#2E7D32" },
    { "name": "GartenMeister",     "port": 3002, "dir": "/volume1/Gurktaler/GartenMeister",         "startScript": "server.js", "healthPath": "/api/health", "color": "#388E3C" },
    { "name": "Gurktaler-2.0",     "port": 3003, "dir": "/volume1/Gurktaler/Gurktaler-2.0",         "startScript": "server.js", "healthPath": "/api/health", "color": "#6A1B9A" },
    { "name": "LagerMeister",      "port": 3004, "dir": "/volume1/Gurktaler/LagerMeister",          "startScript": "server.js", "healthPath": "/api/health", "color": "#E65100" },
    { "name": "MazerationsMeister","port": 3005, "dir": "/volume1/Gurktaler/MazerationsMeister",    "startScript": "server.js", "healthPath": "/api/health", "color": "#795548" },
    { "name": "Huf-Macherin",      "port": 3006, "dir": "/volume1/Gurktaler/Huf-Macherin",          "startScript": "server.js", "healthPath": "/api/health", "color": "#00838F" }
  ]
}
"@ | Set-Content "config.json" -Encoding UTF8

# ── server.js ───────────────────────────────────────────────────────────────
@'
const express = require('express');
const http    = require('http');
const path    = require('path');
const fs      = require('fs');
const { exec } = require('child_process');

const PORT    = process.env.PORT    || 4000;
const API_KEY = process.env.API_KEY || null;
const PM2     = process.env.PM2_BIN || '/usr/local/bin/pm2';
const CONFIG  = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.use('/api', (req, res, next) => {
  if (API_KEY && req.headers['x-api-key'] !== API_KEY)
    return res.status(401).json({ error: 'Unauthorized' });
  next();
});

function pm2List() {
  return new Promise((resolve, reject) => {
    exec(`${PM2} jlist`, (err, stdout) => {
      if (err) return reject(err);
      try { resolve(JSON.parse(stdout)); } catch (e) { reject(e); }
    });
  });
}

function pm2Action(action, name) {
  return new Promise((resolve, reject) => {
    exec(`${PM2} ${action} ${name}`, (err, stdout, stderr) => {
      if (err) return reject(new Error(stderr || err.message));
      resolve(stdout);
    });
  });
}

function healthCheck(appCfg) {
  return new Promise((resolve) => {
    const req = http.request(
      { hostname: '127.0.0.1', port: appCfg.port, path: appCfg.healthPath || '/api/health', method: 'GET', timeout: 3000 },
      (res) => resolve(res.statusCode === 200 ? 'healthy' : 'unhealthy')
    );
    req.on('error', () => resolve('unreachable'));
    req.on('timeout', () => { req.destroy(); resolve('timeout'); });
    req.end();
  });
}

app.get('/api/status', async (req, res) => {
  try {
    const [pm2Procs, healthResults] = await Promise.all([
      pm2List(),
      Promise.all(CONFIG.apps.map(a => healthCheck(a))),
    ]);
    const apps = CONFIG.apps.map((cfg, i) => {
      const proc      = pm2Procs.find(p => p.name === cfg.name);
      const pm2Status = proc ? proc.pm2_env.status : 'not_registered';
      const health    = healthResults[i];
      let status;
      if      (pm2Status === 'online'  && health === 'healthy') status = 'online';
      else if (pm2Status === 'online'  && health !== 'healthy') status = 'degraded';
      else if (pm2Status === 'stopped')                         status = 'stopped';
      else if (pm2Status === 'errored')                         status = 'errored';
      else                                                       status = 'unknown';
      return { name: cfg.name, port: cfg.port, color: cfg.color, status, pm2: pm2Status, health,
               cpu: proc?.monit?.cpu ?? null, memory: proc?.monit?.memory ?? null,
               uptime: proc?.pm2_env?.pm_uptime ?? null, restarts: proc?.pm2_env?.restart_time ?? null };
    });
    res.json({ apps, timestamp: new Date().toISOString() });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/apps/:name/restart', async (req, res) => {
  if (!CONFIG.apps.find(a => a.name === req.params.name)) return res.status(404).json({ error: 'App nicht gefunden' });
  try { await pm2Action('restart', req.params.name); res.json({ success: true, action: 'restart', name: req.params.name }); }
  catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/apps/:name/stop', async (req, res) => {
  if (!CONFIG.apps.find(a => a.name === req.params.name)) return res.status(404).json({ error: 'App nicht gefunden' });
  try { await pm2Action('stop', req.params.name); res.json({ success: true, action: 'stop', name: req.params.name }); }
  catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/apps/:name/start', async (req, res) => {
  if (!CONFIG.apps.find(a => a.name === req.params.name)) return res.status(404).json({ error: 'App nicht gefunden' });
  try { await pm2Action('start', req.params.name); res.json({ success: true, action: 'start', name: req.params.name }); }
  catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/nas/reboot', (req, res) => {
  if (req.body?.confirm !== true) return res.status(400).json({ error: 'confirm: true erforderlich' });
  res.json({ success: true, message: 'NAS startet neu...' });
  setTimeout(() => { exec('sudo reboot'); }, 1500);
});

app.get('/api/config', (req, res) => {
  res.json({ apps: CONFIG.apps.map(({ name, port, color }) => ({ name, port, color })) });
});

app.listen(PORT, () => console.log(`NasMeister laeuft auf http://localhost:${PORT}`));
'@ | Set-Content "server.js" -Encoding UTF8

# ── start_synology.sh ───────────────────────────────────────────────────────
@"
#!/bin/sh
sleep 60
NODE=/var/packages/Node.js_v20/target/usr/local/bin/node
APP_DIR=/volume1/Gurktaler/nasmeister
LOG=`$APP_DIR/server.log
export API_KEY="NM-Gurktaler-2026"
export PORT=4000
export PM2_BIN=/usr/local/bin/pm2
cd `$APP_DIR
`$NODE server.js >> `$LOG 2>&1 &
echo "NasMeister gestartet (PID `$!)" >> `$LOG
"@ | Set-Content "start_synology.sh" -Encoding UTF8

# ── pm2-setup.sh ────────────────────────────────────────────────────────────
@"
#!/bin/sh
NODE=/var/packages/Node.js_v20/target/usr/local/bin/node
NPM=/var/packages/Node.js_v20/target/usr/local/bin/npm
BASE=/volume1/Gurktaler
echo "=== PM2 installieren ==="
`$NPM install -g pm2
PM2=/usr/local/bin/pm2
echo "=== Apps registrieren ==="
`$PM2 start `$BASE/zeiterfassung/backend/server.js --name zeiterfassung --env PORT=3000 --env API_KEY=ZE-Gurktaler-2026 --env DATA_DIR=`$BASE/zeiterfassung/backend/data
`$PM2 start `$BASE/TerminMeister/server.js       --name TerminMeister     --env PORT=3001 --env API_KEY=TM-Gurktaler-2026
`$PM2 start `$BASE/GartenMeister/server.js       --name GartenMeister     --env PORT=3002 --env API_KEY=GM-Gurktaler-2026
`$PM2 start `$BASE/Gurktaler-2.0/server.js       --name Gurktaler-2.0     --env PORT=3003 --env API_KEY=G2-Gurktaler-2026
`$PM2 start `$BASE/LagerMeister/server.js        --name LagerMeister      --env PORT=3004 --env API_KEY=LM-Gurktaler-2026
`$PM2 start `$BASE/MazerationsMeister/server.js  --name MazerationsMeister --env PORT=3005 --env API_KEY=MM-Gurktaler-2026
`$PM2 start `$BASE/Huf-Macherin/server.js        --name Huf-Macherin      --env PORT=3006 --env API_KEY=HM-Gurktaler-2026
`$PM2 start `$BASE/nasmeister/server.js          --name nasmeister        --env PORT=4000 --env API_KEY=NM-Gurktaler-2026 --env PM2_BIN=/usr/local/bin/pm2
echo "=== Autostart einrichten ==="
`$PM2 startup
`$PM2 save
echo "=== Status ==="
`$PM2 list
echo "WICHTIG: Den pm2 startup Befehl als root ausfuehren!"
"@ | Set-Content "pm2-setup.sh" -Encoding UTF8

# ── public/ ─────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path "public" -Force | Out-Null

# manifest.json
@"
{
  "name": "NasMeister",
  "short_name": "NasMeister",
  "description": "NAS Server Monitor & Control",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#121212",
  "theme_color": "#1E1E2E",
  "orientation": "portrait",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
"@ | Set-Content "public\manifest.json" -Encoding UTF8

# sw.js
@"
const CACHE = 'nasmeister-v1';
const ASSETS = ['/', '/app.js', '/style.css', '/manifest.json'];
self.addEventListener('install', e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS))));
self.addEventListener('fetch', e => {
  if (e.request.url.includes('/api/')) return;
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});
"@ | Set-Content "public\sw.js" -Encoding UTF8

Write-Host "Dateien erstellt. Starte Git-Setup..." -ForegroundColor Cyan

# Git initialisieren und pushen
git init
git branch -M main
git remote add origin $repoUrl
git add -A
git commit -m "init: NasMeister v1.0 - NAS Monitor & Control PWA"
git push -u origin main

Write-Host ""
Write-Host "=== FERTIG ===" -ForegroundColor Green
Write-Host "NasMeister ist jetzt auf GitHub: $repoUrl" -ForegroundColor Green
Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor Yellow
Write-Host "1. index.html und app.js und style.css noch in public\ anlegen (siehe Claude Chat)"
Write-Host "2. NasMeister-Ordner per git clone / scp auf die NAS kopieren"
Write-Host "3. SSH auf NAS: bash /volume1/Gurktaler/nasmeister/pm2-setup.sh"
