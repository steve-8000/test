cat > ping_log.sh <<'EOF'
#!/bin/bash
set -euo pipefail

LOG="${LOG:-ping_results.log}"
SPEEDTEST_BIN="/home/a4x/.local/bin/speedtest-cli"   # sivel speedtest-cli로 고정
SERVER_ID="${SERVER_ID:-}"                            # 비우면 자동 선택
INTERVAL="${INTERVAL:-60}"                            # 초
DEBUG="${DEBUG:-0}"

# jq 필수
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq가 필요합니다. 설치 후 재시도하세요." >&2
  exit 1
fi

# speedtest-cli 존재 확인
if [[ ! -x "$SPEEDTEST_BIN" ]]; then
  echo "[ERROR] $SPEEDTEST_BIN 실행 파일을 찾을 수 없습니다." >&2
  exit 1
fi

# 로그 헤더 1회
if [[ ! -f "$LOG" ]]; then
  echo "time,ping_ms,server_id,server_name,client_isp" > "$LOG"
fi

trap 'echo "stopped." >&2; exit 0' INT TERM

run_once() {
  local raw rc
  if [[ -n "$SERVER_ID" ]]; then
    raw=$("$SPEEDTEST_BIN" --json --server "$SERVER_ID" 2>&1); rc=$?
  else
    raw=$("$SPEEDTEST_BIN" --json 2>&1); rc=$?
  fi
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DBG] rc=$rc raw_head=$(printf '%s' "$raw" | head -c 300 | tr '\n' ' ')" >&2
  fi
  # 성공/실패와 상관없이 raw 반환 (실패 시 jq에서 NA 처리)
  printf '%s\n' "$raw"
}

while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  json="$(run_once)"

  # sivel 포맷: ping은 .ping, 서버정보는 .server.*
  ping_ms=$(jq -r '.ping // empty' <<<"$json") || ping_ms=""
  server_id=$(jq -r '.server.id // empty' <<<"$json") || server_id=""
  server_name=$(jq -r '(.server.name // .server.sponsor // .server.host) // empty' <<<"$json") || server_name=""
  client_isp=$(jq -r '(.client.isp // .isp // .client.name) // empty' <<<"$json") || client_isp=""

  [[ -z "$ping_ms" || "$ping_ms" == "null" ]] && ping_ms="NA"
  [[ -z "$server_id" || "$server_id" == "null" ]] && server_id="${SERVER_ID:-auto}"
  [[ -z "$server_name" || "$server_name" == "null" ]] && server_name="unknown"
  [[ -z "$client_isp" || "$client_isp" == "null" ]] && client_isp="unknown"

  echo "${ts},${ping_ms},${server_id},${server_name},${client_isp}" | tee -a "$LOG"
  sleep "$INTERVAL"
done
EOF

chmod +x ping_log.sh
