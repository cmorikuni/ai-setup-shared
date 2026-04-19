#!/usr/bin/env zsh
# AI Dev Setup — zshrc snippets
#
# Source this from your ~/.zshrc:
#   source ~/ai-setup/zshrc-snippets.sh
#
# Edit the CONFIG block below to match your environment.

# ─── CONFIG (edit these) ──────────────────────────────────────────────────────

# Path to your main git repo (the one you create worktrees from)
AI_REPO=~/Repos/your-main-repo

# Where git worktrees are checked out
AI_WORKTREES_DIR=~/Repos/worktrees

# Path to your wiki / second brain (Obsidian vault or plain folder)
AI_WIKI=~/wiki

# Path to the ai-orchestrator repo
AI_ORCHESTRATOR=~/ai-setup/ai-orchestrator

# Path to the ollama proxy script
AI_PROXY=~/ai-setup/bin/ollama-proxy.py

# ─── OLLAMA ───────────────────────────────────────────────────────────────────

# Allow multiple models loaded simultaneously
export OLLAMA_MAX_LOADED_MODELS=2

# Allow parallel requests
export OLLAMA_NUM_PARALLEL=2

# Keep models in VRAM
export OLLAMA_KEEP_ALIVE=10m

# Flash Attention (beneficial on Apple Silicon)
export OLLAMA_FLASH_ATTENTION=1

# 8-bit context cache quantization (~50% VRAM savings)
export OLLAMA_KV_CACHE_TYPE=q8_0

# Create an optimized local variant of qwen3-coder for your machine
# Run once after `ollama pull qwen3-coder:latest`
create-qwen3-coder-local() {
    echo ">> Creating optimized qwen3-coder model (32k context)..."
    local modelfile=$(mktemp)
    printf '%s\n' \
        'FROM qwen3-coder:latest' \
        'PARAMETER num_ctx 32768' \
        'PARAMETER num_predict 4096' \
        'PARAMETER temperature 0' \
        'PARAMETER num_thread 8' \
        > "$modelfile"
    ollama create qwen3-coder-local -f "$modelfile"
    rm "$modelfile"
}

# Create an optimized mistral-small variant
# Run once after `ollama pull mistral-small:24b`
create-mistral-small-local() {
    echo ">> Creating optimized mistral-small model (32k context)..."
    local modelfile=$(mktemp)
    printf '%s\n' \
        'FROM mistral-small:24b' \
        'PARAMETER num_ctx 32768' \
        'PARAMETER num_predict 4096' \
        'PARAMETER temperature 0' \
        'PARAMETER num_thread 8' \
        > "$modelfile"
    ollama create mistral-small-local -f "$modelfile"
    rm "$modelfile"
}

# ─── CLAUDE + LOCAL LLM ───────────────────────────────────────────────────────

# Run Claude Code with permissions bypass (trust yourself)
claude-skip-permissions() {
    claude --dangerously-skip-permissions
}

# Run Claude Code backed by a local Ollama model instead of the cloud API.
# Usage: oclaude [model]
#   oclaude           → qwen3-coder-local (default, strongest)
#   oclaude mistral   → mistral-small-local (faster)
#   oclaude 7b        → qwen2.5-coder:7b (lightweight)
#   oclaude <name>    → any ollama model by name
oclaude() {
    local target_model="$1"
    local model_name

    case "$target_model" in
        "7b")
            model_name="qwen2.5-coder:7b"
            ;;
        "mistral")
            model_name="mistral-small-local"
            ;;
        ""|"pro")
            model_name="qwen3-coder-local:latest"
            ;;
        *)
            model_name="$target_model"
            ;;
    esac

    ensure-proxy

    echo ">> Starting Local Claude ($model_name) in: $(basename "$(pwd)")"

    (
        export ANTHROPIC_BASE_URL="http://localhost:11435"
        export ANTHROPIC_API_KEY="ollama"
        export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model_name"
        export ANTHROPIC_DEFAULT_SONNET_MODEL="$model_name"
        export ANTHROPIC_DEFAULT_OPUS_MODEL="$model_name"
        export CLAUDE_CODE_MAX_TOKENS=8192
        export CLAUDE_CODE_TIMEOUT=300000
        export DISABLE_TELEMETRY=1

        claude --model "$model_name" --dangerously-skip-permissions --bare
    )
}

# ─── AI ORCHESTRATOR ──────────────────────────────────────────────────────────

# Start the Ollama → Anthropic proxy if not already running
ensure-proxy() {
    if ! lsof -i :11435 &>/dev/null; then
        echo ">> Starting Ollama proxy on :11435..."
        python3 "$AI_PROXY" &>/tmp/ollama-proxy.log &
        sleep 1
    fi
}

