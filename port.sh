#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"

SERVER="207.244.243.96"
USER="root"
PASSWORD="skgamer"

USE_PASSWORD=true

mkdir -p /tmp
touch "$DB_FILE"

# Colors
RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
CYN="\e[36m"
RST="\e[0m"

banner() {
  echo -e "${CYN}"
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   CrystalClouds Port Tool - Developed By SKGamer ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo -e "${RST}"
}

# ================================
# Dynamic Range Scanner
# ================================
get_free_port_range() {
  RANGE_START=$1
  RANGE_END=$2

  for PORT in $(seq "$RANGE_START" "$RANGE_END"); do
    if ! ss -tulpn | grep -q ":$PORT "; then
      echo "$PORT"
      return
    fi
  done

  echo "0"
}

# ================================
# Create Tunnel
# ================================
add_tunnel() {
  INPUT=$1
  TMP=$(mktemp)

  # RANGE MODE
  if [[ "$INPUT" == *"-"* ]]; then
    RANGE_START=$(echo "$INPUT" | cut -d'-' -f1)
    RANGE_END=$(echo "$INPUT" | cut -d'-' -f2)

    echo -e "${YEL}Range mode detected: $RANGE_START - $RANGE_END${RST}"

    LOCAL_PORT=$(get_free_port_range "$RANGE_START" "$RANGE_END")

    if [[ "$LOCAL_PORT" == "0" ]]; then
      echo -e "❌ No free ports available in this range"
      return
    fi

    echo -e "🎯 Selected free port: ${GRN}$LOCAL_PORT${RST}"

  else
    LOCAL_PORT=$INPUT
  fi

  # Validate port
  if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid port"
    return
  fi

  REMOTE_PORT="$LOCAL_PORT"

  echo -e "${YEL}Creating tunnel...${RST}"

  sshpass -p "$PASSWORD" ssh -p 22 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -N -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${USER}@${SERVER} \
    >"$TMP" 2>&1 &

  PID=$!
  sleep 1

  if ps -p "$PID" >/dev/null 2>&1; then
    echo "$LOCAL_PORT:$REMOTE_PORT:$PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel Created Successfully!${RST}"
    echo " Local Port  : $LOCAL_PORT"
    echo " Remote Port : $SERVER:$REMOTE_PORT"
  else
    echo "❌ Failed to create tunnel!"
    echo "Debug info:"
    cat "$TMP"
  fi

  rm -f "$TMP"
}

# ================================
# Stop Tunnel
# ================================
stop_tunnel() {
  PORT=$1
  TMP=$(mktemp)
  FOUND=0

  while IFS=: read -r L R P; do
    if [[ "$L" == "$PORT" ]]; then
      kill "$P" 2>/dev/null
      echo "🛑 Stopped tunnel: $L → $R"
      FOUND=1
    else
      echo "$L:$R:$P" >> "$TMP"
    fi
  done < "$DB_FILE"

  mv "$TMP" "$DB_FILE"
  [[ $FOUND -eq 0 ]] && echo "❌ No tunnel found!"
}

stop_all() {
  echo "🛑 Stopping all tunnels..."
  while IFS=: read -r L R P; do
    kill "$P" 2>/dev/null
  done < "$DB_FILE"
  > "$DB_FILE"
  echo "✔ All tunnels stopped"
}

# ================================
# List Tunnels
# ================================
list_tunnels() {
  banner
  if [[ ! -s "$DB_FILE" ]]; then
    echo "❌ No tunnels running."
    return
  fi

  while IFS=: read -r L R P; do
    if ps -p "$P" >/dev/null 2>&1; then STATUS="Alive"; else STATUS="Dead"; fi
    echo " localhost:$L → $SERVER:$R ($STATUS)"
  done < "$DB_FILE"
}

# ================================
# Check Server Status
# ================================
status() {
  banner
  echo "Checking SSH status..."

  sshpass -p "$PASSWORD" ssh -p 22 \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=3 \
    ${USER}@${SERVER} "echo OK" >/dev/null 2>&1

  [[ $? -eq 0 ]] && echo "✅ SSH Connected" || echo "❌ Connection Failed"
}

# ================================
# Help Menu
# ================================
help_menu() {
  banner
  echo "Commands:"
  echo " port add 25565           - Create tunnel on same port"
  echo " port add 10000-20000     - Create tunnel using free port from range"
  echo " port stop <port>         - Stop specific tunnel"
  echo " port stop all            - Stop all tunnels"
  echo " port list tunnels        - Show active tunnels"
  echo " port status              - Check SSH connection"
  echo " port help                - Show help"
}

case "$1" in
  add) add_tunnel "$2" ;;
  stop) [[ "$2" == "all" ]] && stop_all || stop_tunnel "$2" ;;
  list) [[ "$2" == "tunnels" ]] && list_tunnels || help_menu ;;
  status) status ;;
  help|"") help_menu ;;
  *) help_menu ;;
esac
