#!/bin/bash
set -euo pipefail
N=5
OUT=results.json

: > "$OUT"
echo "Running $N speedtests..."
for i in $(seq 1 $N); do
  echo "[$i/$N] running..."
  speedtest --json >> "$OUT" || echo '{}' >> "$OUT"
  echo >> "$OUT"
  sleep 10
done

echo "### 평균/표준편차 ###"
jq -s '
  def mean(a): (a|add) / (a|length);
  def stddev(a):
    (a|length) as $n
    | (a|add) as $sum
    | (a|map(. * .) | add) as $sum2
    | (($sum2 / $n) - (($sum / $n) * ($sum / $n))) | sqrt;

  ( [ .[] | select(.ping!=null)       | .ping ] )               as $pings
| ( [ .[] | select(.download!=null)   | (.download/1000000) ] ) as $downs
| ( [ .[] | select(.upload!=null)     | (.upload/1000000) ] )   as $ups
| {
    count:           ($pings|length),
    avg_ping_ms:     (mean($pings)),
    std_ping_ms:     (stddev($pings)),
    avg_down_mbps:   (mean($downs)),
    std_down_mbps:   (stddev($downs)),
    avg_up_mbps:     (mean($ups)),
    std_up_mbps:     (stddev($ups))
  }
' "$OUT"
