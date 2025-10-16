cat > ping_log.sh <<'EOF'
#!/bin/bash
set -euo pipefail

LOG="ping_results.log"
SERVER_ID="${SERVER_ID:-}"   # 비우면 자동선택
INTERVAL="${INTERVAL:-60}"   # 초 단위 간격 (기본 60)

# ---------- 선검사 ----------
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq 가 설치되어 있지 않습니다. macOS: 'brew install jq', Ubuntu: 'sudo apt-get install -y jq'" >&2
  exit 1
fi

# speedtest 바이너리 탐지: Ookla('speedtest') 우선, 없으면 sivel('speedtest-cli')
if command -v speedtest >/dev/null 2>&1; then
  SPEEDTEST_BIN="speedtest"
elif command -v speedtest-cli >/dev/null 2>&1; then
  SPEEDTEST_BIN="speedtest-cli"
else
  echo "[ERROR] speedtest/ speedtest-cli 가 없습니다. Ookla: https://www.speedtest.net/apps/cli 또는 'pip install speedtest-cli'" >&2
  exit 1
fi

# ---------- 어떤 CLI인지 구분 ----------
detect_cli() {
  if "$SPEEDTEST_BIN" --version 2>/dev/null | grep -qi "ookla"; then
    echo "ookla"
  elif "$SPEEDTEST_BIN" --version 2>/dev/null | grep -qi "speedtest-cli"; then
    echo "sivel"
  else
    # --help에 -f json이 있으면 ookla로 간주
    if "$SPEEDTEST_BIN" --help 2>/dev/null | grep -q -- "-f.*json"; then
      echo "ookla"
    else
      echo "sivel"
    fi
  fi
}

CLI=$(detect_cli)
echo "using bin: $SPEEDTEST_BIN, cli: $CLI (interval=${INTERVAL}s, server_id=${SERVER_ID:-auto})" >&2

# ---------- 로그 헤더 ----------
if [[ ! -f "$LOG" ]]; then
  echo "time,ping_ms,server_id,server_name,client_isp" > "$LOG"
fi

trap 'echo "stopped." >&2; exit 0' INT TERM

# ---------- 1회 측정 ----------
run_once() {
  local raw=""
  if [[ "$CLI" == "ookla" ]]; then
    # Ookla: -f json, --server-id, 동의 플래그, 진행바 끄기
    if [[ -n "$SERVER_ID" ]]; then
      raw=$("$SPEEDTEST_BIN" -f json --progress=no --server-id "$SERVER_ID" --accept-license --accept-gdpr 2>/dev/null) || true
    else
      raw=$("$SPEEDTEST_BIN" -f json --progress=no --accept-license --accept-gdpr 2>/dev/null) || true
    fi
  else
    # sivel: --json, --server (speedtest-cli는 바이너리가 'speedtest-cli')
    if [[ -n "$SERVER_ID" ]]; then
      raw=$("$SPEEDTEST_BIN" --json --server "$SERVER_ID" 2>/dev/null) || true
    else
      raw=$("$SPEEDTEST_BIN" --json 2>/dev/null) || true
    fi
  fi

  if [[ -z "${raw:-}" ]]; then
    echo '{"error":"empty_output"}'
  else
    echo "$raw"
  fi
}

# ---------- 메인 루프 ----------
while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  json=$(run_once)

  # ping(ms): sivel(.ping) 또는 ookla(.ping.latency)
  ping_ms=$(jq -r '(.ping // .ping.latency) // empty' <<<"$json")
  # 서버/클라이언트 정보(키가 CLI마다 다름)
  server_id=$(jq -r '(.server.id // .server.id) // empty' <<<"$json")
  server_name=$(jq -r '(.server.name // .server.sponsor // .server.host) // empty' <<<"$json")
  client_isp=$(jq -r '(.client.isp // .isp // .client.name) // empty' <<<"$json")

  [[ -z "$ping_ms" || "$ping_ms" == "null" ]] && ping_ms="NA"
  [[ -z "$server_id" || "$server_id" == "null" ]] && server_id="${SERVER_ID:-auto}"
  [[ -z "$server_name" || "$server_name" == "null" ]] && server_name="unknown"
  [[ -z "$client_isp" || "$client_isp" == "null" ]] && client_isp="unknown"

  echo "${ts},${ping_ms},${server_id},${server_name},${client_isp}" | tee -a "$LOG"

  sleep "$INTERVAL"
done
EOF

chmod +x ping_log.sh
