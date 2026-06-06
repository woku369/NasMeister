#!/bin/sh
# PM2 Setup – einmalig per SSH auf der Synology ausführen
# Danach: pm2 list  zeigt alle Apps
#         pm2 startup / pm2 save  für Autostart nach Reboot

NODE=/var/packages/Node.js_v20/target/usr/local/bin/node
NPM=/var/packages/Node.js_v20/target/usr/local/bin/npm
BASE=/volume1/Gurktaler

echo "=== PM2 installieren ==="
$NPM install -g pm2

PM2=/usr/local/bin/pm2

echo ""
echo "=== Apps registrieren ==="

$PM2 start $BASE/zeiterfassung/backend/server.js \
  --name zeiterfassung \
  --env PORT=3000 \
  --env API_KEY=ZE-Gurktaler-2026 \
  --env DATA_DIR=$BASE/zeiterfassung/backend/data

$PM2 start $BASE/TerminMeister/server.js \
  --name TerminMeister \
  --env PORT=3001 \
  --env API_KEY=TM-Gurktaler-2026

$PM2 start $BASE/GartenMeister/server.js \
  --name GartenMeister \
  --env PORT=3002 \
  --env API_KEY=GM-Gurktaler-2026

$PM2 start $BASE/Gurktaler-2.0/server.js \
  --name Gurktaler-2.0 \
  --env PORT=3003 \
  --env API_KEY=G2-Gurktaler-2026

$PM2 start $BASE/LagerMeister/server.js \
  --name LagerMeister \
  --env PORT=3004 \
  --env API_KEY=LM-Gurktaler-2026

$PM2 start $BASE/MazerationsMeister/server.js \
  --name MazerationsMeister \
  --env PORT=3005 \
  --env API_KEY=MM-Gurktaler-2026

$PM2 start $BASE/Huf-Macherin/server.js \
  --name Huf-Macherin \
  --env PORT=3006 \
  --env API_KEY=HM-Gurktaler-2026

$PM2 start $BASE/nasmeister/server.js \
  --name nasmeister \
  --env PORT=4000 \
  --env API_KEY=NM-Gurktaler-2026 \
  --env PM2_BIN=/usr/local/bin/pm2

echo ""
echo "=== Autostart einrichten ==="
$PM2 startup
$PM2 save

echo ""
echo "=== Status ==="
$PM2 list

echo ""
echo "WICHTIG: Den pm2 startup Befehl aus der Ausgabe oben als root ausführen!"
echo "DSM Task Scheduler Einträge können danach gelöscht werden."
