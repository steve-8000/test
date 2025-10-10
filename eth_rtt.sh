#!/usr/bin/env bash
URL="${1:-${URL:-http://221.148.45.104:5052/eth/v1/node/version}}"
INTERVAL="${INTERVAL:-1}"
TIMEOUT="${TIMEOUT:-3}"
WINDOW="${WINDOW:-120}"   # 최근 120개 기준으로 W-avg(120) 계산

declare -a W=()
idx=0; count=0; sum=0; min=999999; max=0

# 지연 구간 카운터
b20_99=0       # 20ms ~ 99ms
b100_499=0     # 100ms ~ 499ms
b500p=0        # 500ms 이상

finish(){
  echo
  avg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')
  echo "==== Summary ===="
  echo "URL: $URL"
  echo "Requests: $count"
  echo "Average: ${avg} ms"
  echo "Minimum: ${min} ms"
  echo "Maximum: ${max} ms"
  echo "Buckets: 20-99ms=${b20_99}, 100-499ms=${b100_499}, 500+ms=${b500p}"
  exit 0
}
trap finish INT TERM

echo "RTT log with avg & W-avg($WINDOW). Ctrl+C to stop."
echo "URL: $URL"
echo "Buckets counted (non-overlapping): 20-99ms, 100-499ms, 500+ms"
echo

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

    # 지연 구간 카운팅 (중복 없도록 순차 if-elif)
    if   (( $(awk -v x="$ms" 'BEGIN{print (x>=20 && x<100)}') )); then
      b20_99=$((b20_99+1))
    elif (( $(awk -v x="$ms" 'BEGIN{print (x>=100 && x<500)}') )); then
      b100_499=$((b100_499+1))
    elif (( $(awk -v x="$ms" 'BEGIN{print (x>=500)}') )); then
      b500p=$((b500p+1))
    fi

    # 롤링 윈도우 (최근 120개 → W-avg(120))
    if (( ${#W[@]} < WINDOW )); then
      W+=("$ms")
    else
      W[$idx]="$ms"
    fi
    idx=$(( (idx+1) % WINDOW ))

    # 최근 120개 평균 계산
    n=${#W[@]}
    wavg=$(printf "%s\n" "${W[@]}" | awk '{sum+=$1} END{if(NR>0) printf "%.3f", sum/NR; else print "0.000"}')

    # 전체 평균
    gavg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')

    printf "[%s] Cur: %-7.3f ms | avg(all): %-7s | W-avg(%3d): %-7s | Min: %-7.3f | Max: %-7.3f | N:%d | 20-99:%d 100-499:%d 500+:%d\n" \
      "$ts" "$ms" "$gavg" "$n" "$wavg" "$min" "$max" "$count" "$b20_99" "$b100_499" "$b500p"

  else
    echo "[$ts] timeout/error"
  fi

  sleep "$INTERVAL"
done
