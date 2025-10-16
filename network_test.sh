#!/usr/bin/env bash
set -euo pipefail

# =============================
# Net Diagnose for Ubuntu (v2)
# - 설치(apt) + 측정 + 리포트 저장
# - Ookla speedtest 또는 speedtest-cli 자동 감지
# =============================

TARGETS=("1.1.1.1" "8.8.8.8" "google.com")
IPERF_HOST=""
INSTALL_ONLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets) IFS=',' read -r -a TARGETS <<< "${2:-}"; shift 2 ;;
    --iperf)   IPERF_HOST="${2:-}"; shift 2 ;;
    --install-only) INSTALL_ONLY="true"; shift 1 ;;
    *) echo "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

timestamp() { date +"%Y%m%d_%H%M%S"; }
NOW="$(timestamp)"
TXT_OUT="/tmp/net_diag_${NOW}.txt"
JSON_OUT="/tmp/net_diag_${NOW}.json"

log() { echo -e "$*" | tee -a "$TXT_OUT" >/dev/null; }
hr() { log "------------------------------------------------------------"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
  local base_pkgs=(
    mtr-tiny traceroute dnsutils ethtool iperf3 jq iproute2 net-tools
    wireless-tools iw curl iputils-tracepath
  )
  if ! need_cmd sudo && [[ $EUID -ne 0 ]]; then
    echo "sudo가 필요합니다. sudo 설치 또는 root 권한으로 실행하세요." >&2
    exit 1
  fi
  sudo apt-get update -y
  sudo apt-get install -y "${base_pkgs[@]}"

  # speedtest 계열: 둘 중 하나만 설치. (우선순위: Ookla > speedtest-cli)
  if ! need_cmd speedtest && ! need_cmd speedtest-cli; then
    # packagecloud.io/ookla 저장소가 있다면 보통 'speedtest' 설치 가능
    if sudo apt-get install -y speedtest; then
      :
    else
      sudo apt-get install -y speedtest-cli
    fi
  fi
}

# ---------------- Install ----------------
log "# Net Diagnose 시작: $(date)"
hr
log "필요 패키지 확인/설치 중..."

MISSING=()
for c in mtr traceroute dig ethtool ip iperf3 jq ss iw iwconfig curl tracepath; do
  need_cmd "$c" || MISSING+=("$c")
done
# speedtest 바이너리는 둘 중 하나만 있으면 OK
if ! need_cmd speedtest && ! need_cmd speedtest-cli; then
  MISSING+=("speedtest/cli")
fi

if ((${#MISSING[@]})); then
  log "부족한 도구: ${MISSING[*]} → apt로 설치합니다."
  apt_install
else
  log "필요 도구가 모두 설치되어 있습니다."
fi

if [[ "$INSTALL_ONLY" == "true" ]]; then
  log "설치만 수행하고 종료합니다. 리포트는 생성하지 않습니다."
  exit 0
fi

hr

# ---------------- Helpers ----------------
default_route_iface() { ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1);exit}}}'; }
default_route_src()   { ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){if($i=="src"){print $(i+1);exit}}}'; }

public_ip() {
  for url in "https://ifconfig.me" "https://api.ipify.org"; do
    curl -s --max-time 3 "$url" && return 0 || true
  done
  echo "N/A"
}

