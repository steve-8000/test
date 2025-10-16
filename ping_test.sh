cat > eu_net_benchmark.sh <<'EOF'
#!/bin/bash
set -euo pipefail

# --- 설정 ---
REGIONS=("eu-west-1" "eu-central-1" "eu-north-1")
N=${N:-5}                 # 각 리전 speedtest 실행 횟수 (기본 5회). 필요하면 'N=3 ./eu_net_benchmark.sh'처럼 덮어쓰기
PAUSE=${PAUSE:-10}       # 반복 측정 사이 대기(초)
OUTDIR=${OUTDIR:-results_eu}
MTR_COUNT=${MTR_COUNT:-50}

mkdir -p "$OUTDIR"

# --- speedtest 서버 ID 자동 탐색 ---
# 각 AWS 리전에 대응하는 도시 키워드(대략적 매핑)
declare -A CITY_HINT
CITY_HINT["eu-west-1"]="Dublin|Ireland|IE"
CITY_HINT["eu-central-1"]="Frankfurt|DE"
CITY_HINT["eu-north-1"]="Stockholm|SE"

# 서버 리스트를 한 번만 가져옴(시간 절약)
SERVER_LIST_FILE="$OUTDIR/server_list.txt"
if [[ ! -s "$SERVER_LIST_FILE" ]]; then
  echo "# Fetching speedtest server list..."
  # 일부 환경에서 매우 길 수 있으므로 head -n 5000 정도로 자르고 싶다면 주석 해제
  speedtest --list > "$SERVER_LIST_FILE"
fi

get_server_id_for_region () {
  local region="$1"
  local pattern="${CITY_HINT[$region]}"
  if [[ -z "$pattern" ]]; then
    echo ""
    return 0
  fi
  # server list 형식 예: "12345) Provider (City, Country) [xx.xx km]"
  # 앞의 숫자 ID만 뽑는다.
  local id
  id=$(grep -E "$pattern" "$SERVER_LIST_FILE" | head -n 1 | awk -F')' '{print $1}' | tr -d ' ')
  echo "$id"
}

# --- 요약 계산용 jq 스니펫 ---
read -r -d '' JQ_SUMMARY <<'JQ'
  def mean(a): (a|length) as $n | if $n==0 then null else (a|add)/$n end;
  def stddev(a):
    (a|length) as $n
    | if $n==0 then null else
        (a|add) as $sum
        | (a|map(. * .) | add) as $sum2
        | (($sum2 / $n) - (($sum / $n) * ($sum / $n))) | sqrt
      end;

  ( [ .[] | select(.ping!=null)       | .ping ] )               as $pings
| ( [ .[] | select(.download!=null)   | (.download/1000000) ] ) as $downs  # Mbps
| ( [ .[] | select(.upload!=null)     | (.upload/1000000) ] )   as $ups    # Mbps
| {
    count:           ($pings|length),
    avg_ping_ms:     mean($pings),
    std_ping_ms:     stddev($pings),
    avg_down_mbps:   mean($downs),
    std_down_mbps:   stddev($downs),
    avg_up_mbps:     mean($ups),
    std_up_mbps:     stddev($ups)
  }
JQ

# --- MTR 요약 파서(마지막 홉 기준 평균 RTT/손실) ---
parse_mtr () {
  # mtr -rwc ... 출력에서 헤더 포함 표 형식이므로 마지막 라인의 "Loss%"와 "Avg"를 잡아온다
  # (컬럼 폭이 바뀔 수 있어 awk로 컬럼명 위치를 잡는 대신, 정규식으로 수치만 긁는다.)
  local file="$1"
  # 마지막 라인
  local last_line
  last_line=$(tail -n 1 "$file" 2>/dev/null || true)
  # Loss%: 소수 포함 숫자, Avg: 소수 포함 숫자
  # mtr -rw일 때 포맷: Host Loss% Snt Last Avg Best Wrst StDev
  # 안전하게 grep+awk 대신 perl-style regex로 숫자만 추출
  # 여기서는 간단히 공백 단위 필드에서 3=Loss%, 5=Avg로 가정 (일반적 디폴트 출력)
  # 포맷이 다른 경우를 대비해 방어적으로 처리
  local loss avg
  loss=$(echo "$last_line" | awk '{print $(NF-6)}' 2>/dev/null || echo "")
  avg=$(echo "$last_line"  | awk '{print $(NF-4)}' 2>/dev/null || echo "")
  echo "${loss:-NA},${avg:-NA}"
}

echo "### EU Region Benchmark: N=${N}, pause=${PAUSE}s, mtr=${MTR_COUNT} pings ###"

for region in "${REGIONS[@]}"; do
  target="ec2.${region}.amazonaws.com"
  echo
  echo "== Region: ${region} | Target: ${target} =="

  # 1) MTR (경로/지연/손실)
  mtr_out="${OUTDIR}/mtr_${region}.log"
  echo "# mtr -> ${mtr_out}"
  mtr -rwc "${MTR_COUNT}" "${target}" > "${mtr_out}" || true

  # 2) speedtest 반복
  json_out="${OUTDIR}/speedtest_${region}.json"
  : > "${json_out}"

  server_id="$(get_server_id_for_region "$region")"
  if [[ -n "${server_id}" ]]; then
    echo "# speedtest server-id: ${server_id}"
  else
    echo "# [WARN] No server-id match found for ${region}; using default auto-selected server."
  fi

  echo "# Running ${N} speedtests for ${region}..."
  for i in $(seq 1 "$N"); do
    echo "  - [${i}/${N}]"
    if [[ -n "${server_id}" ]]; then
      speedtest --server "${server_id}" --json >> "${json_out}" || echo '{}' >> "${json_out}"
    else
      speedtest --json >> "${json_out}" || echo '{}' >> "${json_out}"
    fi
    echo >> "${json_out}"
    sleep "${PAUSE}"
  done

  # 3) 리전별 요약(JSON)
  echo "# Region summary:"
  jq -s "${JQ_SUMMARY}" "${json_out}" | tee "${OUTDIR}/summary_${region}.json"

  # 4) 리전별 MTR 요약
  IFS=',' read -r loss_pct avg_rtt <<< "$(parse_mtr "${mtr_out}")"
  echo "# MTR(last hop): loss=${loss_pct}% avg_rtt_ms=${avg_rtt}"
done

# --- 전체 리전 비교표 (CSV 한 줄 출력) ---
# 헤더
echo
echo "region,count,avg_ping_ms,std_ping_ms,avg_down_mbps,std_down_mbps,avg_up_mbps,std_up_mbps,mtr_last_hop_loss_pct,mtr_last_hop_avg_rtt_ms"
for region in "${REGIONS[@]}"; do
  json="${OUTDIR}/summary_${region}.json"
  mtr="${OUTDIR}/mtr_${region}.log"
  IFS=',' read -r loss_pct avg_rtt <<< "$(parse_mtr "${mtr}")"
  jq -r --arg region "$region" --arg loss "$loss_pct" --arg avg "$avg_rtt" '
    [$region,
     .count,
     .avg_ping_ms, .std_ping_ms,
     .avg_down_mbps, .std_down_mbps,
     .avg_up_mbps, .std_up_mbps,
     $loss, $avg] | @csv
  ' "$json"
done

echo
echo "# Done. Raw logs in: ${OUTDIR}"
EOF

chmod +x eu_net_benchmark.sh
