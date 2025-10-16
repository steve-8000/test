cat > eu_net_benchmark_min.sh <<'EOF'
#!/bin/bash
set -euo pipefail

REGIONS=("eu-west-1" "eu-central-1" "eu-north-1")
N=${N:-5}
PAUSE=${PAUSE:-10}
OUTDIR=${OUTDIR:-results_eu}
MTR_COUNT=${MTR_COUNT:-50}

mkdir -p "$OUTDIR"

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
| ( [ .[] | select(.download!=null)   | (.download/1000000) ] ) as $downs
| ( [ .[] | select(.upload!=null)     | (.upload/1000000) ] )   as $ups
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

parse_mtr () {
  # mtr 보고서 마지막 행에서 Loss%와 Avg를 추정 추출
  local file="$1"
  local last_line
  last_line=$(tail -n 1 "$file" 2>/dev/null || true)
  # 보편 포맷: Host Loss% Snt Last Avg Best Wrst StDev
  # NF-6 ~ NF-4 휴리스틱 (환경에 따라 다르면 NA 처리)
  local loss avg
  loss=$(echo "$last_line" | awk '{print $(NF-6)}' 2>/dev/null || echo "")
  avg=$(echo "$last_line"  | awk '{print $(NF-4)}' 2>/dev/null || echo "")
  [[ -z "$loss" ]] && loss="NA"
  [[ -z "$avg"  ]] && avg="NA"
  echo "${loss},${avg}"
}

echo "### EU Region Benchmark(min): N=${N}, pause=${PAUSE}s, mtr=${MTR_COUNT} ###"

for region in "${REGIONS[@]}"; do
  target="ec2.${region}.amazonaws.com"
  echo
  echo "== ${region} (${target}) =="

  mtr_out="${OUTDIR}/mtr_${region}.log"
  json_out="${OUTDIR}/speedtest_${region}.json"
  : > "${json_out}"

  echo "# mtr -> ${mtr_out}"
  mtr -rwc "${MTR_COUNT}" "${target}" > "${mtr_out}" || true

  echo "# speedtest x${N} (auto server)"
  for i in $(seq 1 "$N"); do
    echo "  - [${i}/${N}]"
    speedtest --json >> "${json_out}" || echo '{}' >> "${json_out}"
    echo >> "${json_out}"
    sleep "${PAUSE}"
  done

  echo "# summary(${region}):"
  jq -s "${JQ_SUMMARY}" "${json_out}" | tee "${OUTDIR}/summary_${region}.json"

  IFS=',' read -r loss_pct avg_rtt <<< "$(parse_mtr "${mtr_out}")"
  echo "# MTR(last hop): loss=${loss_pct}% avg_rtt_ms=${avg_rtt}"
done

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
echo "# Done -> ${OUTDIR}"
EOF

chmod +x eu_net_benchmark_min.sh
N=3 PAUSE=5 ./eu_net_benchmark_min.sh
