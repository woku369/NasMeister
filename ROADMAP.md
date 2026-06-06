# NasMeister – Roadmap

> Automatisch gepflegt via `/roadmap`. Manuell aktualisieren nach größeren Änderungen.
> Letztes Update: 2026-06-05 – v1.0 Grundgerüst

---

## Projekt-Übersicht

Zentrales Monitoring- und Steuerungs-Cockpit für alle Node.js-Server-Instanzen
auf der Synology DS124 NAS. Ersetzt das manuelle SSH-Terminal-Chaos beim
Killen und Neustarten von Next.js/Node.js-Apps.

**Stack:** Node.js + Express (Control API) · Vanilla JS PWA (Frontend) · PM2 (Prozessmanager)

**Hardware:**
| Gerät | Einsatz |
|---|---|
| Synology DS124 | NAS – läuft alle Server-Prozesse |
| Xiaomi Poco X7 Pro | Android – primärer NasMeister-Client |
| Homeoffice-PC / Surface | Windows – Browser-Zugriff |

**Verwaltete Apps:**
| Name | Port | Technologie |
|---|---|---|
| zeiterfassung | 3000 | Node.js (standalone) |
| TerminMeister | 3001 | Node.js |
| GartenMeister | 3002 | TypeScript/Next.js |
| Gurktaler-2.0 | 3003 | TypeScript/Next.js |
| LagerMeister | 3004 | TypeScript |
| MazerationsMeister | 3005 | TypeScript/Next.js |
| Huf-Macherin | 3006 | TypeScript |
| NasMeister (selbst) | 4000 | Node.js (standalone) |

---

## Erledigt

### v1.0 – Grundgerüst
- [x] **Control API** (`server.js`, Port 4000):
  - `GET  /api/status` – PM2-Prozessliste + HTTP-Healthcheck aller Apps parallel
  - `POST /api/apps/:name/restart` – PM2 restart
  - `POST /api/apps/:name/stop`    – PM2 stop
  - `POST /api/apps/:name/start`   – PM2 start
  - `POST /api/nas/reboot`         – NAS Neustart (mit `confirm: true` Guard)
  - `GET  /api/config`             – App-Liste für Frontend
  - Optionale API-Key-Authentifizierung via `x-api-key`-Header
- [x] **PWA Frontend** (`public/`):
  - Dark Theme, responsive (Mobile-first)
  - App-Karten mit Ampel-Statuslampe (grün/gelb/rot/grau)
  - Status: `online` · `degraded` · `stopped` · `errored` · `unknown`
  - CPU%, RAM, Uptime, Restart-Zähler je App
  - Start / Stop / Restart Buttons (kontextsensitiv deaktiviert)
  - Summary-Bar (Gesamtüberblick auf einen Blick)
  - NAS-Neustart-Button mit Bestätigungs-Modal
  - Auto-Refresh alle 15 Sekunden
  - Toast-Benachrichtigungen für Aktionen
  - Installierbar als PWA (manifest.json + Service Worker)
- [x] **Konfiguration** (`config.json`): App-Liste editierbar ohne Code-Änderung
- [x] **PM2-Setup-Script** (`pm2-setup.sh`): Einmaliges SSH-Script für alle Apps
- [x] **Synology-Start-Script** (`start_synology.sh`): DSM Task Scheduler Integration
- [x] **Roadmap** (diese Datei)

---

## Offen / In Arbeit

### Kurzfristig – PM2 Migration & Stabilisierung

- [ ] **PM2 auf NAS installieren** (einmalig via SSH):
  - `npm install -g pm2`
  - Alle 7 Apps + NasMeister via `pm2-setup.sh` registrieren
  - `pm2 startup` + `pm2 save` → DSM Task Scheduler Einträge können danach entfernt werden
  - NAS-Pfade in `config.json` und `pm2-setup.sh` an tatsächliche Verzeichnisstruktur anpassen

- [ ] **Health-Endpunkte prüfen und ergänzen:**
  - zeiterfassung: `/api/health` ✓ vorhanden
  - TerminMeister: prüfen / ergänzen
  - GartenMeister: prüfen / ergänzen
  - Gurktaler-2.0: prüfen / ergänzen
  - LagerMeister: prüfen / ergänzen
  - MazerationsMeister: prüfen / ergänzen
  - Huf-Macherin: prüfen / ergänzen
  - Standard-Snippet bereitstellen (copy-paste in jedes `server.js`)

- [ ] **NAS-Pfade verifizieren:**
  - Tatsächliche Verzeichnisstruktur auf der DS124 prüfen
  - `config.json` und `pm2-setup.sh` aktualisieren

- [ ] **Handbuch-Tab** in der PWA:
  - Sidetab / separater Screen mit Dokumentation
  - Abschnitte: PM2-Grundlagen, NAS-Zugriff, Apps verwalten, Troubleshooting
  - Code-Blöcke mit Copy-Tap (wie in zeiterfassung-Handbuch)

