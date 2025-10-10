#!/usr/bin/env bash
URL="${1:-${URL:-http://221.148.45.104:5052/eth/v1/node/version}}"
INTERVAL="${INTERVAL:-1}"
TIMEOUT="${TIMEOUT:-3}"
WINDOW="${WINDOW:-120}"   # 롤링 윈도우 샘플 개수(초당 1회면 120초)

declare -a W=()
idx=0; count=0; sum=0; sumsq=0; min=999999; max=0

finish(){ echo; avg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')
  echo "==== Summary ===="; echo "URL: $URL"; echo "Requests: $count"
  echo "Average: ${avg} ms"; echo "Minimum: ${min} ms"; echo "Maximum: ${max} ms"; exit 0; }
trap finish INT TERM

echo "RTT log with rolling p95 (window=$WINDOW). Ctrl+C to stop."
echo "URL: $URL"; echo

while :; do
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  val=$(curl -w "%{time_total}\n" -sS --max-time "$TIMEOUT" --connect-timeout "$TIMEOUT" -o /dev/null "$URL" || true)

  if [[ "$val" =~ ^[0-9.]+$ ]]; then
    ms=$(awk -v v="$val" 'BEGIN{printf "%.3f", v*1000}')
    # 누적 통계
    ((count++)); sum=$(awk -v a="$sum" -v b="$ms" 'BEGIN{printf "%.6f", a+b}')
    sumsq=$(awk -v a="$sumsq" -v b="$ms" 'BEGIN{printf "%.6f", a+b*b}')
    (( $(awk -v a="$ms" -v b="$min" 'BEGIN{print (a<b)}') )) && min="$ms"
    (( $(awk -v a="$ms" -v b="$max" 'BEGIN{print (a>b)}') )) && max="$ms"

    # 롤링 윈도우 (고정 크기 배열)
    if (( ${#W[@]} < WINDOW )); then
      W+=("$ms")
    else
      old="${W[$idx]}"
      sum=$(awk -v a="$sum" -v b="$old" 'BEGIN{printf "%.6f", a-b}')
      sumsq=$(awk -v a="$sumsq" -v b="$old" 'BEGIN{printf "%.6f", a-b*b}')
      W[$idx]="$ms"
      sum=$(awk -v a="$sum" -v b="$ms" 'BEGIN{printf "%.6f", a+b}')
      sumsq=$(awk -v a="$sumsq" -v b="$ms" 'BEGIN{printf "%.6f", a+b*b}')
    fi
    idx=$(( (idx+1) % WINDOW ))

    # 롤링 p95 계산 (작은 N에서는 근사)
    sorted=$(printf "%s\n" "${W[@]}" | sort -n)
    n=${#W[@]}; k=$(awk -v n="$n" 'BEGIN{print int(0.95*n); if(n>0 && k<1) k=1}')
    rp95=$(printf "%s\n" $sorted | awk -v k="$k" 'NR==k{print; exit}')

    avg=$(awk -v s="$sum" -v c="${#W[@]}" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')
    printf "[%s] Cur: %-7.3f ms | W-avg(%3d): %-7s | W-p95: %-7s | Min: %-7.3f | Max: %-7.3f | N:%d\n" \
      "$ts" "$ms" "$n" "$avg" "$rp95" "$min" "$max" "$count"

    # 스파이크 경보: 현재값이 롤링 p95의 2배 이상이거나 절대 100ms 넘으면 경고
    if [[ -n "$rp95" ]]; then
      spike=$(awk -v c="$ms" -v p="$rp95" 'BEGIN{print (c>p*2 || c>100)}')
      if [[ "$spike" -eq 1 ]]; then
        echo "  -> ⚠️ spike detected: cur=${ms}ms (p95=${rp95}ms)" >&2
      fi
    fi
  else
    echo "[$ts] timeout/error"
  fi
  sleep "$INTERVAL"
done
