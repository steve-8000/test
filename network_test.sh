cat > net_avg.sh <<'EOF'
#!/bin/bash
set -euo pipefail

N=5
OUT=results.json

# 결과 파일 초기화
: > "$OUT"

echo "Running $N speedtests..."
for i in $(seq 1 $N); do
  echo "[$i/$N] running..."
  # 특정 서버 고정하고 싶으면 --server <id> 추가
  speedtest --json >> "$OUT" || echo '{}' >> "$OUT"
  echo >> "$OUT"    # JSON 사이 개행
  sleep 10
done

echo "### 평균/표준편차 ###"
jq -s '
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
' "$OUT"
EOF

chmod +x net_avg.sh
./net_avg.sh
