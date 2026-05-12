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

# Ensure data directory exists
mkdir -p "${DATA_DIR}"

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
if [ "${ENABLE_WS:-false}" = "true" ]; then
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
echo "==> WS enabled: ${ENABLE_WS:-false}"
if [ "${ENABLE_WS:-false}" = "true" ]; then
  echo "==> WS address: ${WS_ADDR:-0.0.0.0}:${WS_PORT:-8546}"
fi

# Start XDC with exec for proper signal handling
exec XDC "${args[@]}"