wifi_iface() { iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'; }

ping_stats() {
  local target="$1"
  ping -c 20 -i 0.2 -q "$target" 2>/dev/null | tail -n 2
}

dns_query_time_ms() {
  local q
  q="$(dig +tries=1 +stats +timeout=2 a google.com 2>/dev/null | awk '/Query time:/ {print $4}')"
  [[ -z "${q:-}" ]] && echo "N/A" || echo "$q"
}

tracepath_pmtu() { tracepath -n -m 20 1.1.1.1 2>/dev/null | awk '/pmtu/ {print $NF; exit}'; }

tcp_retrans() { ss -s 2>/dev/null | awk '/retrans:/ {gsub(/,/, "", $2); print $2; exit}'; }

link_speed_duplex() {
  local ifc="$1"
  ethtool "$ifc" 2>/dev/null | awk -F': ' '
    /Speed:/ {spd=$2}
    /Duplex:/ {dup=$2}
    END{ if(spd||dup){print spd"|"dup}else{print "N/A|N/A"} }
  '
}

wifi_link() {
  local ifc="$1"
  iwconfig "$ifc" 2>/dev/null | awk -F'  +' '
    /ESSID:/ {
      for(i=1;i<=NF;i++){
        if($i ~ /ESSID:/){ess=$i}
        if($i ~ /Link Quality/){lq=$i}
        if($i ~ /Signal level/){sig=$i}
      }
      gsub(/ESSID:/,"",ess); gsub(/"/,"",ess)
      print ess"|"lq"|"sig
      exit
    }
  '
}

# speedtest 실행기를 자동 감지해서 JSON 출력
speedtest_json() {
  if command -v speedtest >/dev/null 2>&1; then
    # Ookla 공식 CLI
    speedtest --accept-license --accept-gdpr -f json 2>/dev/null || true
  elif command -v speedtest-cli >/dev/null 2>&1; then
    # Python speedtest-cli (구버전은 bps일 수 있음)
    speedtest-cli --secure --json 2>/dev/null || true
  else
    echo ""
  fi
}

iperf3_json() { iperf3 -c "$1" -P 4 -t 10 --json 2>/dev/null || true; }

# ---------------- Collect ----------------
log "시스템/인터페이스 정보 수집..."
IFACE="$(default_route_iface || echo 'N/A')"
SRC_IP="$(default_route_src  || echo 'N/A')"
PUB_IP="$(public_ip)"
PMTU="$(tracepath_pmtu || echo 'N/A')"
TCP_RETRANS="$(tcp_retrans || echo 'N/A')"

SPEED="N/A"; DUPLEX="N/A"
if [[ "$IFACE" != "N/A" ]]; then
  LD="$(link_speed_duplex "$IFACE")"
  SPEED="${LD%%|*}"; DUPLEX="${LD##*|}"
fi

WIFI_IF="$(wifi_iface || true)"
WIFI_INFO="N/A"
if [[ -n "${WIFI_IF:-}" ]]; then
  WI="$(wifi_link "$WIFI_IF")"
  [[ -n "$WI" ]] && WIFI_INFO="$WI"
fi

DNS_MS="$(dns_query_time_ms)"

declare -A PING_RESULTS LOSS_RESULTS JITTER_RESULTS
log "지연/지터/손실 측정(ping 20회, 0.2s 간격)..."
for t in "${TARGETS[@]}"; do
  PS="$(ping_stats "$t")"
  LOSS="$(awk -F',' 'NR==1 {gsub(/ /,""); for(i=1;i<=NF;i++){ if($i ~ /%packetloss/){print $i} } }' <<<"$PS" | tr -d '%packetloss')"
  RTT="$(awk -F'=' 'NR==2 {print $2}' <<<"$PS" | tr -d ' ms')"
  AVG="$(awk -F'/' '{print $2}' <<<"$RTT")"
  MDEV="$(awk -F'/' '{print $4}' <<<"$RTT")"
  PING_RESULTS["$t"]="${AVG:-N/A}"
  LOSS_RESULTS["$t"]="${LOSS:-N/A}"
  JITTER_RESULTS["$t"]="${MDEV:-N/A}"
done

log "Speedtest(인터넷 대역폭) 실행..."
ST_JSON="$(speedtest_json)"
DL_MBPS="N/A"; UL_MBPS="N/A"; PING_MS="N/A"; ISP="N/A"; SNAME="N/A"

if [[ -n "${ST_JSON:-}" ]]; then
  if jq -e '.type?=="result"' >/dev/null 2>&1 <<<"$ST_JSON"; then
    # Ookla JSON (새 CLI)
    DL_MBPS="$(jq -r '.download.bandwidth // empty' <<<"$ST_JSON")"
    UL_MBPS="$(jq -r '.upload.bandwidth // empty' <<<"$ST_JSON")"
    PING_MS="$(jq -r '.ping.latency // empty' <<<"$ST_JSON")"
    ISP="$(jq -r '.isp // empty' <<<"$ST_JSON")"
    SNAME="$(jq -r '.server.name // empty' <<<"$ST_JSON")"
    # Ookla bandwidth는 bytes/s → Mb/s 변환
    if [[ "$DL_MBPS" =~ ^[0-9]+$ ]]; then DL_MBPS="$(awk -v v="$DL_MBPS" 'BEGIN{printf "%.2f", (v*8)/1000000}')"; fi
    if [[ "$UL_MBPS" =~ ^[0-9]+$ ]]; then UL_MBPS="$(awk -v v="$UL_MBPS" 'BEGIN{printf "%.2f", (v*8)/1000000}')"; fi
  else
    # speedtest-cli JSON
    DL_MBPS="$(jq -r '.download // empty' <<<"$ST_JSON")"
    UL_MBPS="$(jq -r '.upload // empty' <<<"$ST_JSON")"
    PING_MS="$(jq -r '.ping // empty' <<<"$ST_JSON")"
    ISP="$(jq -r '.client.isp // empty' <<<"$ST_JSON")"
    SNAME="$(jq -r '.server.sponsor // empty' <<<"$ST_JSON")"
    # 구버전은 bps → Mb/s 변환
    if [[ "$DL_MBPS" =~ ^[0-9]+$ ]] && (( DL_MBPS > 1000000 )); then DL_MBPS="$(awk -v v="$DL_MBPS" 'BEGIN{printf "%.2f", v/1000000}')"; fi
    if [[ "$UL_MBPS" =~ ^[0-9]+$ ]] && (( UL_MBPS > 1000000 )); then UL_MBPS="$(awk -v v="$UL_MBPS" 'BEGIN{printf "%.2f", v/1000000}')"; fi
  fi
fi

IPERF_JSON=""
if [[ -n "${IPERF_HOST:-}" ]]; then
  log "iperf3 병렬 4스트림 10초 테스트 실행... (서버: $IPERF_HOST)"
  IPERF_JSON="$(iperf3_json "$IPERF_HOST")"
fi

# ---------------- Report (Text) ----------------
hr
log "네트워크 진단 리포트"
hr
log "시간: $(date)"
log "기본 라우트 인터페이스: $IFACE"
log "내부 IP: $SRC_IP"
log "공인 IP: $PUB_IP"
log "링크 속도/듀플렉스(유선): $SPEED / $DUPLEX"
if [[ "$WIFI_INFO" != "N/A" ]]; then
  ESSID="$(cut -d'|' -f1 <<<"$WIFI_INFO")"
  LQ="$(cut -d'|' -f2 <<<"$WIFI_INFO")"
  SIG="$(cut -d'|' -f3 <<<"$WIFI_INFO")"
  log "무선 링크: ESSID=$ESSID, $LQ, $SIG"
fi
log "PMTU(경로 MTU 추정): $PMTU"
log "TCP 재전송 카운터(ss -s): ${TCP_RETRANS}"
log "DNS 질의 시간(google.com, ms): ${DNS_MS}"
hr

printf "%-25s %-12s %-12s %-12s\n" "Target" "Latency(ms)" "Jitter(ms)" "Loss(%)" | tee -a "$TXT_OUT" >/devnull
for t in "${TARGETS[@]}"; do
  printf "%-25s %-12s %-12s %-12s\n" "$t" "${PING_RESULTS[$t]}" "${JITTER_RESULTS[$t]}" "${LOSS_RESULTS[$t]}" | tee -a "$TXT_OUT" >/dev/null
done
hr

if [[ "$DL_MBPS" != "N/A" ]]; then
  DL_MBs="$(awk -v v="$DL_MBPS" 'BEGIN{printf "%.2f", v/8}')"
  UL_MBs="$(awk -v v="$UL_MBPS" 'BEGIN{printf "%.2f", v/8}')"
  log "Speedtest 서버: ${SNAME:-N/A} | ISP: ${ISP:-N/A}"
  log "다운로드: ${DL_MBPS} Mb/s (${DL_MBs} MB/s)"
  log "업로드:   ${UL_MBPS} Mb/s (${UL_MBs} MB/s)"
  log "레이턴시: ${PING_MS} ms"
else
  log "Speedtest 실패 또는 사용 불가"
fi

if [[ -n "${IPERF_JSON:-}" ]]; then
  SUM_BPS="$(jq -r '.end.sum_received.bits_per_second // .end.sum_sent.bits_per_second // empty' <<<"$IPERF_JSON" || true)"
  if [[ -n "${SUM_BPS:-}" ]]; then
    SUM_MBPS="$(awk -v v="$SUM_BPS" 'BEGIN{printf "%.2f", v/1000000}')"
    SUM_MBs="$(awk -v v="$SUM_BPS" 'BEGIN{printf "%.2f", v/8000000}')"
    log "iperf3 총합 수신 대역폭: ${SUM_MBPS} Mb/s (${SUM_MBs} MB/s)"
  else
    log "iperf3 결과 파싱 실패"
  fi
fi

hr
log "원시 리포트 저장 위치:"
log " - 텍스트: $TXT_OUT"
log " - JSON:   $JSON_OUT"
hr

# ---------------- Report (JSON) ----------------
{
  cat <<'JSON_HEAD'
{
  "timestamp": "__NOW__",
  "system": {
    "iface": "__IFACE__",
    "internal_ip": "__SRCIP__",
    "public_ip": "__PUBIP__",
    "link": {"speed":"__SPEED__","duplex":"__DUPLEX__"},
    "wifi": {"present":__WIFI_PRESENT__,"essid":"__WIFI_ESSID__","quality":"__WIFI_QUALITY__","signal":"__WIFI_SIGNAL__"},
    "pmtu":"__PMTU__",
    "tcp_retrans":"__TCP_RETRANS__",
    "dns_query_ms":"__DNSMS__"
  },
  "ping": {
JSON_HEAD

  for i in "${!TARGETS[@]}"; do
    t="${TARGETS[$i]}"
    printf '    "%s": {"latency_ms": %s, "jitter_ms": %s, "loss_percent": %s}' \
      "$t" \
      "$( [[ -n "${PING_RESULTS[$t]:-}" ]] && printf '%s' "${PING_RESULTS[$t]}" || echo 'null')" \
      "$( [[ -n "${JITTER_RESULTS[$t]:-}" ]] && printf '%s' "${JITTER_RESULTS[$t]}" || echo 'null')" \
      "$( [[ -n "${LOSS_RESULTS[$t]:-}" ]] && printf '%s' "${LOSS_RESULTS[$t]//%/}" || echo 'null')"
    (( i < ${#TARGETS[@]} - 1 )) && echo "," || echo
  done

  cat <<'JSON_MID'
  },
  "speedtest": {"server":"__SNAME__","isp":"__ISP__","download_Mbps":__DL__,"upload_Mbps":__UL__,"ping_ms":__STPING__},
  "iperf3": {"enabled":__IPERF_ENABLED__,"sum_Mbps":__IPERF_MBPS__}
}
JSON_MID
} | sed \
  -e "s/__NOW__/$(date -Is)/" \
  -e "s/__IFACE__/$(printf "%s" "$IFACE" | sed 's/[&/]/\\&/g')/" \
  -e "s/__SRCIP__/$(printf "%s" "$SRC_IP" | sed 's/[&/]/\\&/g')/" \
  -e "s/__PUBIP__/$(printf "%s" "$PUB_IP" | sed 's/[&/]/\\&/g')/" \
  -e "s/__SPEED__/$(printf "%s" "$SPEED" | sed 's/[&/]/\\&/g')/" \
  -e "s/__DUPLEX__/$(printf "%s" "$DUPLEX" | sed 's/[&/]/\\&/g')/" \
  -e "s/__PMTU__/$(printf "%s" "$PMTU" | sed 's/[&/]/\\&/g')/" \
  -e "s/__TCP_RETRANS__/$(printf "%s" "$TCP_RETRANS" | sed 's/[&/]/\\&/g')/" \
  -e "s/__DNSMS__/$(printf "%s" "$DNS_MS" | sed 's/[&/]/\\&/g')/" \
  -e "s/__SNAME__/$(printf "%s" "$SNAME" | sed 's/[&/]/\\&/g')/" \
  -e "s/__ISP__/$(printf "%s" "$ISP" | sed 's/[&/]/\\&/g')/" \
  -e "s/__DL__/$( [[ -n "$DL_MBPS" && "$DL_MBPS" != "N/A" ]] && echo "$DL_MBPS" || echo "null")/" \
  -e "s/__UL__/$( [[ -n "$UL_MBPS" && "$UL_MBPS" != "N/A" ]] && echo "$UL_MBPS" || echo "null")/" \
  -e "s/__STPING__/$( [[ -n "$PING_MS" && "$PING_MS" != "N/A" ]] && echo "$PING_MS" || echo "null")/" \
  -e "s/__IPERF_ENABLED__/$( [[ -n "$IPERF_JSON" ]] && echo "true" || echo "false")/" \
  -e "s/__IPERF_MBPS__/$( [[ -n "$IPERF_JSON" ]] && (jq -r '.end.sum_received.bits_per_second // .end.sum_sent.bits_per_second // empty' <<<"$IPERF_JSON" | awk '{if($1!=""){printf "%.2f", $1/1000000}else{print "null"}}') || echo "null")/" \
  -e "s/__WIFI_PRESENT__/$( [[ -n "${WIFI_IF:-}" ]] && echo "true" || echo "false")/" \
  -e "s/__WIFI_ESSID__/$( [[ -n "${WIFI_IF:-}" && "$WIFI_INFO" != "N/A" ]] && printf "%s" "$(cut -d'|' -f1 <<<"$WIFI_INFO")" | sed 's/[&/]/\\&/g' || echo "")/" \
  -e "s/__WIFI_QUALITY__/$( [[ -n "${WIFI_IF:-}" && "$WIFI_INFO" != "N/A" ]] && printf "%s" "$(cut -d'|' -f2 <<<"$WIFI_INFO")" | sed 's/[&/]/\\&/g' || echo "")/" \
  -e "s/__WIFI_SIGNAL__/$( [[ -n "${WIFI_IF:-}" && "$WIFI_INFO" != "N/A" ]] && printf "%s" "$(cut -d'|' -f3 <<<"$WIFI_INFO")" | sed 's/[&/]/\\&/g' || echo "")/" \
> "$JSON_OUT"

log "완료!"
