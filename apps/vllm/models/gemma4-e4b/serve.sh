#!/bin/bash
set -euo pipefail

exec vllm serve google/gemma-4-E4B-it \
  --host=0.0.0.0 \
  --port=8000 \
  --max-model-len=65536 \
  --gpu-memory-utilization=0.92 \
  --kv-cache-dtype=fp8 \
  --dtype=bfloat16 \
  --max-num-seqs=16 \
  --attention-backend=TRITON_ATTN \
  --enable-auto-tool-choice \
  --reasoning-parser=gemma4 \
  --tool-call-parser=gemma4 \
  --enable-prefix-caching \
  --async-scheduling
