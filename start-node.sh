#!/usr/bin/env bash
# =============================================================================
# XDC Node Startup Script
# =============================================================================
# Starts the XDC node in RPC mode (non-mining) with modern CLI flags.
# Uses --bootnodes for peer discovery instead of post-startup IPC injection.
# =============================================================================

set -Eeuo pipefail

WORK_DIR="/work"
DATA_DIR="${WORK_DIR}/xdcchain"
IPC_PATH="${DATA_DIR}/XDC.ipc"
ENODE_FILE="/work/enode.txt"

# Ensure data directory exists
mkdir -p "${DATA_DIR}"

# Download and extract snapshot if SNAPSHOT_URL is set and chaindata doesn't exist
if [ -n "${SNAPSHOT_URL:-}" ] && [ ! -d "$DATA_DIR/XDC/chaindata" ]; then
  echo "==> Downloading XDC snapshot from ${SNAPSHOT_URL}"
  echo "==> This is a ~650GB file and may take several hours"
  cd "$DATA_DIR"

  if [ -f xdcchain.tar ]; then
    echo "==> Resuming previous download"
  fi

  wget -c -T 30 -O xdcchain.tar "${SNAPSHOT_URL}"

  echo "==> Extracting snapshot (this may take 1-2 hours)"
  tar -xvzf xdcchain.tar || tar -xvf xdcchain.tar

  rm -f xdcchain.tar
  rm -f XDC/nodekey

  echo "==> Snapshot extraction complete"
  cd "${WORK_DIR}"
fi

# Download and initialize genesis if needed
if [ ! -d "$DATA_DIR/XDC/chaindata" ]; then
  echo "==> Downloading genesis from ${GENESIS_URL}"
  wget "${GENESIS_URL}" -O /tmp/genesis.json

  echo "==> Initializing XDC genesis"
  XDC init --datadir "$DATA_DIR" /tmp/genesis.json
  rm -f /tmp/genesis.json
fi

# Determine network parameters
if [ "${NETWORK}" = "testnet" ]; then
  NETWORK_ID="${NETWORK_ID:-51}"
  P2P_PORT_INTERNAL=30312
else
  NETWORK_ID="${NETWORK_ID:-50}"
  P2P_PORT_INTERNAL="${P2P_PORT:-30303}"
fi

# Build XDC arguments
args=(
  --datadir "$DATA_DIR"
  --XDCx.datadir "$DATA_DIR/XDCx"
  --networkid "$NETWORK_ID"
  --port "$P2P_PORT_INTERNAL"
  --syncmode "${SYNC_MODE:-full}"
  --gcmode "${GC_MODE:-full}"
  --verbosity "${LOG_LEVEL:-3}"
)

# Add bootnodes if available
if [ -n "${XDC_BOOTNODES:-}" ]; then
  args+=(--bootnodes "${XDC_BOOTNODES}")
  echo "==> Using $(echo "$XDC_BOOTNODES" | tr ',' '\n' | wc -l | xargs) bootnodes"
fi

# HTTP RPC configuration
if [ "${ENABLE_RPC:-true}" = "true" ]; then
  args+=(
    --http
    --http-addr "${RPC_ADDR:-0.0.0.0}"
    --http-port "${RPC_PORT:-8545}"
    --http-api "${RPC_API:-eth,net,web3,XDPoS}"
    --http-corsdomain "${RPC_CORS_DOMAIN:-}"
    --http-vhosts "${RPC_VHOSTS:-localhost}"
  )
else
  args+=(--http=false)
fi

# WebSocket configuration
if [ "${ENABLE_WS:-true}" = "true" ]; then
  args+=(
    --ws
    --ws-addr "${WS_ADDR:-0.0.0.0}"
    --ws-port "${WS_PORT:-8546}"
    --ws-api "${WS_API:-eth,net,web3,XDPoS}"
    --ws-origins "${WS_ORIGINS:-}"
  )
else
  args+=(--ws=false)
fi

# Add any extra user-specified args
if [ -n "${EXTRA_ARGS:-}" ]; then
  # shellcheck disable=SC2206
  extra_args=( ${EXTRA_ARGS} )
  args+=("${extra_args[@]}")
fi

# Display startup info
echo "==> Starting XDC node"
echo "==> Network: ${NETWORK:-mainnet}"
echo "==> Network ID: $NETWORK_ID"
echo "==> Data directory: $DATA_DIR"
echo "==> Sync mode: ${SYNC_MODE:-full}"
echo "==> GC mode: ${GC_MODE:-full}"
echo "==> RPC enabled: ${ENABLE_RPC:-true}"
if [ "${ENABLE_RPC:-true}" = "true" ]; then
  echo "==> RPC address: ${RPC_ADDR:-0.0.0.0}:${RPC_PORT:-8545}"
fi
echo "==> WS enabled: ${ENABLE_WS:-true}"
if [ "${ENABLE_WS:-true}" = "true" ]; then
  echo "==> WS address: ${WS_ADDR:-0.0.0.0}:${WS_PORT:-8546}"
fi

# Peer injection helpers
get_peer_count() {
  XDC --exec 'admin.peers.length' attach "${IPC_PATH}" 2>/dev/null | tail -n 1 | tr -dc '0-9' || echo 0
}

inject_peers() {
  [ -f "${ENODE_FILE}" ] || return 0

  peer_count="$(get_peer_count)"
  peer_count="${peer_count:-0}"

  if [ "${peer_count}" -ge "${MIN_PEERS:-3}" ]; then
    return 0
  fi

  echo "==> Peer count is ${peer_count}; injecting peers from ${ENODE_FILE}"

  while IFS= read -r enode; do
    [ -z "${enode}" ] && continue
    case "${enode}" in
      \#*) continue ;;
    esac

    XDC --exec "admin.addPeer(\"${enode}\")" attach "${IPC_PATH}" >/dev/null 2>&1 || true
  done < "${ENODE_FILE}"

  echo "==> Peer injection complete; peer count now $(get_peer_count)"
}

# Start XDC in background so this wrapper can inject peers and forward signals
XDC "${args[@]}" &
XDC_PID=$!

shutdown() {
  echo "==> Received shutdown signal, stopping XDC"
  kill -TERM "${PEER_INJECT_PID:-}" 2>/dev/null || true
  kill -TERM "${XDC_PID}" 2>/dev/null || true
  wait "${XDC_PID}" 2>/dev/null || true
  exit 0
}

trap shutdown TERM INT

echo "==> Waiting for IPC to be ready..."
until [ -S "${IPC_PATH}" ]; do
  if ! kill -0 "${XDC_PID}" 2>/dev/null; then
    echo "==> XDC exited before IPC became ready"
    wait "${XDC_PID}"
    exit $?
  fi
  sleep 2
done

echo "==> IPC ready"

inject_peers
(
  while kill -0 "${XDC_PID}" 2>/dev/null; do
    sleep "${PEER_INJECT_INTERVAL:-60}"
    inject_peers
  done
) &
PEER_INJECT_PID=$!

wait "${XDC_PID}"
EXIT_CODE=$?
kill -TERM "${PEER_INJECT_PID:-}" 2>/dev/null || true
exit "${EXIT_CODE}"
