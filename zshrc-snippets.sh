#!/usr/bin/env zsh
# AI Dev Setup — zshrc snippets
#
# Source this from your ~/.zshrc:
#   source ~/ai-setup/zshrc-snippets.sh
#
# Set the CONFIG vars before sourcing (or export them in ~/.zshrc above the source line).

# ─── CONFIG (set these in ~/.zshrc before sourcing) ───────────────────────────

# Path to your Obsidian wiki / second brain
AI_WIKI=${AI_WIKI:-~/wiki}

# Path to your main git repo (the one you create worktrees from)
AI_REPO=${AI_REPO:-~/Repos/your-main-repo}

# Where git worktrees are checked out
AI_WORKTREES_DIR=${AI_WORKTREES_DIR:-~/Repos/worktrees}

# LiteLLM + model config (defaults work if you copied the files to ~/.local/bin/)
AI_LITELLM_YAML=${AI_LITELLM_YAML:-$HOME/.local/bin/litellm_config.yaml}
AI_MODELS_YAML=${AI_MODELS_YAML:-$HOME/.local/bin/custom_models.yaml}

# ─── OLLAMA ───────────────────────────────────────────────────────────────────

export OLLAMA_FLASH_ATTENTION=1   # faster attention on Apple Silicon
export OLLAMA_KEEP_ALIVE=15m      # keep model loaded between requests

# Auto-start Ollama when a new shell opens (inherits env vars above).
# Do NOT use 'brew services start ollama' — launchd won't inherit these vars.
if ! curl -sf http://localhost:11434 > /dev/null 2>&1; then
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    disown
fi

# ─── SECOND BRAIN ─────────────────────────────────────────────────────────────

# Run once per machine to symlink ~/.claude and ~/.claude-local into the wiki.
# This makes Claude's memory, sessions, and settings persist across reinstalls.
claude-bootstrap() {
    local wiki_root="${AI_WIKI}/claude"

    mkdir -p "$wiki_root/cloud"
    mkdir -p "$wiki_root/local"

    if [[ ! -L ~/.claude ]]; then
        [[ -d ~/.claude ]] && mv ~/.claude ~/.claude.bak
        ln -s "$wiki_root/cloud" ~/.claude
        echo "Linked Cloud Brain: ~/.claude -> $wiki_root/cloud"
    else
        echo "Cloud Brain already linked: $(readlink ~/.claude)"
    fi

    if [[ ! -L ~/.claude-local ]]; then
        [[ -d ~/.claude-local ]] && mv ~/.claude-local ~/.claude-local.bak
        ln -s "$wiki_root/local" ~/.claude-local
        echo "Linked Local Brain: ~/.claude-local -> $wiki_root/local"
    else
        echo "Local Brain already linked: $(readlink ~/.claude-local)"
    fi
}

# ─── MODEL CREATION ───────────────────────────────────────────────────────────

# Build all Ollama named model variants from custom_models.yaml.
# Run once after pulling base models, or again after editing the yaml.
create-ai-models() {
    local file="${AI_MODELS_YAML:-$HOME/.local/bin/custom_models.yaml}"

    for name in $(yq '.models | keys | .[]' "$file" -r); do
        local base=$(yq ".models.\"$name\".base" "$file" -r)
        local ctx=$(yq ".models.\"$name\".ctx" "$file" -r)
        local temp=$(yq ".models.\"$name\".temperature" "$file" -r)

        if ollama list | cut -d' ' -f1 | grep -qx "$base"; then
            echo ">> $base already present, skipping pull"
        else
            echo ">> Pulling $base"
            ollama pull "$base"
        fi

        echo ">> Building $name"
        local modelfile=$(mktemp)
        {
            echo "FROM $base"
            echo "PARAMETER num_ctx $ctx"
            echo "PARAMETER temperature $temp"
            yq ".models.\"$name\".top_p" "$file" -r | grep -v null >/dev/null && \
                echo "PARAMETER top_p $(yq ".models.\"$name\".top_p" "$file" -r)"
            yq ".models.\"$name\".num_batch" "$file" -r | grep -v null >/dev/null && \
                echo "PARAMETER num_batch $(yq ".models.\"$name\".num_batch" "$file" -r)"
            yq ".models.\"$name\".num_predict" "$file" -r | grep -v null >/dev/null && \
                echo "PARAMETER num_predict $(yq ".models.\"$name\".num_predict" "$file" -r)"
            yq ".models.\"$name\".system" "$file" -r | grep -v null >/dev/null && \
                echo "SYSTEM \"\"\"$(yq ".models.\"$name\".system" "$file" -r)\"\"\""
            for stop in $(yq ".models.\"$name\".stop[]?" "$file" -r); do
                echo "PARAMETER stop \"$stop\""
            done
        } > "$modelfile"
        ollama create "$name" -f "$modelfile"
        rm -f "$modelfile"
    done
}

# ─── CLAUDE WRAPPER ───────────────────────────────────────────────────────────

# Wraps the claude CLI to ensure cloud sessions are never accidentally routed
# through LiteLLM (clears ANTHROPIC_API_KEY and ANTHROPIC_BASE_URL).
#
# Usage:
#   claude           → normal cloud Claude
#   claude --skip    → cloud Claude with --dangerously-skip-permissions
claude() {
    local mode="normal"
    if [[ "$1" == "--skip" ]]; then
        mode="skip"
        shift
    fi
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_BASE_URL
    export CLAUDE_CODE_USE_BEDROCK=0
    export CLAUDE_CODE_USE_VERTEX=0
    if [[ "$mode" == "skip" ]]; then
        command claude --dangerously-skip-permissions "$@"
    else
        command claude "$@"
    fi
}

# ─── GIT WORKTREES ────────────────────────────────────────────────────────────
#
# Usage:
#   wt <branch>       — create or open a worktree (creates branch from main if new)
#   wt -d <branch>    — delete worktree and its branch
#
# Customize AI_REPO and AI_WORKTREES_DIR in the CONFIG block above.

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

    if [ -d "$target_dir" ]; then
        echo "== Worktree exists, opening VS Code =="
    else
        echo "== Updating $base and creating worktree: $branch =="
        git -C "$repo" fetch origin "$base":"$base"
        git -C "$repo" worktree add "$target_dir" "$branch" 2>/dev/null \
            || git -C "$repo" worktree add "$target_dir" -b "$branch" "$base"
    fi

    local wt_path wt_slug project_root
    wt_path="$(realpath "$target_dir")"
    wt_slug=$(echo "$wt_path" | sed 's|[/._]|-|g')
    project_root="$AI_WIKI/claude/projects/$wt_slug"

    mkdir -p "$project_root/memory"

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

    open -a "Visual Studio Code" "$target_dir"
}

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
