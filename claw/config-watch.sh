#!/bin/bash
# ============================================================================
# config-watch.sh — Cron-based watchdog that auto-restores openclaw.json
# ============================================================================
#
# WHY THIS EXISTS:
#   OpenClaw's startup process rewrites openclaw.json and strips certain
#   custom settings (most notably <trusted partner> number from whatsapp.allowFrom).
#   The entrypoint golden-restore (docker-compose.yml) catches restarts,
#   but this cron catches any OTHER config rewrites (e.g. `openclaw doctor`,
#   wizard runs, or remote updates via the gateway UI).
#
# SCHEDULE: Every 1 minute via cron
#   * * * * * /docker/openclaw-vtmt/config-watch.sh
#
# BEHAVIOR:
#   - If golden copy doesn't exist yet → exits silently (run config-guard.sh first)
#   - If config is intact → does nothing
#   - If drift detected → backs up broken config, restores golden, restarts container
#   - Logs all actions to config-backups/watch.log
# ============================================================================

CONFIG="/docker/openclaw-vtmt/data/.openclaw/openclaw.json"
GOLDEN="/docker/openclaw-vtmt/data/.openclaw/config-backups/openclaw.json.golden"
LOG="/docker/openclaw-vtmt/data/.openclaw/config-backups/watch.log"

# No golden copy yet? Nothing to compare against. Run config-guard.sh first.
[ -f "$GOLDEN" ] || exit 0

# Quick validation: are all 3 agent bindings present?
#   - <yournumber> WhatsApp  → main agent
#   - <Your> Telegram  → main agent
#   - <Trusted person> WhatsApp → shared agent
BINDING_COUNT=$(python3 -c "
import json
cfg = json.load(open('$CONFIG'))
bindings = cfg.get('bindings', [])
checks = [
    any(b.get('agentId')=='main' and b.get('match',{}).get('channel')=='whatsapp' and b.get('match',{}).get('peer',{}).get('id')=='+<yournumber>' for b in bindings),
    any(b.get('agentId')=='main' and b.get('match',{}).get('channel')=='telegram' and b.get('match',{}).get('peer',{}).get('id')=='<yourtelegramid>' for b in bindings),
    any(b.get('agentId')=='shared' and b.get('match',{}).get('channel')=='whatsapp' and b.get('match',{}).get('peer',{}).get('id')=='+<trustedpersonnumber>' for b in bindings),
]
print(sum(checks))
" 2>/dev/null)

# Is <trusted person> number in the WhatsApp allowlist? (This is what OpenClaw keeps stripping)
ALLOW_OK=$(python3 -c "
import json
cfg = json.load(open('$CONFIG'))
allow = cfg.get('channels',{}).get('whatsapp',{}).get('allowFrom',[])
print(1 if '+<trustedperson>' in allow else 0)
" 2>/dev/null)

# If anything is wrong, restore from golden and restart
if [ "$BINDING_COUNT" != "3" ] || [ "$ALLOW_OK" != "1" ]; then
    echo "[$(date)] ⚠️ Config drift detected (bindings=$BINDING_COUNT/3, allowOk=$ALLOW_OK). Restoring golden." >> "$LOG"

    # Save the broken version for forensics
    cp "$CONFIG" "$CONFIG.pre-restore-$(date +%Y%m%d-%H%M%S)"

    # Overwrite with known-good config
    cp "$GOLDEN" "$CONFIG"

    # Restart so OpenClaw re-reads the restored config
    cd /docker/openclaw-vtmt && docker compose restart openclaw >> "$LOG" 2>&1

    echo "[$(date)] ✅ Config restored and container restarted." >> "$LOG"
fi