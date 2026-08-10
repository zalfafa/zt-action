set -euo pipefail
IFS=$'\n\t'

# /home/runner/work/zerotier-github-action/zerotier-github-action/./
echo $GITHUB_ACTION_PATH

# ── 1. Detect OS & check if ZeroTier is already installed ──────────────────────
IS_INSTALLED=false

case $(uname -s) in
MINGW64_NT?*)
  ztcli="/c/Program Files (x86)/ZeroTier/One/zerotier-cli.bat"
  if [ -f "${ztcli}" ]; then
    IS_INSTALLED=true
  fi
  ;;
*)
  if command -v zerotier-cli &>/dev/null; then
    IS_INSTALLED=true
  fi
  ;;
esac

# ── 2. Install ZeroTier (skip if already present) ──────────────────────────────
if [ "$IS_INSTALLED" = true ]; then
  echo "⏁  ZeroTier is already installed, skipping installation."
else
  echo "⏁  Installing ZeroTier"
  case $(uname -s) in
  MINGW64_NT?*)
    pwsh "$GITHUB_ACTION_PATH/util/install.ps1"
    ztcli="/c/Program Files (x86)/ZeroTier/One/zerotier-cli.bat"
    ;;
  *)
    . $GITHUB_ACTION_PATH/util/install.sh &>/dev/null
    ;;
  esac
fi

# ── 3. Get member ID ──────────────────────────────────────────────────────────
case $(uname -s) in
MINGW64_NT?*)
  member_id=$("${ztcli}" info | awk '{ print $3 }')
  ;;
*)
  member_id=$(sudo zerotier-cli info | awk '{ print $3 }')
  ;;
esac

# ── 4. Authorize Runner to ZeroTier network ────────────────────────────────────
echo "⏁  Authorizing Runner to ZeroTier network"
MAX_RETRIES=10
RETRY_COUNT=0

# Use custom member name/description if provided, otherwise use defaults
MEMBER_NAME_VAL="${MEMBER_NAME:-Zerotier GitHub Member ${GITHUB_SHA::7}}"
MEMBER_DESC_VAL="${MEMBER_DESCRIPTION:-Member created by ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}}"

# Build body: assign fixed IPs if provided, otherwise let the pool auto-assign
if [ -n "${IP_ASSIGNMENTS:-}" ]; then
  BODY='{"name":"'"${MEMBER_NAME_VAL}"'", "description": "'"${MEMBER_DESC_VAL}"'", "config":{"authorized":true,"noAutoAssignIps":true,"ipAssignments":["'"$(echo $IP_ASSIGNMENTS | sed 's/,/","/g')"'"]}}'
else
  BODY='{"name":"'"${MEMBER_NAME_VAL}"'", "description": "'"${MEMBER_DESC_VAL}"'", "config":{"authorized":true,"ipAssignments":[]}}'
fi

while ! curl -s -X POST \
  -H "Authorization: token $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$API_URL/network/$NETWORK_ID/member/${member_id}" | grep '"authorized":true'; do
  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Reached maximum number of retries ($MAX_RETRIES). Exiting..."
    exit 1
  fi

  echo "Authorization failed. Retrying in 2 seconds... (Attempt $RETRY_COUNT of $MAX_RETRIES)"
  sleep 2
done

echo "Member authorized successfully."

# ── 5. Join ZeroTier Network (with timeout) ────────────────────────────────────
echo "⏁  Joining ZeroTier Network ID: $NETWORK_ID"

# Timeout: 120 iterations * 0.5s = 60 seconds max
WAIT_COUNT=0
MAX_WAIT=120

case $(uname -s) in
MINGW64_NT?*)
  "${ztcli}" join $NETWORK_ID
  while ! "${ztcli}" listnetworks | grep $NETWORK_ID | grep OK; do
    sleep 0.5
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
      echo "ERROR: Timeout after 60s waiting for network $NETWORK_ID to become OK."
      exit 1
    fi
  done
  ;;
*)
  sudo zerotier-cli join $NETWORK_ID
  while ! sudo zerotier-cli listnetworks | grep $NETWORK_ID | grep OK; do
    sleep 0.5
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
      echo "ERROR: Timeout after 60s waiting for network $NETWORK_ID to become OK."
      exit 1
    fi
  done
  ;;
esac

echo "⏁  Successfully joined ZeroTier network $NETWORK_ID"
