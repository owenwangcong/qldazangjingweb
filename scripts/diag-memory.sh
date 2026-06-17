#!/usr/bin/env bash
#
# diag-memory.sh — READ-ONLY diagnostics for the qldazangjingweb Ubuntu box.
#
# Collects memory / swap / Elasticsearch / Node / Chromium / systemd facts so the
# swap-exhaustion root cause can be confirmed. It makes NO changes to the system:
# every command only reads state (ps, free, curl GET, cat, systemctl show/cat,
# journalctl). sudo is used only where a file/log needs elevated read access.
#
# Usage:
#   bash scripts/diag-memory.sh                 # print + save report
#   sudo bash scripts/diag-memory.sh            # same, but no per-command sudo prompts
#
# Output: prints to the terminal AND writes ./diag-memory-<timestamp>.txt
# Send that file back for analysis.

# Deliberately NOT using `set -e`: many probes are expected to fail on some
# boxes (ES down, pm2 absent, etc.) and we want the script to keep going.
set -u

APP_DIR="${APP_DIR:-/var/www/qldazangjingweb}"
SERVICE="${SERVICE:-qldazangjingweb}"
ES_URL="${ELASTICSEARCH_URL:-http://localhost:9200}"
ES_INDEX="${ELASTICSEARCH_INDEX:-buddhist_texts}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$(pwd)/diag-memory-${TS}.txt"

# sudo helper: use sudo only if available and not already root.
if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

# Mirror everything to the output file.
exec > >(tee "$OUT") 2>&1

hr()      { printf '\n========== %s ==========\n' "$*"; }
sub()     { printf '\n----- %s -----\n' "$*"; }
have()    { command -v "$1" >/dev/null 2>&1; }
run()     { echo "\$ $*"; "$@" 2>&1; echo; }            # run + show command
runs()    { echo "\$ $SUDO $*"; $SUDO "$@" 2>&1; echo; } # run with sudo

echo "qldazangjingweb memory/swap diagnostics"
echo "timestamp : $TS"
echo "host      : $(hostname 2>/dev/null)"
echo "app dir   : $APP_DIR"
echo "service   : $SERVICE"
echo "es url    : $ES_URL  (index: $ES_INDEX)"
echo "report    : $OUT"

# ---------------------------------------------------------------------------
hr "1. SYSTEM: RAM, SWAP, KERNEL OOM"
# ---------------------------------------------------------------------------
run uname -a
have lsb_release && run lsb_release -d
sub "memory + swap (human)"
run free -h
sub "swap devices"
run swapon --show
run cat /proc/swaps
sub "swappiness + overcommit (tuning knobs)"
run cat /proc/sys/vm/swappiness
run cat /proc/sys/vm/overcommit_memory
run cat /proc/sys/vm/overcommit_ratio
sub "/proc/meminfo (key lines)"
grep -Ei 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Cached|Buffers|Dirty|Committed_AS|Mapped|Shmem' /proc/meminfo
sub "recent OOM-killer / kill events (dmesg + journal)"
runs dmesg -T --level=err,warn | grep -iE 'oom|kill|out of memory|memory cgroup' | tail -40
runs journalctl -k --no-pager | grep -iE 'oom|out of memory|killed process' | tail -40

# ---------------------------------------------------------------------------
hr "2. TOP CONSUMERS: RSS and ACTUAL SWAP USAGE PER PROCESS"
# ---------------------------------------------------------------------------
sub "top 25 by resident memory (RSS)"
run bash -c "ps -eo pid,ppid,rss,vsz,%mem,comm --sort=-rss | head -26"
sub "per-process swap used (VmSwap from /proc/*/status), top 25"
# This is the key table: which processes are actually IN swap right now.
$SUDO bash -c '
  for f in /proc/[0-9]*/status; do
    pid=$(basename "$(dirname "$f")")
    name=$(awk -F":\t" "/^Name:/{print \$2}" "$f" 2>/dev/null)
    swap=$(awk "/^VmSwap:/{print \$2}" "$f" 2>/dev/null)
    rss=$(awk "/^VmRSS:/{print \$2}" "$f" 2>/dev/null)
    [[ -n "$swap" && "$swap" -gt 0 ]] && printf "%8s kB swap  %8s kB rss  pid=%-7s %s\n" "$swap" "${rss:-0}" "$pid" "$name"
  done | sort -rn | head -25
'
echo
sub "total swap in use, summed across processes"
$SUDO bash -c '
  total=0
  for f in /proc/[0-9]*/status; do
    s=$(awk "/^VmSwap:/{print \$2}" "$f" 2>/dev/null)
    [[ -n "$s" ]] && total=$((total + s))
  done
  echo "sum of per-process VmSwap: $((total/1024)) MB"
'

