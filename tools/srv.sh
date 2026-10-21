#!/bin/bash
# Headless control for the server (dev or prod): srv.sh start|stop|status|cmd "<console command>"|log [n]|restartall
set -euo pipefail
# Lives in the repo at [vana]/tools/, i.e. <server>/mods/deathmatch/resources/[vana]/tools/.
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SRV="$(cd "$HERE/../../../../.." && pwd)"
RUN="$SRV/.run"
FIFO="$RUN/console.fifo"
PIDF="$RUN/server.pid"
OUT="$RUN/console.log"
mkdir -p "$RUN"

running() { [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

case "${1:-}" in
    start)
        running && { echo "already running (pid $(cat "$PIDF"))"; exit 0; }
        rm -f "$FIFO"; mkfifo "$FIFO"
        # Holder keeps the FIFO's write end open so the server never sees EOF on stdin.
        (exec 3>"$FIFO"; while [[ -p "$FIFO" ]]; do sleep 60; done) &
        echo $! > "$RUN/holder.pid"
        cd "$SRV"
        # Prod ships a start.sh wrapper that runs the binary under a bundled glibc (Ubuntu 20.04 host).
        launch=./mta-server64; [[ -x start.sh ]] && launch=./start.sh
        nohup "$launch" -n -t -u < "$FIFO" > "$OUT" 2>&1 &
        echo $! > "$PIDF"
        for _ in $(seq 1 30); do
            grep -q "ready to accept connections" "$OUT" 2>/dev/null && { echo "started (pid $(cat "$PIDF"))"; exit 0; }
            running || { echo "server exited during startup:"; tail -20 "$OUT"; exit 1; }
            sleep 0.5
        done
        echo "started, but no ready line yet; see $OUT"
        ;;
    stop)
        if running; then
            echo shutdown > "$FIFO"
            for _ in $(seq 1 20); do running || break; sleep 0.5; done
            running && kill "$(cat "$PIDF")"
        fi
        [[ -f "$RUN/holder.pid" ]] && kill "$(cat "$RUN/holder.pid")" 2>/dev/null || true
        rm -f "$FIFO" "$PIDF" "$RUN/holder.pid"
        echo stopped
        ;;
    status)
        running && echo "running (pid $(cat "$PIDF"))" || echo "not running"
        ;;
    cmd)
        running || { echo "not running"; exit 1; }
        shift
        before=$(wc -l < "$OUT")
        echo "$*" > "$FIFO"
        sleep "${SRV_CMD_WAIT:-1}"
        tail -n +"$((before + 1))" "$OUT"
        ;;
    log)
        tail -n "${2:-40}" "$OUT"
        ;;
    restartall)
        # Every vana resource (not the data maps), in mtaserver.conf's startup order. A joining player's
        # client starts resources in the order the server last started them, so after restarting
        # vana-lib alone its importers would start before it there and fail (docs/libraries.md).
        running || { echo "not running"; exit 1; }
        for res in $(grep -oE 'resource src="vana-[a-z-]+"' "$SRV/mods/deathmatch/mtaserver.conf" | cut -d'"' -f2 | grep -v '^vana-data-'); do
            before=$(wc -l < "$OUT")
            echo "restart $res" > "$FIFO"
            sleep 3
            tail -n +"$((before + 1))" "$OUT" | grep -E "restarted successfully|ERROR|failed" | grep -v "\[client " || true
        done
        ;;
    *)
        echo "usage: $0 start|stop|status|cmd \"<console command>\"|log [n]|restartall"; exit 2
        ;;
esac
