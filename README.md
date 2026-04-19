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
```

Then run the `create-qwen3-coder-mbp` / `create-mistral-small-mbp` functions from `zshrc-snippets.sh` to create optimized variants with tuned context sizes.

### 4. Wire up zshrc

```bash
# Add to your ~/.zshrc:
source ~/ai-setup/zshrc-snippets.sh
```

Edit the paths at the top of `zshrc-snippets.sh` to match your environment.

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
