/**
 * NasMeister – Control API
 * Überwacht und steuert alle Node.js-Apps auf der Synology NAS via PM2.
 * Start: node server.js
 *
 * Umgebungsvariablen (optional):
 *   PORT     HTTP-Port (default: 4000)
 *   API_KEY  Auth-Key für alle /api/-Routen
 *   PM2_BIN  Pfad zur pm2-Binary (default: /usr/local/bin/pm2)
 */

const express  = require('express');
const http     = require('http');
const path     = require('path');
const fs       = require('fs');
const { exec, execSync } = require('child_process');

const PORT    = process.env.PORT    || 4000;
const API_KEY = process.env.API_KEY || null;
const PM2     = process.env.PM2_BIN || '/usr/local/bin/pm2';
const CONFIG  = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── Auth ──────────────────────────────────────────────────────────────────────

app.use('/api', (req, res, next) => {
  if (API_KEY && req.headers['x-api-key'] !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function pm2List() {
  return new Promise((resolve, reject) => {
    exec(`${PM2} jlist`, (err, stdout) => {
      if (err) return reject(err);
      try { resolve(JSON.parse(stdout)); }
      catch (e) { reject(e); }
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
    const options = {
      hostname: '127.0.0.1',
      port: appCfg.port,
      path: appCfg.healthPath || '/api/health',
      method: 'GET',
      timeout: 3000,
    };
    const req = http.request(options, (res) => {
      resolve(res.statusCode === 200 ? 'healthy' : 'unhealthy');
    });
    req.on('error', () => resolve('unreachable'));
    req.on('timeout', () => { req.destroy(); resolve('timeout'); });
    req.end();
  });
}

// ── API ───────────────────────────────────────────────────────────────────────

// GET /api/status – alle Apps mit PM2-Status + HTTP-Healthcheck
app.get('/api/status', async (req, res) => {
  try {
    const [pm2Procs, healthResults] = await Promise.all([
      pm2List(),
      Promise.all(CONFIG.apps.map(a => healthCheck(a))),
    ]);

    const apps = CONFIG.apps.map((cfg, i) => {
      const proc = pm2Procs.find(p => p.name === cfg.name);
      const pm2Status = proc ? proc.pm2_env.status : 'not_registered';
      const health    = healthResults[i];

      let status;
      if (pm2Status === 'online' && health === 'healthy')    status = 'online';
      else if (pm2Status === 'online' && health !== 'healthy') status = 'degraded';
      else if (pm2Status === 'stopped')                        status = 'stopped';
      else if (pm2Status === 'errored')                        status = 'errored';
      else                                                      status = 'unknown';

      return {
        name:     cfg.name,
        port:     cfg.port,
        color:    cfg.color,
        status,
        pm2:      pm2Status,
        health,
        cpu:      proc?.monit?.cpu    ?? null,
        memory:   proc?.monit?.memory ?? null,
        uptime:   proc?.pm2_env?.pm_uptime ?? null,
        restarts: proc?.pm2_env?.restart_time ?? null,
      };
    });

    res.json({ apps, timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/apps/:name/restart
app.post('/api/apps/:name/restart', async (req, res) => {
  const { name } = req.params;
  if (!CONFIG.apps.find(a => a.name === name))
    return res.status(404).json({ error: 'App nicht gefunden' });
  try {
    await pm2Action('restart', name);
    res.json({ success: true, action: 'restart', name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/apps/:name/stop
app.post('/api/apps/:name/stop', async (req, res) => {
  const { name } = req.params;
  if (!CONFIG.apps.find(a => a.name === name))
    return res.status(404).json({ error: 'App nicht gefunden' });
  try {
    await pm2Action('stop', name);
    res.json({ success: true, action: 'stop', name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/apps/:name/start
app.post('/api/apps/:name/start', async (req, res) => {
  const { name } = req.params;
  if (!CONFIG.apps.find(a => a.name === name))
    return res.status(404).json({ error: 'App nicht gefunden' });
  try {
    await pm2Action('start', name);
    res.json({ success: true, action: 'start', name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/nas/reboot – NAS Neustart (mit Bestätigung im Frontend)
app.post('/api/nas/reboot', (req, res) => {
  if (req.body?.confirm !== true)
    return res.status(400).json({ error: 'confirm: true erforderlich' });
  res.json({ success: true, message: 'NAS startet neu...' });
  setTimeout(() => { exec('sudo reboot'); }, 1500);
});

// GET /api/config – App-Liste für Frontend
app.get('/api/config', (req, res) => {
  res.json({ apps: CONFIG.apps.map(({ name, port, color }) => ({ name, port, color })) });
});

app.listen(PORT, () =>
  console.log(`NasMeister läuft auf http://localhost:${PORT}`)
);