# Run the AI orchestrator against a spec file
# Usage: run-ai [spec-file]  (default: .ai-spec.md in cwd)
run-ai() {
    local spec="${1:-.ai-spec.md}"

    if [[ ! -f "$spec" ]]; then
        echo "Spec not found: $spec"
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Not in git repo"
        return 1
    fi

    ensure-proxy

    export LLM_PROXY_URL="http://localhost:11435/v1/chat/completions"

    python3 "$AI_ORCHESTRATOR/orchestrator.py" "$spec"
}

# Write a spec to .ai-spec.md (Ctrl+D to finish)
ai-spec() {
    cat > .ai-spec.md
}

# Shortcut: write spec then immediately run
ai-run() {
    ai-spec
    run-ai
}

# ─── GIT WORKTREES ────────────────────────────────────────────────────────────
#
# wt <branch>          — create or open a worktree
# wt -d <branch>       — delete a worktree and its branch
#
# Adapt the body to your team's workflow. The key behaviors:
#   - Creates a per-worktree Claude memory dir in the wiki
#   - Creates a CLAUDE.local.md with worktree context for Claude
#   - Opens VS Code at the worktree path
#
# You likely need to customize:
#   - The VS Code tasks.json symlink section (or remove it)
#   - The wiki memory path structure

wt() {
    local repo="$AI_REPO"

    # --- DELETE MODE ---
    if [[ "$1" == "-d" || "$1" == "--delete" ]]; then
        local branch="${2:?branch name required for deletion}"
        local target_dir="$AI_WORKTREES_DIR/$branch"

        local wt_path="$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")"
        local wt_slug=$(echo "$wt_path" | sed 's|[/._]|-|g')
        local memory_project="$AI_WIKI/claude/projects/$wt_slug"

        echo "== Deleting Worktree: $branch =="
        git -C "$repo" worktree remove "$target_dir" --force 2>/dev/null || echo "Directory already gone."

        if git -C "$repo" branch -D "$branch" 2>/dev/null; then
            echo "== Deleted branch: $branch =="
        fi

        if [ -d "$memory_project" ]; then
            rm -rf "$memory_project"
            echo "== Removed Claude memory: $wt_slug =="
        fi
        return 0
    fi

    # --- CREATE/OPEN MODE ---
    local branch="${1:?branch name required}"
    local base="${2:-main}"
    local target_dir="$AI_WORKTREES_DIR/$branch"

    # 1. Check/Create Worktree
    if [ -d "$target_dir" ]; then
        echo "== Worktree exists, opening VS Code =="
    else
        echo "== Updating $base and creating worktree: $branch =="
        git -C "$repo" fetch origin "$base":"$base"
        git -C "$repo" worktree add "$target_dir" "$branch" 2>/dev/null \
            || git -C "$repo" worktree add "$target_dir" -b "$branch" "$base"
    fi

    # 2. Setup AI Project Memory (Wiki)
    local wt_path wt_slug project_root
    wt_path="$(realpath "$target_dir")"
    wt_slug=$(echo "$wt_path" | sed 's|[/._]|-|g')
    project_root="$AI_WIKI/claude/projects/$wt_slug"

    mkdir -p "$project_root/memory"

    # Write a branch-specific context file for Claude
    {
        echo "# Worktree Context: $branch"
        echo "- You are working in a git worktree at $target_dir."
        echo "- Project memory is synced to the wiki at: $project_root"
        echo "- Core project instructions are in the parent repo's CLAUDE.md."
    } > "$target_dir/CLAUDE.local.md"

    echo "----------------------------------------"
    echo "OK Worktree: $branch"
    echo "   'claude'  -> Anthropic Cloud"
    echo "   'oclaude' -> Ollama Local"
    echo "----------------------------------------"

    # 3. Open in VS Code
    open -a "Visual Studio Code" "$target_dir"
}

# Tab completion for wt
_wt_complete() {
    local repo="$AI_REPO"
    local -a branches flags

    flags=('-d:Delete worktree and branch' '--delete:Delete worktree and branch')

    if [[ $CURRENT -eq 2 ]]; then
        branches=(${(f)"$(git -C "$repo" branch -a --format='%(refname:short)' 2>/dev/null | sed 's|^origin/||' | sort -u)"})
        _describe 'flags' flags
        _describe 'branch' branches
    elif [[ $CURRENT -eq 3 && ( "$words[2]" == "-d" || "$words[2]" == "--delete" ) ]]; then
        local -a worktrees
        worktrees=(${(f)"$(ls -1 "$AI_WORKTREES_DIR" 2>/dev/null)"})
        _describe 'worktree' worktrees
    fi
}

compdef _wt_complete wt
