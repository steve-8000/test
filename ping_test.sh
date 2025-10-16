cat > ping_log.sh <<'EOF'
#!/bin/bash
set -euo pipefail

LOG="ping_results.log"
SERVER_ID="${SERVER_ID:-}"   # 환경변수로도 주입 가능. 비우면 자동선택
INTERVAL="${INTERVAL:-60}"   # 초 단위 간격 (기본 60)

# ---- 유틸: 헤더 1회만 쓰기 ----
if [[ ! -f "$LOG" ]]; then
  echo "time,ping_ms,server_id,server_name,client_isp" > "$LOG"
fi

# ---- 유틸: Ctrl+C 시 메시지 ----
trap 'echo "stopped." >&2; exit 0' INT TERM

# ---- 어떤 speedtest 인지 감지 (ookla / sivel) ----
detect_cli() {
  # ookla: "Speedtest by Ookla" 문구가 version에 보임.
  if speedtest --version 2>/dev/null | grep -qi "ookla"; then
    echo "ookla"
    return
  fi
  # sivel: python 기반, --version 문자열이 다름.
  if speedtest --version 2>/dev/null | grep -qi "speedtest-cli"; then
    echo "sivel"
    return
  fi
  # 최후의 수단: --help에 -f json이 있으면 ookla로 간주
  if speedtest --help 2>/dev/null | grep -q -- "-f.*json"; then
    echo "ookla"
  else
    echo "sivel"
  fi
}

CLI=$(detect_cli)
echo "using CLI: $CLI (interval=${INTERVAL}s, server_id=${SERVER_ID:-auto})" >&2

# ---- 1회 측정 함수 (실패해도 JSON 한 줄 보장) ----
run_once() {
  local raw err rc
  if [[ "$CLI" == "ookla" ]]; then
    # ookla: -f json, --server-id, 라이선스/개인정보 동의 필요할 수 있음
    if [[ -n "${SERVER_ID}" ]]; then
      raw=$(speedtest -f json --server-id "${SERVER_ID}" --accept-license --accept-gdpr 2>/dev/null) || true
    else
      raw=$(speedtest -f json --accept-license --accept-gdpr 2>/dev/null) || true
    fi
  else
    # sivel: --json, --server
    if [[ -n "${SERVER_ID}" ]]; then
      raw=$(speedtest --json --server "${SERVER_ID}" 2>/dev/null) || true
    else
      raw=$(speedtest --json 2>/dev/null) || true
    fi
  fi

  if [[ -z "${raw:-}" ]]; then
    # speedtest 자체가 깨졌을 때도 한 줄 반환
    echo '{"error":"empty_output"}'
  else
    echo "$raw"
  fi
}

# ---- 메인 루프 ----
while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  json=$(run_once)

  # ping(ms) 추출: sivel(.ping) 또는 ookla(.ping.latency)
  ping_ms=$(jq -r '(.ping // .ping.latency) // empty' <<<"$json")
  # 서버 정보: sivel(.server.sponsor / .server.id / .server.name), ookla(.server.name / .server.id)
  server_id=$(jq -r '(.server.id // .server.id) // empty' <<<"$json")
  server_name=$(jq -r '(.server.name // .server.sponsor // .server.host) // empty' <<<"$json")
  client_isp=$(jq -r '(.client.isp // .isp // .client.name) // empty' <<<"$json")

  # 수치가 없으면 "NA"로 채움 (로그가 끊기지 않도록)
  [[ -z "${ping_ms}" || "${ping_ms}" == "null" ]] && ping_ms="NA"
  [[ -z "${server_id}" || "${server_id}" == "null" ]] && server_id="${SERVER_ID:-auto}"
  [[ -z "${server_name}" || "${server_name}" == "null" ]] && server_name="unknown"
  [[ -z "${client_isp}" || "${client_isp}" == "null" ]] && client_isp="unknown"

  line="${ts},${ping_ms},${server_id},${server_name},${client_isp}"
  echo "$line" | tee -a "$LOG"

  sleep "$INTERVAL"
done
EOF

chmod +x ping_log.sh
