#!/usr/bin/env bash
# OpenClaw Guide — True one-click install (Linux / macOS / WSL2)
# One command, no manual steps after it. You only supply:
#   - an API key (hidden prompt, or OPENCLAW_CUSTOM_API_KEY)
#   - optionally a Telegram bot token (hidden prompt, or TELEGRAM_BOT_TOKEN)
# The script then does everything: install, key/model verify, config
# backup + provider write (with model name, required by OpenClaw
# 2026.11.1+), config validate, Telegram channel, gateway start,
# wait until the gateway answers, channel probe, and a short summary.
# Keys are never printed and never written to git or shell history.
#
# Usage:
#   bash install.sh
#   bash install.sh --base-url https://api.example.com/v1 --model your-model-id
#   OPENCLAW_CUSTOM_API_KEY=... bash install.sh --dry-run
#
# --dry-run prints what would change and changes nothing. --skip-install
# skips the official installer (useful when OpenClaw is already there).
# --skip-telegram skips the Telegram prompt entirely.
set -euo pipefail

BASE_URL="${OPENCLAW_BASE_URL:-}"
MODEL_ID="${OPENCLAW_MODEL:-}"
PROVIDER_NAME="${OPENCLAW_PROVIDER:-myprovider}"
API_KEY="${OPENCLAW_CUSTOM_API_KEY:-}"
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
DRY_RUN=0
SKIP_INSTALL=0
SKIP_TELEGRAM=0

while [ $# -gt 0 ]; do
  case "$1" in
    --base-url) BASE_URL="$2"; shift 2 ;;
    --model) MODEL_ID="$2"; shift 2 ;;
    --provider) PROVIDER_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --skip-telegram) SKIP_TELEGRAM=1; shift ;;
    --help|-h) sed -n '1,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

gateway_ready() {
  command -v openclaw >/dev/null 2>&1 || return 1
  local out
  out="$(openclaw gateway status 2>/dev/null || true)"
  printf '%s' "$out" | grep -q "Connectivity check: ok" && return 0
  printf '%s' "$out" | grep -q "Listening: 127.0.0.1:18789" && return 0
  return 1
}

wait_for_gateway() {
  # $1 = max seconds to wait (default 150). A cold gateway takes ~40s.
  local max="${1:-150}" waited=0
  while [ "$waited" -lt "$max" ]; do
    if gateway_ready; then
      say "Gateway is up (listening on 127.0.0.1:18789)."
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

[ -n "$BASE_URL" ] || { printf 'Custom Base URL (e.g. https://api.example.com/v1): '; read -r BASE_URL; }
[ -n "$MODEL_ID" ] || { printf 'Model ID (e.g. your-model-id): '; read -r MODEL_ID; }
if [ -z "$API_KEY" ]; then
  printf 'API key for %s (hidden, not echoed): ' "$BASE_URL"
  read -rs API_KEY; echo
fi
[ -n "$BASE_URL" ] || die "Base URL is required."
[ -n "$MODEL_ID" ] || die "Model ID is required."
[ -n "$API_KEY" ] || die "API key is required."
case "$BASE_URL" in
  */v1) ;;
  *) say "Note: OpenAI-compatible providers usually end with /v1. Continuing with: $BASE_URL" ;;
esac

CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="$CONFIG_DIR/backups"

if [ "$DRY_RUN" = "1" ]; then
  say "[dry-run] Would install OpenClaw (skip-install=$SKIP_INSTALL), verify $BASE_URL/models, back up $CONFIG_FILE, set primary model to $PROVIDER_NAME/$MODEL_ID, validate the config, add Telegram (if a token is given), start the gateway and wait until it answers, then probe channels. Nothing will change."
  exit 0
fi

command -v curl >/dev/null || die "curl is required."
command -v python3 >/dev/null || die "python3 is required (used only to merge the JSON config safely)."

# 1. Install OpenClaw itself (official installer only).
if [ "$SKIP_INSTALL" = "0" ] && ! command -v openclaw >/dev/null 2>&1; then
  say "Installing OpenClaw (official installer)..."
  curl -fsSL https://openclaw.ai/install.sh | bash -- --no-onboard
else
  say "OpenClaw already installed, or --skip-install given. Skipping official installer."
fi
command -v openclaw >/dev/null 2>&1 || die "'openclaw' is not on PATH after install. Reopen your terminal, then rerun with --skip-install."

# 2. Verify the key + model against the provider before writing anything.
say "Verifying API key against $BASE_URL/models ..."
MODELS_JSON="$(curl -fsS -H "Authorization: Bearer $API_KEY" "$BASE_URL/models" 2>/dev/null || true)"
if [ -z "$MODELS_JSON" ]; then
  die "Could not reach $BASE_URL/models. Check the base URL (401 = key, 404 = URL) and try again. Nothing was written."
fi
if ! printf '%s' "$MODELS_JSON" | grep -q "$MODEL_ID"; then
  say "Warning: model '$MODEL_ID' was not listed by $BASE_URL/models. Continuing anyway — the provider may list models differently."
