#!/bin/sh
# NasMeister – Synology Task Scheduler Script
# Systemsteuerung → Aufgabenplaner → Erstellen → Benutzerdefiniertes Skript
# Aufgabentyp: Beim Systemstart ausführen

sleep 60

NODE=/var/packages/Node.js_v20/target/usr/local/bin/node
PM2=/usr/local/bin/pm2
APP_DIR=/volume1/Gurktaler/nasmeister
LOG=$APP_DIR/server.log

export API_KEY="NM-Gurktaler-2026"
export PORT=4000
export PM2_BIN=$PM2

cd $APP_DIR
$NODE server.js >> $LOG 2>&1 &

echo "NasMeister gestartet (PID $!)" >> $LOG
