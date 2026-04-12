#!/bin/bash
set -euo pipefail

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/examples/tool_chat_template_gemma4.jinja \
  -o /app/vllm/examples/tool_chat_template_gemma4.jinja

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/tool_parsers/gemma4_tool_parser.py \
  -o /usr/local/lib/python3.12/dist-packages/vllm/tool_parsers/gemma4_tool_parser.py

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
  --enable-auto-tool-choice \
  --reasoning-parser=gemma4 \
  --tool-call-parser=gemma4 \
  --chat-template=/app/vllm/examples/tool_chat_template_gemma4.jinja \
  --async-scheduling