fi

# 3. Back up, then merge the provider config (pure-JSON path).
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
if [ -f "$CONFIG_FILE" ]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP_DIR/openclaw.json.$TS"
  chmod 600 "$BACKUP_DIR/openclaw.json.$TS" 2>/dev/null || true
  say "Backed up existing config to $BACKUP_DIR/openclaw.json.$TS"
fi

OPENCLAW_BASE_URL="$BASE_URL" OPENCLAW_PROVIDER="$PROVIDER_NAME" OPENCLAW_MODEL="$MODEL_ID" \
  OPENCLAW_CONFIG_FILE="$CONFIG_FILE" python3 - <<'PY'
import json, os, sys
path = os.environ["OPENCLAW_CONFIG_FILE"]
try:
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
    if not isinstance(cfg, dict):
        raise ValueError("config is not a JSON object")
except FileNotFoundError:
    cfg = {}
except Exception as exc:
    print(f"Existing config is not plain JSON ({exc}). It was backed up, but not merged.", file=sys.stderr)
    print("Write your provider into the backup by hand, or start from templates/openclaw.json.example.", file=sys.stderr)
    sys.exit(3)
cfg.setdefault("models", {}).setdefault("providers", {})[os.environ["OPENCLAW_PROVIDER"]] = {
    "baseUrl": os.environ["OPENCLAW_BASE_URL"],
    "api": "openai-completions",
    "models": [{"id": os.environ["OPENCLAW_MODEL"], "name": os.environ["OPENCLAW_MODEL"]}],
}
cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("model", {})["primary"] = (
    f"{os.environ['OPENCLAW_PROVIDER']}/{os.environ['OPENCLAW_MODEL']}"
)
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.chmod(path, 0o600)
print(f"Wrote provider to {path} (mode 600). Primary model: {cfg['agents']['defaults']['model']['primary']}")
PY

# 3b. Validate the config now, so a bad config fails here — not later
# at the dashboard or Telegram step (OpenClaw 2026.11.1 requires a
# model "name", and doctor cannot fix a missing one).
say "Validating config..."
openclaw config validate || die "Config is invalid after writing. Restore the backup in $BACKUP_DIR and report this."
say "Config valid."

# 4. Telegram (optional, only if a token is given and not skipped).
# Asked once, here, before the gateway starts — the channel is config,
# it does not need a running gateway to be added.
TELEGRAM_ADDED=0
if [ "$SKIP_TELEGRAM" = "0" ] && [ -z "$TELEGRAM_TOKEN" ]; then
  printf 'Telegram bot token (optional, Enter to skip): '
  read -rs TELEGRAM_TOKEN; echo
fi
if [ -n "${TELEGRAM_TOKEN:-}" ]; then
  say "Adding Telegram channel..."
  if openclaw channels add --channel telegram --token "$TELEGRAM_TOKEN" 2>/dev/null; then
    TELEGRAM_ADDED=1
  else
    say "Warning: Telegram channel add failed. Check the token and rerun: openclaw channels add --channel telegram --token <TOKEN>"
  fi
  unset TELEGRAM_TOKEN
fi

# 5. Start the gateway and wait until it answers. No manual step after
# this script: on machines with a service manager the managed daemon
# is used; without one (e.g. Cloud Shell) the gateway runs in the
# background instead. A cold gateway takes ~40s to be ready.
if gateway_ready; then
  say "Gateway is already running. Restarting it so the new config loads..."
  openclaw gateway restart 2>/dev/null || true
  wait_for_gateway 150 || die "Gateway did not come back up after restart. Run 'openclaw gateway status --deep' and check /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
else
  openclaw gateway install 2>/dev/null || true
  openclaw gateway start 2>/dev/null || true
  if ! wait_for_gateway 60; then
    say "Managed daemon did not start (no service manager here?). Starting the gateway in the background instead..."
    nohup openclaw gateway run > /tmp/openclaw-gateway.log 2>&1 &
    wait_for_gateway 150 || die "Gateway did not come up. See /tmp/openclaw-gateway.log for the reason."
  fi
fi

# 6. Probe channels (best effort — a failed probe does not undo the install).
openclaw channels status --probe 2>/dev/null || true

say ""
say "Done. OpenClaw is running."
say "  Dashboard: http://127.0.0.1:18789/"
say "    - On this machine, run: openclaw dashboard"
say "    - On Cloud Shell, use Web Preview on port 18789. On a remote server, use an SSH tunnel: ssh -N -L 18789:127.0.0.1:18789 <user>@<host>, then open http://localhost:18789/"
say "    - The dashboard asks for a token. Get it with: openclaw gateway auth-token --show  (never share it)"
if [ "$TELEGRAM_ADDED" = "1" ]; then
  say "  Telegram: message your bot, then approve pairing with: openclaw pairing approve telegram <CODE>"
fi
say "  Note: on Cloud Shell the gateway stops when the session closes. For 24/7, run this on a VPS."
say "  Never expose port 18789 to the public internet."
