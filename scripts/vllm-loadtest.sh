#!/usr/bin/env bash
set -euo pipefail

# Saturates vLLM with concurrent streamed requests while sampling
# runtime metrics from the pod, so KV cache headroom can be sized
# against observed peak rather than the idle floor.

URL="${VLLM_URL:-https://vllm.tailf95ba8.ts.net}"
MODEL="${VLLM_MODEL:-google/gemma-4-26B-A4B-it}"
NAMESPACE="${VLLM_NAMESPACE:-vllm}"
CONCURRENCY="${CONCURRENCY:-16}"
MAX_TOKENS="${MAX_TOKENS:-2000}"
SAMPLE_INTERVAL="${SAMPLE_INTERVAL:-5}"
SAMPLE_COUNT="${SAMPLE_COUNT:-60}"
PROMPT="${PROMPT:-Write a detailed 2000 word story about a raccoon astronaut exploring a ringed planet. Include dialogue and vivid descriptions.}"

OUTDIR="$(mktemp -d)"
METRICS="$OUTDIR/metrics.tsv"
trap 'rm -rf "$OUTDIR"' EXIT

echo "vLLM load test"
echo "  url:         $URL"
echo "  model:       $MODEL"
echo "  concurrency: $CONCURRENCY"
echo "  max_tokens:  $MAX_TOKENS"
echo "  namespace:   $NAMESPACE"
echo "  outdir:      $OUTDIR"
echo

echo "preflight: GET /v1/models"
curl -fsS --max-time 10 "$URL/v1/models" >/dev/null
echo "  ok"
echo

body=$(jq -n --arg model "$MODEL" --arg content "$PROMPT" --argjson max_tokens "$MAX_TOKENS" \
  '{model:$model, stream:true, max_tokens:$max_tokens, messages:[{role:"user", content:$content}]}')

echo "launching $CONCURRENCY concurrent streamed requests..."
for i in $(seq 1 "$CONCURRENCY"); do
  curl -sN --max-time 600 "$URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$body" \
    > "$OUTDIR/out-$i.sse" 2>&1 &
done
LOAD_PIDS=$(jobs -p)

echo "sampling vllm metrics every ${SAMPLE_INTERVAL}s (up to ${SAMPLE_COUNT} samples)"
echo -e "t\trunning\twaiting\tkv_cache_pct\tpreemptions" > "$METRICS"

peak_kv=0
peak_running=0
peak_waiting=0
peak_preempt=0
saw_load=0
for t in $(seq 1 "$SAMPLE_COUNT"); do
  raw=$(kubectl exec -n "$NAMESPACE" deploy/vllm -- \
    curl -sf --max-time 5 localhost:8000/metrics 2>/dev/null || true)

  running=$(printf '%s\n' "$raw"   | awk -F'[ }]' '/^vllm:num_requests_running{/ {print $NF; exit}')
  waiting=$(printf '%s\n' "$raw"   | awk -F'[ }]' '/^vllm:num_requests_waiting{/ {print $NF; exit}')
  kvpct=$(printf '%s\n' "$raw"     | awk -F'[ }]' '/^vllm:kv_cache_usage_perc{/ {print $NF; exit}')
  preempt=$(printf '%s\n' "$raw"   | awk -F'[ }]' '/^vllm:num_preemptions_total{/ {print $NF; exit}')

  running=${running:-0}; waiting=${waiting:-0}; kvpct=${kvpct:-0}; preempt=${preempt:-0}

  printf '%ds\t%s\t%s\t%s\t%s\n' "$((t*SAMPLE_INTERVAL))" "$running" "$waiting" "$kvpct" "$preempt" \
    | tee -a "$METRICS"

  awk -v a="$kvpct"   -v b="$peak_kv"      'BEGIN{exit !(a+0 > b+0)}' && peak_kv=$kvpct
  awk -v a="$running" -v b="$peak_running" 'BEGIN{exit !(a+0 > b+0)}' && peak_running=$running
  awk -v a="$waiting" -v b="$peak_waiting" 'BEGIN{exit !(a+0 > b+0)}' && peak_waiting=$waiting
  awk -v a="$preempt" -v b="$peak_preempt" 'BEGIN{exit !(a+0 > b+0)}' && peak_preempt=$preempt

  [ "$(echo "$running" | awk '{print ($1+0 > 0)}')" = "1" ] && saw_load=1

  if [ "$saw_load" = "1" ] && [ "$(echo "$running" | awk '{print ($1+0 == 0)}')" = "1" ]; then
    echo "all requests drained"
    break
  fi

  sleep "$SAMPLE_INTERVAL"
done

echo
echo "waiting for in-flight curls to finish..."
wait $LOAD_PIDS 2>/dev/null || true

completed=0
for f in "$OUTDIR"/out-*.sse; do
  grep -q '"finish_reason"' "$f" 2>/dev/null && completed=$((completed+1)) || true
done

peak_kv_pct=$(awk -v v="$peak_kv" 'BEGIN{printf "%.2f", v*100}')

echo
echo "=== summary ==="
printf '  peak kv_cache_usage:        %s%%\n' "$peak_kv_pct"
printf '  peak num_requests_running:  %s\n' "$peak_running"
printf '  peak num_requests_waiting:  %s\n' "$peak_waiting"
printf '  total preemptions:          %s\n' "$peak_preempt"
printf '  streamed responses completed: %s / %s\n' "$completed" "$CONCURRENCY"
if [ "$saw_load" = "0" ]; then
  echo "  WARNING: never observed running>0; load never landed (check connectivity)"
fi
echo
echo "metrics log: $METRICS (kept until script exits; copy elsewhere to persist)"
cp "$METRICS" "./vllm-loadtest-$(date +%Y%m%d-%H%M%S).tsv"
echo "copied log to $(ls -1t ./vllm-loadtest-*.tsv | head -1)"
