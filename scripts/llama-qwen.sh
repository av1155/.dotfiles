#!/usr/bin/env bash
# Launches llama-server with Qwen3.6-35B-A3B for agentic coding use
# Provides: thinking, preserve_thinking, vision, on port 1235

set -euo pipefail

MODEL_DIR="/Users/andreaventi/.cache/lm-studio/models/unsloth/Qwen3.6-35B-A3B-GGUF"

exec llama-server \
    --model "${MODEL_DIR}/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
    --mmproj "${MODEL_DIR}/mmproj-F32.gguf" \
    --alias qwen3.6-35b-a3b \
    --host 127.0.0.1 \
    --port 1235 \
    --ctx-size 262144 \
    --n-gpu-layers 999 \
    --flash-attn on \
    --jinja \
    --reasoning on \
    --reasoning-format deepseek \
    --chat-template-kwargs '{"preserve_thinking":true}' \
    --image-min-tokens 1024 \
    --temp 0.6 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.0 \
    --presence-penalty 0.0 \
    --threads 10 \
    --perf