# ---------------------------------------------------------------------------
hr "3. ELASTICSEARCH (co-located JVM — prime suspect for steady-state RAM)"
# ---------------------------------------------------------------------------
sub "elasticsearch service state + cgroup memory"
runs systemctl status elasticsearch --no-pager -l | head -20
runs systemctl show elasticsearch -p MemoryCurrent -p MemoryMax -p MemoryLimit
sub "configured JVM heap (Xms/Xmx) and memory_lock"
runs bash -c "cat /etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options.d/* 2>/dev/null | grep -iE '^-Xm|Xms|Xmx'"
runs bash -c "grep -iE 'bootstrap.memory_lock|node.name|cluster.name' /etc/elasticsearch/elasticsearch.yml 2>/dev/null"
runs bash -c "cat /proc/\$(pgrep -f 'org.elasticsearch.bootstrap' | head -1)/cmdline 2>/dev/null | tr '\0' ' ' | grep -oE 'Xm[sx][0-9a-zA-Z]+' "
sub "ES runtime JVM heap usage (live)"
run bash -c "curl -s '$ES_URL/_nodes/stats/jvm?human' | grep -ioE '\"heap_used[^,]*|\"heap_max[^,]*|\"heap_used_percent[^,]*' | head"
run bash -c "curl -s '$ES_URL/_cat/nodes?v&h=name,heap.percent,heap.current,heap.max,ram.percent,ram.current,ram.max,cpu,load_1m'"
sub "cluster health (single-node + replicas=1 -> expect yellow)"
run bash -c "curl -s '$ES_URL/_cluster/health?pretty'"
sub "index size, shard count, doc count for $ES_INDEX"
run bash -c "curl -s '$ES_URL/_cat/indices/$ES_INDEX?v&h=health,status,pri,rep,docs.count,docs.deleted,store.size,pri.store.size'"
run bash -c "curl -s '$ES_URL/_cat/shards/$ES_INDEX?v&h=index,shard,prirep,state,docs,store,node,unassigned.reason'"
sub "segment + fielddata memory (off-heap/heap pressure from term_vectors/ngram)"
run bash -c "curl -s '$ES_URL/_cat/segments/$ES_INDEX?v&h=index,shard,segments.memory' | head"
run bash -c "curl -s '$ES_URL/_nodes/stats/indices/fielddata,segments,query_cache,request_cache?human' | tr ',' '\n' | grep -iE 'memory_size|fielddata|segments' | head -20"

# ---------------------------------------------------------------------------
hr "4. NODE / NEXT.JS APP ($SERVICE)"
# ---------------------------------------------------------------------------
sub "systemd unit definition (does it set NODE_ENV=production?)"
runs systemctl cat "$SERVICE"
sub "unit runtime state + memory accounting"
runs systemctl status "$SERVICE" --no-pager -l | head -20
runs systemctl show "$SERVICE" -p MemoryCurrent -p MemoryMax -p Environment -p ExecStart -p MainPID
sub "node processes (RSS) — should be one tree, not a PM2 cluster"
run bash -c "ps -eo pid,ppid,rss,%mem,etime,args --sort=-rss | grep -iE 'node|next' | grep -v grep | head -20"
sub "leftover PM2 cluster? (deployment moved to systemd)"
have pm2 && run pm2 list || echo "pm2 not installed / not on PATH"
have pm2 && run pm2 jlist 2>/dev/null | head -c 2000

# ---------------------------------------------------------------------------
hr "5. CHROMIUM / PUPPETEER (spiky RAM from /api/download-pdf)"
# ---------------------------------------------------------------------------
sub "any chrome/chromium processes right now? (should be 0 at idle)"
run bash -c "ps -eo pid,ppid,rss,%mem,etime,args | grep -iE 'chrome|chromium' | grep -v grep"
run bash -c "echo -n 'chromium process count: '; pgrep -fc 'chrome|chromium' 2>/dev/null || echo 0"
sub "shared memory / tmp pressure (puppeteer uses --disable-dev-shm-usage)"
run df -h /dev/shm /tmp

# ---------------------------------------------------------------------------
hr "6. APP LOGS: memory warnings, crashes, abnormal exits"
# ---------------------------------------------------------------------------
if [[ -d "$APP_DIR/logs" ]]; then
  sub "logs dir size + files"
  run bash -c "du -sh '$APP_DIR/logs' 2>/dev/null; ls -lhS '$APP_DIR/logs' 2>/dev/null | head -20"
  sub "memory warnings (server.js logs heapUsed>500MB)"
  run bash -c "tail -30 '$APP_DIR/logs/memory.log' 2>/dev/null || echo 'no memory.log'"
  sub "recent abnormal exits / crashes"
  run bash -c "tail -40 '$APP_DIR/logs/abnormal-exit.log' 2>/dev/null || echo 'no abnormal-exit.log'"
  run bash -c "tail -20 '$APP_DIR/logs/crash.log' 2>/dev/null || echo 'no crash.log'"
  sub "requests.log size (per-request synchronous appendFileSync)"
  run bash -c "ls -lh '$APP_DIR/logs/requests.log' 2>/dev/null || echo 'no requests.log'"
else
  echo "APP_DIR/logs not found at $APP_DIR/logs"
fi
sub "service journal — restarts, OOM, errors (last 60)"
runs journalctl -u "$SERVICE" --no-pager -n 60

# ---------------------------------------------------------------------------
hr "7. SERVICE RESTART HISTORY (memory-driven restarts?)"
# ---------------------------------------------------------------------------
runs journalctl -u "$SERVICE" --no-pager | grep -iE 'started|stopped|killed|oom|memory|fail' | tail -30

hr "DONE"
echo "Report saved to: $OUT"
echo "Send this file back for analysis."
