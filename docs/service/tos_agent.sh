#!/data/data/com.termux/files/usr/bin/bash
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:/system/bin
export LD_LIBRARY_PATH=$PREFIX/lib
LOCK=$PREFIX/tmp/agent.lock
mkdir "$LOCK" 2>/dev/null || { echo "agent already running"; exit 0; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
IN="$HOME/ubuntu-26.04/opt/terminalos/voice/in"
mkdir -p "$IN"
while true; do
  ts=$(date +%Y%m%d-%H%M%S)
  f="$IN/${ts}.m4a"
  termux-microphone-record -f "$f" -l 6 -e aac >/dev/null 2>&1
  sleep 7
  sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
  if [ "$sz" -lt 3000 ]; then rm -f "$f"; fi
  sleep 1
done