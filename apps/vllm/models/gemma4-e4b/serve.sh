#!/bin/bash
set -euo pipefail

# The official vllm-openai-rocm:gemma4 image ships without these Gemma 4 parser
# files even though the recipe references them. We mount vendored copies via a
# ConfigMap (see apps/vllm/base/gemma4-parsers/SOURCE for the pinned vLLM SHA)
# and drop them into place on boot.

cp /parsers/tool_chat_template_gemma4.jinja /app/vllm/examples/tool_chat_template_gemma4.jinja
cp /parsers/gemma4_tool_parser.py           /usr/local/lib/python3.12/dist-packages/vllm/tool_parsers/gemma4_tool_parser.py
cp /parsers/gemma4_reasoning_parser.py      /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_reasoning_parser.py
cp /parsers/gemma4_utils.py                 /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_utils.py
cp /parsers/basic_parsers.py                /usr/local/lib/python3.12/dist-packages/vllm/reasoning/basic_parsers.py

# This vLLM build (e92668e83) doesn't invoke reasoning_parser.adjust_request(),
# so the gemma4 parser can't flip skip_special_tokens=False and <|channel>
# delimiters get stripped before extract_reasoning() sees them. Flip the
# default instead — safe here since this server only runs gemma-4.
sed -i 's/^\(\s*\)skip_special_tokens: bool = True$/\1skip_special_tokens: bool = False/' \
  /usr/local/lib/python3.12/dist-packages/vllm/entrypoints/openai/chat_completion/protocol.py

exec vllm serve google/gemma-4-E4B-it \
  --host=0.0.0.0 \
  --port=8000 \
  --max-model-len=65536 \
  --gpu-memory-utilization=0.92 \
  --kv-cache-dtype=fp8 \
  --dtype=bfloat16 \
  --enforce-eager \
  --max-num-seqs=16 \
  --attention-backend=TRITON_ATTN \
  --enable-auto-tool-choice \
  --reasoning-parser=gemma4 \
  --tool-call-parser=gemma4 \
  --chat-template=/app/vllm/examples/tool_chat_template_gemma4.jinja \
  --enable-prefix-caching \
  --async-scheduling
