#!/usr/bin/env bash
# Launches llama-server with Qwen3.6-27B (dense) in *Instruct* (non-thinking)
# mode, tuned for OpenAI-compatible agentic tool-calling clients
# (TradingAgents, OpenCode, generic function-calling apps).
#
# Why 27B dense over 35B-A3B MoE for this profile:
#   - BenchLM agentic average 59.3 vs 51.5 (27B leads).
#   - Terminal-Bench 2.0  59.3 vs 51.5; SWE-bench Verified 77.2 vs 73.4.
#   - Q6_K_XL retains an order-of-magnitude lower KL-divergence vs BF16 than
#     the 35B-A3B Q4_K_XL we have on disk, so tool-call argument fidelity is
#     better.
#   - Dense routing avoids the per-token expert variance that occasionally
#     produces malformed JSON in MoE tool calls.
#
# Differences vs llama-qwen.sh (the thinking-coding profile, 35B-A3B):
#   - Thinking is disabled. Clients that don't echo `reasoning_content` back
#     across turns (e.g. langchain-openai's default path used by TradingAgents'
#     "ollama" provider) leak <think> traces into tool arguments and break
#     tool_call parsing. Instruct mode emits clean tool_calls only.
#   - mmproj vision tower is omitted. TradingAgents and most agentic flows
#     here are text-only.
#   - Sampler matches Unsloth's published Instruct/general-tasks preset
#     (temp 0.7, top_p 0.8, top_k 20, presence_penalty 1.5).
#   - 131,072 ctx covers TradingAgents Deep runs (5 debate rounds + 5 risk
#     rounds; final Portfolio Manager prompt accumulates ~50-60k tokens).
#     KV cache cost is ~8 GB; still fits in M4 Max headroom comfortably.
#   - --parallel 1 pins all requests to a single slot. Qwen3.6 has hybrid
#     SSM/attention layers whose recurrent state can't be shared via the
#     prompt cache; with parallel=4 every slot switch caused a full
#     `forcing full prompt re-processing due to lack of cache data` reprefill,
#     wasting 1-3 minutes per Deep run. TradingAgents is strictly sequential
#     so the extra slots provide no benefit, only thrash. Bump back to >=2
#     only if running multiple concurrent clients against this server.
#   - --cache-ram 16384 doubles the prompt cache from the 8 GB default so
#     long Deep runs stop hitting `cache size limit reached` and evicting
#     useful checkpoints. Costs system RAM only (not VRAM); fits the budget.
#   - Listens on 127.0.0.1:11434 (the canonical Ollama port) so the
#     TradingAgents interactive CLI's hardcoded Ollama entry reaches it
#     without patching. The thinking server on 1235 is unaffected.
#
# OpenAI base_url: http://127.0.0.1:11434/v1
# Served alias:    qwen3.6-27b-agent

set -euo pipefail

MODEL_DIR="/Users/andreaventi/.cache/lm-studio/models/unsloth/Qwen3.6-27B-GGUF"

exec llama-server \
    --model "${MODEL_DIR}/Qwen3.6-27B-UD-Q6_K_XL.gguf" \
    --alias qwen3.6-27b-agent \
    --host 127.0.0.1 \
    --port 11434 \
    --ctx-size 131072 \
    --parallel 1 \
    --cache-ram 16384 \
    --n-gpu-layers 999 \
    --flash-attn on \
    --jinja \
    --reasoning off \
    --temp 0.7 \
    --top-p 0.8 \
    --top-k 20 \
    --min-p 0.0 \
    --presence-penalty 1.5 \
    --repeat-penalty 1.0 \
    --threads 10 \
    --perf
