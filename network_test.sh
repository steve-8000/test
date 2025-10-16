#!/bin/bash
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
  def mean(stream): ( [stream] | add / length );
  def variance(stream):
    ( [stream] ) as $a
    | ($a | add / length) as $m
    | ( [ foreach $a[] as $x (0; .; .), ((($x - $m) * ($x - $m))) ] | add / length );
  def stddev(stream): (variance(stream)) | sqrt;

  ( [ .[] | select(.ping!=null)      | .ping ] )              as $pings
| ( [ .[] | select(.download!=null) | (.download/1000000) ] ) as $downs
| ( [ .[] | select(.upload!=null)   | (.upload/1000000) ] )   as $ups
| {
    count:        ($pings|length),
    avg_ping_ms:  ($pings | add / length),
    std_ping_ms:  (stddev($pings[])),
    avg_down_mbps:($downs | add / length),
    std_down_mbps:(stddev($downs[])),
    avg_up_mbps:  ($ups   | add / length),
    std_up_mbps:  (stddev($ups[]))
  }
' "$OUT"
