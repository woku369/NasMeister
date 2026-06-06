'use strict';

const API_KEY = localStorage.getItem('nm_api_key') || '';
const REFRESH_INTERVAL = 15000;

let refreshTimer = null;
let isLoading = false;

const headers = () => API_KEY ? { 'x-api-key': API_KEY } : {};

// ── Status helpers ─────────────────────────────────────────────────────────

function lampClass(status) {
  return { online: 'lamp-green', degraded: 'lamp-yellow', stopped: 'lamp-red',
           errored: 'lamp-red', unknown: 'lamp-grey' }[status] ?? 'lamp-grey';
}

function badgeClass(status) {
  return `badge-${status}`;
}

function badgeLabel(status) {
  return { online: '● Online', degraded: '◐ Degraded', stopped: '● Gestoppt',
           errored: '✕ Fehler', unknown: '? Unbekannt' }[status] ?? status;
}

function formatUptime(ms) {
  if (!ms) return '—';
  const s = Math.floor((Date.now() - ms) / 1000);
  if (s < 60)  return `${s}s`;
  if (s < 3600) return `${Math.floor(s/60)}m`;
  return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m`;
}

function formatMem(bytes) {
  if (!bytes) return '—';
  if (bytes < 1024*1024) return `${(bytes/1024).toFixed(0)} KB`;
  return `${(bytes/1024/1024).toFixed(0)} MB`;
}

// ── Card rendering ─────────────────────────────────────────────────────────

function renderCard(app) {
  const isRunning = app.status === 'online' || app.status === 'degraded';
  return `
    <div class="card" data-name="${app.name}">
      <div class="card-accent" style="background:${app.color}"></div>
      <div class="card-body">
        <div class="card-header">
          <div>
            <div class="app-name">${app.name}</div>
            <div class="app-port">Port ${app.port}</div>
          </div>
          <div class="status-lamp ${lampClass(app.status)}"></div>
        </div>

        <div class="status-badge ${badgeClass(app.status)}">${badgeLabel(app.status)}</div>

        <div class="stats">
          <div class="stat">CPU <span>${app.cpu != null ? app.cpu + '%' : '—'}</span></div>
          <div class="stat">RAM <span>${formatMem(app.memory)}</span></div>
          <div class="stat">Up <span>${formatUptime(app.uptime)}</span></div>
          <div class="stat">Restarts <span>${app.restarts ?? '—'}</span></div>
        </div>

        <div class="card-actions">
          <button class="btn btn-restart" onclick="action('${app.name}','restart')" ${!isRunning ? 'disabled' : ''}>
            ↺ Restart
          </button>
          <button class="btn btn-stop" onclick="action('${app.name}','stop')" ${!isRunning ? 'disabled' : ''}>
            ⏹ Stop
          </button>
          <button class="btn btn-start" onclick="action('${app.name}','start')" ${isRunning ? 'disabled' : ''}>
            ▶ Start
          </button>
        </div>
      </div>
    </div>`;
}

// ── Summary bar ────────────────────────────────────────────────────────────

function renderSummary(apps) {
  const counts = { online: 0, degraded: 0, stopped: 0, errored: 0, unknown: 0 };
  apps.forEach(a => { counts[a.status] = (counts[a.status] || 0) + 1; });
  document.getElementById('summary').innerHTML = `
    <div class="summary-item"><span class="dot dot-green"></span>${counts.online} Online</div>
    <div class="summary-item"><span class="dot dot-yellow"></span>${counts.degraded} Degraded</div>
    <div class="summary-item"><span class="dot dot-red"></span>${counts.stopped + counts.errored} Gestoppt/Fehler</div>
    <div class="summary-item"><span class="dot dot-grey"></span>${counts.unknown} Unbekannt</div>`;
}

// ── Data fetching ──────────────────────────────────────────────────────────

async function loadStatus() {
  if (isLoading) return;
  isLoading = true;
  setRefreshBtnSpinning(true);

  try {
    const res = await fetch('/api/status', { headers: headers() });
    if (res.status === 401) { showApiKeyPrompt(); return; }
    const data = await res.json();

    document.getElementById('grid').innerHTML = data.apps.map(renderCard).join('');
    renderSummary(data.apps);

    const ts = new Date(data.timestamp).toLocaleTimeString('de-AT');
    document.getElementById('last-update').textContent = `Aktualisiert: ${ts}`;
  } catch (err) {
    showToast('Verbindungsfehler – NAS erreichbar?', 'error');
  } finally {
    isLoading = false;
    setRefreshBtnSpinning(false);
  }
}

// ── Actions ────────────────────────────────────────────────────────────────

async function action(name, act) {
  const btn = document.querySelector(`[data-name="${name}"] .btn-${act}`);
  if (btn) { btn.disabled = true; btn.textContent = '...'; }

  try {
    const res = await fetch(`/api/apps/${name}/${act}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers() },
    });
    const data = await res.json();
    if (data.error) throw new Error(data.error);
    showToast(`${name}: ${act} ausgeführt`);
    setTimeout(loadStatus, 1500);
  } catch (err) {
    showToast(`Fehler: ${err.message}`, 'error');
    if (btn) { btn.disabled = false; }
    setTimeout(loadStatus, 500);
  }
}

// ── NAS Reboot ─────────────────────────────────────────────────────────────

function showRebootModal() {
  document.getElementById('reboot-modal').classList.add('visible');
}

function hideRebootModal() {
  document.getElementById('reboot-modal').classList.remove('visible');
}

async function confirmReboot() {
  hideRebootModal();
  try {
    const res = await fetch('/api/nas/reboot', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers() },
      body: JSON.stringify({ confirm: true }),
    });
    const data = await res.json();
    showToast(data.message || 'NAS startet neu...');
  } catch (err) {
    showToast(`Fehler: ${err.message}`, 'error');
  }
}

// ── UI helpers ─────────────────────────────────────────────────────────────

function showToast(msg, type = 'info') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.borderColor = type === 'error' ? 'rgba(244,67,54,.4)' : '';
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 3000);
}

function setRefreshBtnSpinning(spin) {
  document.getElementById('refresh-btn').classList.toggle('spinning', spin);
}

function showApiKeyPrompt() {
  const key = prompt('API-Key eingeben:');
  if (key) { localStorage.setItem('nm_api_key', key); location.reload(); }
}

function startAutoRefresh() {
  clearInterval(refreshTimer);
  refreshTimer = setInterval(loadStatus, REFRESH_INTERVAL);
}

// ── Tab navigation ────────────────────────────────────────────────────────

function switchTab(name) {
  document.querySelectorAll('.tab').forEach(t =>
    t.classList.toggle('active', t.dataset.tab === name)
  );
  document.querySelectorAll('.tab-content').forEach(c =>
    c.classList.toggle('active', c.id === `tab-${name}`)
  );
  const refreshBtn = document.getElementById('refresh-btn');
  refreshBtn.style.display = name === 'dashboard' ? '' : 'none';
}

// ── Copy code blocks ──────────────────────────────────────────────────────

function copyCode(el) {
  navigator.clipboard.writeText(el.textContent.trim()).then(() => {
    showToast('Kopiert!');
  }).catch(() => {
    showToast('Kopieren fehlgeschlagen', 'error');
  });
}

// ── Init ───────────────────────────────────────────────────────────────────

document.getElementById('refresh-btn').addEventListener('click', () => {
  loadStatus();
  startAutoRefresh();
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').catch(() => {});
}

loadStatus();
startAutoRefresh();
