#!/bin/sh
# PM2 Setup – einmalig per SSH auf der Synology ausführen
# Voraussetzung: Node.js v20 Package installiert
#
# Ausführen: sh /volume1/Gurktaler/nasmeister/pm2-setup.sh
# Danach:    pm2 list            → alle Apps anzeigen
#            pm2 logs <name>     → Live-Log einer App
#            pm2 startup / pm2 save  → Autostart nach Reboot

NODE=/var/packages/Node.js_v20/target/usr/local/bin/node
NPM=/var/packages/Node.js_v20/target/usr/local/bin/npm
BASE=/volume1/Gurktaler

echo "=== PM2 installieren ==="
$NPM install -g pm2

# PM2-Pfad nach npm global install
PM2=/usr/local/bin/pm2

echo ""
echo "=== Apps registrieren ==="

# zeiterfassung – Port 3000
PORT=3000 API_KEY=ZE-Gurktaler-2026 DATA_DIR=$BASE/zeiterfassung/backend/data \
  $PM2 start $BASE/zeiterfassung/backend/server.js \
  --name zeiterfassung \
  --cwd $BASE/zeiterfassung/backend

# zweipunktnull (Gurktaler 2.0) – Port 3002 (via nginx proxy)
PORT=3002 \
  $PM2 start $BASE/zweipunktnull/server.js \
  --name zweipunktnull \
  --cwd $BASE/zweipunktnull

# gartenmeister – Port 3003 (Startscript liegt in nas/)
PORT=3003 \
  $PM2 start $BASE/gartenmeister/nas/server-gartenmeister.js \
  --name gartenmeister \
  --cwd $BASE/gartenmeister/nas

# terminmeister – Port 3005
PORT=3005 \
  $PM2 start $BASE/terminmeister/server.js \
  --name terminmeister \
  --cwd $BASE/terminmeister

# lagermeister – Port 3006 (nutzt APP_PORT statt PORT)
APP_PORT=3006 APP_BASE=$BASE/lagermeister \
  $PM2 start $BASE/lagermeister/server.js \
  --name lagermeister \
  --cwd $BASE/lagermeister

# nasmeister selbst – Port 4000
PORT=4000 API_KEY=NM-Gurktaler-2026 PM2_BIN=/usr/local/bin/pm2 \
  $PM2 start $BASE/nasmeister/server.js \
  --name nasmeister \
  --cwd $BASE/nasmeister

echo ""
echo "=== Autostart einrichten ==="
$PM2 startup
$PM2 save

echo ""
echo "=== Status ==="
$PM2 list

echo ""
echo "WICHTIG: Den 'pm2 startup' Befehl aus der Ausgabe oben als root ausführen!"
echo "Erst danach sind die Apps nach einem NAS-Neustart automatisch aktiv."
echo "DSM Task Scheduler Einträge können dann schrittweise deaktiviert werden."
