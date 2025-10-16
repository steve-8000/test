cat > ping_log.sh <<'EOF'
#!/bin/bash
set -euo pipefail

LOG="${LOG:-ping_results.log}"
SERVER_ID="${SERVER_ID:-}"     # 비우면 자동선택
INTERVAL="${INTERVAL:-60}"     # 초 단위
TIMEOUT_SEC="${TIMEOUT_SEC:-25}" # speedtest 실행 타임아웃
DEBUG="${DEBUG:-0}"

# --- 유틸: echo to stderr ---
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

# --- jq 필수 ---
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq 미설치. macOS: 'brew install jq', Ubuntu: 'sudo apt-get install -y jq'" >&2
  exit 1
fi

# --- timeout 준비 (macOS면 coreutils의 gtimeout일 수 있음) ---
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  log "경고: timeout/gtimeout 없음. 무한 대기 가능성 있음(계속 진행)."
fi

# --- speedtest 바이너리 탐지 ---
SPEEDTEST_BIN=""
if command -v speedtest >/dev/null 2>&1; then
  SPEEDTEST_BIN="$(command -v speedtest)"
elif command -v speedtest-cli >/dev/null 2>&1; then
  SPEEDTEST_BIN="$(command -v speedtest-cli)"
else
  echo "[ERROR] speedtest/ speedtest-cli 미설치." >&2
  exit 1
fi

# --- CLI 종류 감지 (ookla/sivel) ---
detect_cli() {
  local ver
  ver="$("$SPEEDTEST_BIN" --version 2>/dev/null || true)"
  if grep -qi "ookla" <<<"$ver"; then
    echo "ookla"; return
  fi
  if grep -qi "speedtest-cli" <<<"$ver"; then
    echo "sivel"; return
  fi
  # --help 검사로 최후 판정
  if "$SPEEDTEST_BIN" --help 2>/dev/null | grep -q -- "-f.*json"; then
    echo "ookla"
  else
    echo "sivel"
  fi
}

CLI="$(detect_cli)"
log "bin: $SPEEDTEST_BIN, cli: $CLI, interval=${INTERVAL}s, server_id=${SERVER_ID:-auto}"

# --- 로그 헤더 ---
if [[ ! -f "$LOG" ]]; then
  echo "time,ping_ms,server_id,server_name,client_isp" > "$LOG"
fi

trap 'log "stopped."; exit 0' INT TERM

# --- 1회 실행: 실패해도 JSON 한 줄 보장 ---
run_once() {
  local cmd raw=""
  if [[ "$CLI" == "ookla" ]]; then
    if [[ -n "$SERVER_ID" ]]; then
      cmd=( "$SPEEDTEST_BIN" -f json --progress=no --server-id "$SERVER_ID" --accept-license --accept-gdpr )
    else
      cmd=( "$SPEEDTEST_BIN" -f json --progress=no --accept-license --accept-gdpr )
    fi
  else
    if [[ -n "$SERVER_ID" ]]; then
      cmd=( "$SPEEDTEST_BIN" --json --server "$SERVER_ID" )
    else
      cmd=( "$SPEEDTEST_BIN" --json )
    fi
  fi

  # timeout 적용
  if [[ -n "$TIMEOUT_BIN" ]]; then
    cmd=( "$TIMEOUT_BIN" "$TIMEOUT_SEC" "${cmd[@]}" )
  fi

  # set -e 환경에서 실패해도 계속 진행하도록
  set +e
  raw="$("${cmd[@]}" 2>&1)"
  local rc=$?
  set -e

  # 디버그 출력(원시 출력 앞 500자만)
  if [[ "$DEBUG" == "1" ]]; then
    log "rc=${rc}, raw_head=$(printf '%s' "$raw" | head -c 500 | tr '\n' ' ' )"
  fi

  # Ookla가 가끔 TTY/환경에 따라 부가 텍스트 섞을 수 있음 → JSON만 뽑기
  # 가장 마지막 JSON 객체를 추출 시도
  local json
  json="$(printf '%s\n' "$raw" | awk '
    BEGIN{buf=""; depth=0}
    {
      for(i=1;i<=length($0);i++){
        c=substr($0,i,1)
        if(c=="{"){depth++; buf=buf c}
        else if(c=="}"){depth--; buf=buf c; if(depth==0){print buf; buf=""}}
        else if(depth>0){buf=buf c}
      }
    }
  ' | tail -n1)"

  if [[ -z "$json" ]]; then
    # 마지막 시도: raw가 이미 순수 JSON일 수도
    if jq -e . >/dev/null 2>&1 <<<"$raw"; then
      json="$raw"
    else
      json='{"error":"no_json","raw_sample":"'"$(printf '%s' "$raw" | head -c 120 | tr -d '\n' | sed 's/"/\\"/g')"'" }'
    fi
  fi

  printf '%s\n' "$json"
}

# --- 메인 루프 ---
while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  json="$(run_once)"

  # jq 실패해도 죽지 않게 보호
  set +e
  ping_ms=$(jq -r '(.ping // .ping.latency) // empty' <<<"$json"); rc1=$?
  server_id=$(jq -r '(.server.id // .server.id) // empty' <<<"$json"); rc2=$?
  server_name=$(jq -r '(.server.name // .server.sponsor // .server.host) // empty' <<<"$json"); rc3=$?
  client_isp=$(jq -r '(.client.isp // .isp // .client.name) // empty' <<<"$json"); rc4=$?
  set -e

  [[ $rc1 -ne 0 || -z "${ping_ms:-}" || "$ping_ms" == "null" ]] && ping_ms="NA"
  [[ $rc2 -ne 0 || -z "${server_id:-}" || "$server_id" == "null" ]] && server_id="${SERVER_ID:-auto}"
  [[ $rc3 -ne 0 || -z "${server_name:-}" || "$server_name" == "null" ]] && server_name="unknown"
  [[ $rc4 -ne 0 || -z "${client_isp:-}" || "$client_isp" == "null" ]] && client_isp="unknown"

  echo "${ts},${ping_ms},${server_id},${server_name},${client_isp}" | tee -a "$LOG"

  sleep "$INTERVAL"
done
EOF

chmod +x ping_log.sh
