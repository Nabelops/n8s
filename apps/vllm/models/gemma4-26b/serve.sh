#!/bin/bash
set -euo pipefail

# TEMPORARY: pod is running as an inspection shell against vllm-openai-rocm:v0.19.1.
# Use `kubectl -n vllm exec deploy/vllm -- <cmd>` to verify arch support for
# gemma4, qwen3.6, and Strix Halo before re-enabling model serving.
#
# Example checks:
#   python -c "import vllm; print(vllm.__version__)"
#   python -c "from vllm.model_executor.models import ModelRegistry; \
#              print([m for m in ModelRegistry.get_supported_archs() \
#                     if 'qwen3' in m.lower() or 'gemma' in m.lower()])"
#   rocminfo | head -40

# The gemma4-specific parser shims below were for the :gemma4 image only.
# v0.19.1 has a different vllm tree layout — leaving these commented until we
# decide whether to keep running gemma4 on the new image at all.
#
# cp /parsers/tool_chat_template_gemma4.jinja /app/vllm/examples/tool_chat_template_gemma4.jinja
# cp /parsers/gemma4_tool_parser.py           /usr/local/lib/python3.12/dist-packages/vllm/tool_parsers/gemma4_tool_parser.py
# cp /parsers/gemma4_reasoning_parser.py      /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_reasoning_parser.py
# cp /parsers/gemma4_utils.py                 /usr/local/lib/python3.12/dist-packages/vllm/reasoning/gemma4_utils.py
# cp /parsers/basic_parsers.py                /usr/local/lib/python3.12/dist-packages/vllm/reasoning/basic_parsers.py
#
# sed -i 's/^\(\s*\)skip_special_tokens: bool = True$/\1skip_special_tokens: bool = False/' \
#   /usr/local/lib/python3.12/dist-packages/vllm/entrypoints/openai/chat_completion/protocol.py

# exec vllm serve google/gemma-4-26B-A4B-it \
#   --host=0.0.0.0 \
#   --port=8000 \
#   --max-model-len=65536 \
#   --gpu-memory-utilization=0.65 \
#   --kv-cache-dtype=fp8 \
#   --dtype=bfloat16 \
#   --max-num-seqs=16 \
#   --attention-backend=TRITON_ATTN \
#   --enable-auto-tool-choice \
#   --reasoning-parser=gemma4 \
#   --tool-call-parser=gemma4 \
#   --chat-template=/app/vllm/examples/tool_chat_template_gemma4.jinja \
#   --enable-prefix-caching \
#   --async-scheduling

exec sleep infinity
