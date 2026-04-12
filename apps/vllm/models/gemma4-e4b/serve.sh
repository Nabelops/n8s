#!/bin/bash
set -euo pipefail

# E4B uses its own embedded chat template from tokenizer_config.json.
# Do NOT pull the gemma4 chat template / tool parser from vllm main — those
# target the 26B A4B variant and break E4B's conversation format.
# Re-add --chat-template / --reasoning-parser / --tool-call-parser only if
# you confirm E4B-specific versions exist and match this tokenizer.

exec vllm serve google/gemma-4-E4B \
  --host=0.0.0.0 \
  --port=8000 \
  --max-model-len=131072 \
  --gpu-memory-utilization=0.90 \
  --kv-cache-dtype=fp8 \
  --dtype=bfloat16 \
  --enforce-eager \
  --max-num-seqs=8 \
  --attention-backend=TRITON_ATTN \
  --async-scheduling
