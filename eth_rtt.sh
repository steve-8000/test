#!/usr/bin/env bash
URL="${1:-${URL:-http://221.148.45.104:5052/eth/v1/node/version}}"
INTERVAL="${INTERVAL:-1}"
TIMEOUT="${TIMEOUT:-3}"
WINDOW="${WINDOW:-120}"   # 최근 120개 기준으로 W-avg(120) 계산

declare -a W=()
idx=0; count=0; sum=0; min=999999; max=0

finish(){
  echo
  avg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')
  echo "==== Summary ===="
  echo "URL: $URL"
  echo "Requests: $count"
  echo "Average: ${avg} ms"
  echo "Minimum: ${min} ms"
  echo "Maximum: ${max} ms"
  exit 0
}
trap finish INT TERM

echo "RTT log with avg & W-avg($WINDOW). Ctrl+C to stop."
echo "URL: $URL"; echo

while :; do
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  val=$(curl -w "%{time_total}\n" -sS --max-time "$TIMEOUT" --connect-timeout "$TIMEOUT" -o /dev/null "$URL" || true)

  if [[ "$val" =~ ^[0-9.]+$ ]]; then
    ms=$(awk -v v="$val" 'BEGIN{printf "%.3f", v*1000}')

    # 전체 평균 계산용 누적
    ((count++))
    sum=$(awk -v a="$sum" -v b="$ms" 'BEGIN{printf "%.6f", a+b}')
    (( $(awk -v a="$ms" -v b="$min" 'BEGIN{print (a<b)}') )) && min="$ms"
    (( $(awk -v a="$ms" -v b="$max" 'BEGIN{print (a>b)}') )) && max="$ms"

    # 롤링 윈도우 (최근 120개)
    if (( ${#W[@]} < WINDOW )); then
      W+=("$ms")
    else
      W[$idx]="$ms"
    fi
    idx=$(( (idx+1) % WINDOW ))

    # 최근 120개 평균 계산 (이전의 W-p95 대신 W-avg(120))
    n=${#W[@]}
    wavg=$(printf "%s\n" "${W[@]}" | awk '{sum+=$1} END{if(NR>0) printf "%.3f", sum/NR; else print "0.000"}')

    # 전체 평균
    gavg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')

    printf "[%s] Cur: %-7.3f ms | avg(all): %-7s | W-avg(%3d): %-7s | Min: %-7.3f | Max: %-7.3f | N:%d\n" \
      "$ts" "$ms" "$gavg" "$n" "$wavg" "$min" "$max" "$count"

  else
    echo "[$ts] timeout/error"
  fi

  sleep "$INTERVAL"
done
