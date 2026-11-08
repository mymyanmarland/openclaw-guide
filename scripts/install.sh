#!/usr/bin/env bash
# OpenClaw Guide — One-click install (Linux / macOS / WSL2)
# For a NEW machine, for everyone. NOT for an already-running gateway:
# it backs up ~/.openclaw/openclaw.json before any change and never
# deletes the backup. Keys are never printed and never written to git.
#
# Usage:
#   bash install.sh
#   bash install.sh --base-url https://api.example.com/v1 --model your-model-id
#   OPENCLAW_CUSTOM_API_KEY=... bash install.sh --dry-run
#
# Prompts (hidden input) are used for anything not passed in, so a key
# never appears in shell history. --dry-run prints what would change
# and changes nothing. --skip-install skips the official installer and
# only writes the provider config (useful when OpenClaw is already there).
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
    --help|-h) sed -n '1,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

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
  say "[dry-run] Would install OpenClaw (skip-install=$SKIP_INSTALL), verify $BASE_URL/models, back up $CONFIG_FILE, and set primary model to $PROVIDER_NAME/$MODEL_ID."
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
command -v openclaw >/dev/null 2>&1 || say "Warning: 'openclaw' is not on PATH yet. Reopen your terminal if the next steps fail, then rerun with --skip-install."

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

# 4. Telegram (optional, only if a token is given and not skipped).
if [ "$SKIP_TELEGRAM" = "0" ] && [ -z "$TELEGRAM_TOKEN" ]; then
  printf 'Telegram bot token (optional, Enter to skip): '
  read -rs TELEGRAM_TOKEN; echo
fi
if [ -n "${TELEGRAM_TOKEN:-}" ] && command -v openclaw >/dev/null 2>&1; then
  say "Adding Telegram channel..."
  openclaw channels add --channel telegram --token "$TELEGRAM_TOKEN" || say "Warning: Telegram channel add failed. Check the token and rerun the channel command by hand."
  unset TELEGRAM_TOKEN
fi

# 5. Gateway service + status.
if command -v openclaw >/dev/null 2>&1; then
  openclaw gateway install 2>/dev/null || true
  openclaw gateway status 2>/dev/null || say "Run 'openclaw gateway status' and 'openclaw dashboard' to check the gateway."
fi

say ""
say "Done. Next:"
say "  1. Run: openclaw dashboard   (opens http://127.0.0.1:18789/)"
say "  2. If you added Telegram: message your bot, then approve pairing with: openclaw pairing approve telegram <CODE>"
say "  3. Never expose port 18789 to the public internet. Use an SSH tunnel, nginx + HTTPS + basic auth, or Tailscale."