- [ ] **App als PWA auf Android installieren und testen:**
  - Browser öffnen → `http://<tailscale-ip>:4000`
  - „Zum Startbildschirm hinzufügen"
  - Grundfunktionen verifizieren (Ampeln, Restart, Stop)

### Kurzfristig – UX

- [ ] **Log-Viewer** (PM2 Logs je App):
  - `GET /api/apps/:name/logs?lines=50` → letzte N Zeilen aus PM2-Log
  - Modal oder eigener Screen mit scrollbarem Log
  - Automatisches Scrollen zum Ende

- [ ] **App-Icons / Farben konfigurierbar** in `config.json`:
  - Farbe je App bereits implementiert (`color`-Feld)
  - Emoji/Icon-Feld ergänzen

- [ ] **Verbindungsstatus-Indikator:**
  - Wenn NAS nicht erreichbar → Banner „NAS offline / Tailscale prüfen"
  - Unterschied: NasMeister-API nicht erreichbar vs. einzelne App down

### Mittelfristig – Erweiterungen

- [ ] **Push-Benachrichtigungen (Web Push):**
  - Wenn App von `online` → `errored` oder `stopped` wechselt → Notification auf Android
  - Erfordert VAPID-Keys + Browser-Permission
  - Alternativ: IFTTT-Webhook oder ntfy.sh

- [ ] **Restart-on-Error Protokoll:**
  - PM2 macht automatisch restart bei Absturz → NasMeister zeigt Restart-Historie
  - Wann ist welche App wie oft abgestürzt?

- [ ] **Git-Pull + Restart** (Deploy-Button):
  - `POST /api/apps/:name/deploy` → `git pull` im App-Verzeichnis + `pm2 restart`
  - Ermöglicht Ein-Klick-Deploy direkt aus NasMeister

- [ ] **Mehrere NAS / Remote-Instanzen:**
  - NasMeister als zentrales Dashboard für mehrere Server
  - Konfigurierbare Endpunkte in `config.json`

### Langfristig / Ideen

- [ ] **Automatischer `/api/health`-Endpunkt** in allen Meister-Apps via shared NPM-Paket
- [ ] **Uptime-History** (Sparkline je App – letzten 24h)
- [ ] **CPU/RAM-Graphen** (Zeitverlauf, nicht nur Momentaufnahme)
- [ ] **Dependency-Map:** zeigt welche Apps voneinander abhängen (z. B. zeiterfassung nutzt TerminMeister)
- [ ] **APK via PWABuilder** generieren (nach stabiler PWA-Version)

---

## Architektur-Notizen

```
nasmeister/
├── server.js           Control API + Static File Server (Port 4000)
├── package.json        Abhängigkeit: express
├── config.json         App-Liste (Name, Port, Pfad, Health-URL, Farbe) – editierbar
├── start_synology.sh   Synology DSM Task Scheduler Startskript
├── pm2-setup.sh        Einmaliges PM2-Installationsscript (SSH)
├── ROADMAP.md          Diese Datei
└── public/
    ├── index.html      Single-Page PWA
    ├── app.js          Frontend-Logik (Vanilla JS)
    ├── style.css       Dark Theme, CSS Custom Properties
    ├── manifest.json   PWA-Manifest (installierbar auf Android)
    └── sw.js           Service Worker (Offline-Cache für App-Shell)
```

**Status-Logik:**
```
PM2: online  + Health: 200    → status: "online"   🟢
PM2: online  + Health: ≠200   → status: "degraded" 🟡
PM2: stopped                  → status: "stopped"  🔴
PM2: errored                  → status: "errored"  🔴
App nicht in PM2 registriert  → status: "unknown"  ⚫
```

**API-Key Authentifizierung:**
- Kein Key konfiguriert → API offen (nur im lokalen Tailscale-Netz betreiben!)
- Key via Env-Variable `API_KEY` setzen
- Frontend speichert Key in `localStorage` (Prompt beim ersten 401)

**PM2-Pfad:**
- Standard: `/usr/local/bin/pm2`
- Synology: ggf. `/var/packages/Node.js_v20/target/usr/local/bin/pm2`
- Überschreibbar via Env-Variable `PM2_BIN`

---

## Bekannte Einschränkungen

| Thema | Details |
|---|---|
| PM2 noch nicht installiert | Einmalige SSH-Session erforderlich (`pm2-setup.sh`) |
| NAS-Pfade noch zu verifizieren | `config.json` enthält Annahmen – anpassen nötig |
| Health-Endpunkte fehlen | Ältere Apps (GartenMeister, MazerationsMeister) haben noch kein `/api/health` → Status bleibt `degraded` bis ergänzt |
| NAS-Reboot benötigt sudo | `sudo reboot` in `server.js` – auf Synology ggf. Berechtigungen konfigurieren |
| Kein HTTPS | Nur über Tailscale nutzbar (verschlüsseltes VPN-Tunnel) – kein öffentlicher Zugriff |
| Service Worker Cache | Bei Updates: einmal hard refresh im Browser (Strg+Shift+R) nötig |
