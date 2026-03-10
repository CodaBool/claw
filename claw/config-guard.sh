#!/bin/bash
# ============================================================================
# config-guard.sh — Validates openclaw.json has all required custom settings.
# ============================================================================
#
# WHY THIS EXISTS:
#   OpenClaw rewrites openclaw.json on startup, during `openclaw doctor`, and
#   when the wizard runs. Each time, it can silently drop settings it doesn't
#   "own" — particularly:
#     - <Trusted Partners>'s number from channels.whatsapp.allowFrom
#     - Agent bindings (which user → which agent)
#     - Token values (if rotated outside the wizard)
#
#   This script catches those regressions.
#
# USAGE:
#   ./config-guard.sh           # Run manually after any config change
#   Called by config-watch.sh   # Automated via cron (every 1 min)
#
# ON SUCCESS: Saves current config as the "golden" copy (known-good state).
# ON FAILURE: Backs up the broken config and prints restore instructions.
# ============================================================================

CONFIG="/docker/openclaw-vtmt/data/.openclaw/openclaw.json"
BACKUP_DIR="/docker/openclaw-vtmt/data/.openclaw/config-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ERRORS=0

mkdir -p "$BACKUP_DIR"

echo "[config-guard] Checking openclaw.json at $(date)"

# ---------------------------------------------------------------------------
# CHECK 1: User's WhatsApp DMs route to the "main" agent
# ---------------------------------------------------------------------------
# Without this binding, all WhatsApp messages fall through to the "shared"
# (default) agent, which has no access to MEMORY.md, contacts, or private files.
if ! python3 -c "
import json, sys
cfg = json.load(open('$CONFIG'))
found = any(
    b.get('agentId') == 'main' and
    b.get('match', {}).get('channel') == 'whatsapp' and
    b.get('match', {}).get('peer', {}).get('id') == '+1<yournumber>'
    for b in cfg.get('bindings', [])
)
sys.exit(0 if found else 1)
" 2>/dev/null; then
    echo "  ❌ MISSING: WhatsApp +<yournumber> → main binding"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ WhatsApp +<yournumber> → main binding"
fi

# ---------------------------------------------------------------------------
# CHECK 2: User's Telegram DMs route to the "main" agent
# ---------------------------------------------------------------------------
# Same reason as above — Telegram messages also need to hit the main agent.
if ! python3 -c "
import json, sys
cfg = json.load(open('$CONFIG'))
found = any(
    b.get('agentId') == 'main' and
    b.get('match', {}).get('channel') == 'telegram' and
    b.get('match', {}).get('peer', {}).get('id') == 'your_telegram_id'
    for b in cfg.get('bindings', [])
)
sys.exit(0 if found else 1)
" 2>/dev/null; then
    echo "  ❌ MISSING: Telegram your_telegram_id → main binding"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ Telegram your_telegram_id → main binding"
fi

# ---------------------------------------------------------------------------
# CHECK 3: Trusted person's WhatsApp DMs route to the "shared" agent
# ---------------------------------------------------------------------------
# <Trusted Partner> gets the shared agent — separate workspace, no access to private files.
# This is the multi-agent privacy model.
if ! python3 -c "
import json, sys
cfg = json.load(open('$CONFIG'))
found = any(
    b.get('agentId') == 'shared' and
    b.get('match', {}).get('channel') == 'whatsapp' and
    b.get('match', {}).get('peer', {}).get('id') == '+<trusted_persons_number>'
    for b in cfg.get('bindings', [])
)
sys.exit(0 if found else 1)
" 2>/dev/null; then
    echo "  ❌ MISSING: WhatsApp +<trusted_persons_number>→ shared binding"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ WhatsApp +1<trusted_persons_number> → shared binding"
fi

# ---------------------------------------------------------------------------
# CHECK 4: <trusted_persons_number> number is in the WhatsApp allowlist
# ---------------------------------------------------------------------------
# dmPolicy is "allowlist", so only numbers in allowFrom can DM the bot.
# OpenClaw strips this on every restart — this is the main thing that breaks.
if ! python3 -c "
import json, sys
cfg = json.load(open('$CONFIG'))
allow = cfg.get('channels', {}).get('whatsapp', {}).get('allowFrom', [])
sys.exit(0 if '+<trusted_persons_number>' in allow else 1)
" 2>/dev/null; then
    echo "  ❌ MISSING: +<trusted_persons_number> in whatsapp.allowFrom"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ +<trusted_persons_number> in whatsapp.allowFrom"
fi

# ---------------------------------------------------------------------------
# CHECK 5: Gateway token is the current rotated one (not the old pre-rotation)
# ---------------------------------------------------------------------------
# We rotated the token on Feb 15. The old token started with "TkT6z".
# If it shows up, something reverted the security hardening.
if python3 -c "
import json, sys
cfg = json.load(open('$CONFIG'))
token = cfg.get('hooks', {}).get('token', '')
sys.exit(0 if 'TkT6z' in token else 1)
" 2>/dev/null; then
    echo "  ❌ WARNING: Old token detected in hooks.token!"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✅ Token is current"
fi

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "[config-guard] ⚠️  $ERRORS issue(s) found! Backing up current config."
    cp "$CONFIG" "$BACKUP_DIR/openclaw.json.broken-$TIMESTAMP"
    echo "  Backup saved: config-backups/openclaw.json.broken-$TIMESTAMP"
    echo "  Diff:    diff $BACKUP_DIR/openclaw.json.broken-$TIMESTAMP $BACKUP_DIR/openclaw.json.golden"
    echo "  Restore: cp $BACKUP_DIR/openclaw.json.golden $CONFIG"
    exit 1
else
    echo ""
    echo "[config-guard] ✅ All checks passed."
    # Save current config as the golden reference for auto-restore
    cp "$CONFIG" "$BACKUP_DIR/openclaw.json.golden"
    echo "  Golden copy updated."
    exit 0
fi