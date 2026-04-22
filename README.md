# AI Dev Setup

A portable Claude Code + local LLM dev environment. Everything lives in a wiki (Obsidian or any folder), symlinked into `~/.claude` so setup on a new machine is one command.

## What's included

| Component | Purpose |
|---|---|
| `claude/CLAUDE.md` | Global Claude Code behavior overrides |
| `claude/settings.json` | Permissions, statusline, plugins |
| `claude/wiki-maintenance.md` | Protocol for maintaining the wiki second brain |
| `claude/skills/ai-usage/` | Slash command: explains the AI orchestrator workflow |
| `ai-orchestrator/` | Local-LLM code-generation + test loop |
| `bin/ai-spec` | Interactive spec writer: prompts for name + notes, saves to wiki/claude/plans/, launches grill-me |
| `bin/run-ai` | Generate mode: writes new code to `.ai_output.py` from spec |
| `bin/patch-ai` | Patch mode: locates and patches existing files in-place from spec |
| `bin/ollama-proxy.py` | Flask proxy: Anthropic API format → Ollama |
| `zshrc-snippets.sh` | Shell functions: `wt`, `oclaude`, `run-ai`, etc. |

## Quick start

### 1. Clone this repo somewhere

```bash
git clone <repo-url> ~/ai-setup
```

### 2. Symlink Claude config

```bash
ln -s ~/ai-setup/claude ~/.claude
```

Or if you use Obsidian, copy `claude/` into your vault and symlink from there.

### 3. Install Ollama + models

```bash
# Install Ollama: https://ollama.com
brew install ollama

# Pull the models (adjust to what fits your hardware)
ollama pull qwen3-coder:latest          # main code model
ollama pull mistral-small:24b           # fast fix model
ollama pull kimi:latest                  # Kimi model
```

Then run the custom model creation functions from `zshrc-snippets.sh` to create optimized variants with tuned context sizes:
- `create-qwen3-coder-pro` - Creates optimized qwen3-coder Pro model
- `create-qwen3-coder-fast` - Creates optimized qwen3-coder Fast model
- `create-mistral-small-mbp` - Creates optimized mistral-small model for MBP
- `create-kimi-pro` - Creates optimized Kimi Pro model

### 4. Wire up zshrc

```bash
# Add to your ~/.zshrc:
source ~/ai-setup/zshrc-snippets.sh
export PATH="$HOME/ai-setup/bin:$PATH"
```

Edit the paths at the top of `zshrc-snippets.sh` to match your environment (`AI_REPO`, `AI_WORKTREES_DIR`, `AI_WIKI`, etc.).

### 5. Set your API key (for cloud escalation)

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### 6. Install ai-orchestrator dependencies

```bash
cd ~/ai-setup/ai-orchestrator
pip install -r requirements.txt
# or: uv pip install -r requirements.txt
```

## Obsidian Vault structure

See `claude/wiki-structure.md` for the recommended second-brain layout.

## Custom Functions

This setup includes several custom functions for enhanced workflow:

### Claude Code Functions
- `oclaude` - Run Claude Code with local Ollama models
  - `oclaude` (or `oclaude pro`) → qwen3-coder-pro (default, strongest)
  - `oclaude fast` → qwen3-coder-fast (faster)
  - `oclaude mistral` → mistral-small-mbp (faster)
  - `oclaude 7b` → qwen2.5-coder:7b (lightweight)
  - `oclaude <name>` → any ollama model by name
- `ai-spec` — interactive spec writer (requires `bin/` on PATH)
  1. Prompts for a spec name (no path/extension)
  2. Prompts for a one-line summary
  3. Saves to `$AI_WIKI/claude/plans/<name>.md` via grill-me
  After writing the spec, run the orchestrator with: `run-ai $AI_WIKI/claude/plans/<name>.md`

### Model Creation Functions
- `create-kimi-pro` - Create optimized Kimi Pro model
- `create-qwen3-coder-pro` - Create optimized qwen3-coder Pro model
- `create-qwen3-coder-fast` - Create optimized qwen3-coder Fast model
- `create-mistral-small-mbp` - Create optimized mistral-small model for MBP

### Git Worktree Functions
- `wt <branch>` - Create or open a worktree
- `wt -d <branch>` - Delete a worktree and its branch
