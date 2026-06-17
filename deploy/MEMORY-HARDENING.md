# Memory / swap incident — recovery & hardening runbook

## What happened (root cause)

Two compounding failures on the shared 7.6 GB box (`ip-172-31-9-193`, which also
runs MySQL, Apache/Plesk, Docker):

1. **App crash-loop (active outage).** `next build` left no `.next/` (the deploy
   scripts did `rm -rf .next` *before* building, and the build failed — likely
   OOM-killed). The systemd unit then restarted `server.js` every ~5 s forever
   (~6568 times) with: *"Could not find a production build in the '.next'
   directory."* This also generated ~100 MB of crash logs.

2. **Swap exhaustion + OOM cascade (root cause of the original symptom).**
   Elasticsearch had no `-Xms/-Xmx` set, so it auto-sized its heap to ~50 % of
   RAM (~4 GB — confirmed by the OOM kill: `java anon-rss 4.2 GB`). ES (4 GB) +
   `next build` (up to 4 GB) + MySQL/Apache/Plesk exceeded 7.6 GB, overflowed
   into the new swapfile, and a `swapoff` (swap maintenance) forced pages back
   into RAM and OOM-killed ES.

## Fixes in this branch

| File | Change |
|------|--------|
| `deploy/qldazangjingweb.service` | `StartLimit*` (no infinite loop), `MemoryMax=1200M`, `NODE_OPTIONS` heap cap |
| `deploy/elasticsearch-jvm-heap.options` | Pin ES heap to `-Xms1g -Xmx1g` |
| `deploy/elasticsearch-override.conf` | cgroup `MemoryMax=2G` for ES |
| `update.sh`, `deploy.sh` | Keep `.next.bak` fallback; restore it if build fails; build heap 4096 → 1536 |
| `server.js` | Stop dumping full `process.env` (secret leak); write crash blobs once; trim heavy fields |
| `src/app/api/download-pdf/route.ts` | Limit puppeteer/Chromium to 1 concurrent render, 429 when queue full |

## Server steps (run in order)

```bash
cd /var/www/qldazangjingweb
git fetch origin && git checkout fix/server-memory-hardening   # or main after merge

# 0. Reclaim disk first (/dev/root was 93% full from crash logs).
sudo truncate -s 0 logs/crash.log logs/abnormal-exit.log logs/app.log logs/process-exits.log

# 1. Pin + cap Elasticsearch, then bring it back (it's currently failed/oom).
sudo cp deploy/elasticsearch-jvm-heap.options /etc/elasticsearch/jvm.options.d/heap.options
sudo mkdir -p /etc/systemd/system/elasticsearch.service.d
sudo cp deploy/elasticsearch-override.conf /etc/systemd/system/elasticsearch.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl reset-failed elasticsearch
sudo systemctl start elasticsearch
curl -s 'localhost:9200/_cat/nodes?v&h=name,heap.percent,heap.max'   # expect heap.max ~1gb

# 2. Install the hardened app unit.
sudo cp deploy/qldazangjingweb.service /etc/systemd/system/qldazangjingweb.service
sudo systemctl daemon-reload

# 3. Produce a valid build (this stops the crash-loop). Build while ES heap is small.
export PATH="/home/ubuntu/.nvm/versions/node/v20.18.0/bin:$PATH"
CI=true NODE_OPTIONS=--max-old-space-size=1536 npm run build
ls .next/BUILD_ID            # must exist before restarting

# 4. Restart the app and confirm it stays up.
sudo systemctl reset-failed qldazangjingweb
sudo systemctl restart qldazangjingweb
sleep 5 && systemctl is-active qldazangjingweb     # expect: active
sudo systemctl status qldazangjingweb --no-pager | head -15

# 5. Verify memory headroom.
free -h && swapon --show
```

## Follow-ups (not in this branch)

- Add `logrotate` for `/var/www/qldazangjingweb/logs/*.log` (the per-request
  `requests.log` and crash logs grow unbounded).
- Consider a swappiness drop (`vm.swappiness=10`) so the box prefers reclaiming
  cache over swapping ES heap.
- Re-evaluate the ES index cost: `term_vector: with_positions_offsets` + the
  n-gram sub-field on CJK content inflate index size and RAM. Dropping either
  would shrink ES's footprint further.
