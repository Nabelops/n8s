#!/bin/bash
set -euo pipefail

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/examples/tool_chat_template_gemma4.jinja \
  -o /app/vllm/examples/tool_chat_template_gemma4.jinja

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/tool_parsers/gemma4_tool_parser.py \
  -o /usr/local/lib/python3.12/dist-packages/vllm/tool_parsers/gemma4_tool_parser.py

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/reasoning/gemma4_reasoning_parser.py \
  -o /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_reasoning_parser.py

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/reasoning/gemma4_utils.py \
  -o /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_utils.py

curl -sfL https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/reasoning/basic_parsers.py \
  -o /usr/local/lib/python3.12/dist-packages/vllm/reasoning/basic_parsers.py

# This vLLM build (e92668e83) doesn't invoke reasoning_parser.adjust_request(),
# so the gemma4 parser can't flip skip_special_tokens=False and <|channel>
# delimiters get stripped before extract_reasoning() sees them. Flip the
# default instead — safe here since this server only runs gemma-4.
sed -i 's/^\(\s*\)skip_special_tokens: bool = True$/\1skip_special_tokens: bool = False/' \
  /usr/local/lib/python3.12/dist-packages/vllm/entrypoints/openai/chat_completion/protocol.py

exec vllm serve google/gemma-4-E4B-it \
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
