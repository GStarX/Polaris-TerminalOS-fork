#!/data/data/com.termux/files/usr/bin/bash
# TerminalOS supervisor: 单实例守护 1panel / 语音 web / worker / 录音 agent，工作时段内才录音
export HOME=/data/data/com.termux/files/home
P=/data/data/com.termux/files/usr
export PATH=$P/bin:/system/bin
export LD_LIBRARY_PATH=$P/lib
unset LD_PRELOAD
R=$HOME/ubuntu-26.04
L=$R/opt/terminalos/logs
LOCKD=$P/tmp/tos_supervisor.lock
CONF=$HOME/tos_supervisor.conf
INTERVAL=10
WORK_START=9
WORK_END=19
[ -f "$CONF" ] && . "$CONF"

mkdir -p "$L"
if ! mkdir "$LOCKD" 2>/dev/null; then
  old=$(cat "$LOCKD/pid" 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    echo "supervisor already running pid=$old"; exit 0
  fi
  rm -rf "$LOCKD"; mkdir "$LOCKD" 2>/dev/null || exit 0
fi
echo $$ > "$LOCKD/pid"
trap 'rm -rf "$LOCKD"' EXIT INT TERM

say() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$L/supervisor.log"; }
up()  { $P/bin/curl -s -m 2 -o /dev/null "http://127.0.0.1:$1/" 2>/dev/null; }
rot() {
  f=$1
  [ -f "$f" ] || return 0
  sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
  [ "$sz" -gt 5242880 ] && mv -f "$f" "$f.1"
  return 0
}
run_in() {
  wd=$1; shift
  $P/bin/proot -0 -r "$R" -b /dev -b /proc -b /sys -b "$HOME" -w "$wd" \
    /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TMPDIR=/tmp \
    "$@"
}

say "supervisor START pid=$$ work=$WORK_START-$WORK_END interval=${INTERVAL}s"
i=0
while :; do
  i=$((i+1))
  # 1Panel
  if ! up 10086; then
    say "restart 1panel"; rot "$L/1panel.log"
    run_in /opt/1panel /usr/local/bin/1panel >> "$L/1panel.log" 2>&1 &
  fi
  # 语音 web 后台
  if ! up 8081; then
    say "restart web"; rot "$L/web.log"
    run_in /root /usr/bin/python3 /opt/terminalos/web/server.py >> "$L/web.log" 2>&1 &
  fi
  # 识别 worker
  if ! pgrep -f "python3 /opt/terminalos/worker.py" >/dev/null 2>&1; then
    say "restart worker"; rot "$L/worker.log"
    run_in /root /usr/bin/python3 /opt/terminalos/worker.py >> "$L/worker.log" 2>&1 &
  fi
  # 录音 agent：只在工作时段
  hour=$(date +%H); hour=$((10#$hour))
  if [ "$hour" -ge "$WORK_START" ] && [ "$hour" -lt "$WORK_END" ]; then
    if ! pgrep -f "tos_agent.sh" >/dev/null 2>&1; then
      say "start agent"; rot "$L/agent.log"
      rm -rf "$P/tmp/agent.lock"
      ( nohup sh "$HOME/tos_agent.sh" >> "$L/agent.log" 2>&1 & )
    fi
  else
    if pgrep -f "tos_agent.sh" >/dev/null 2>&1; then
      say "stop agent (off-hours $hour)"; pkill -f "tos_agent.sh" 2>/dev/null
    fi
  fi
  [ $((i % 30)) -eq 0 ] && say "heartbeat" \
    "$(pgrep -fc 'tos_agent.sh' 2>/dev/null || echo 0)agent" \
    "$(up 8081 && echo web-up || echo web-down)" \
    "$(up 10086 && echo panel-up || echo panel-down)"
  sleep "$INTERVAL"
done
