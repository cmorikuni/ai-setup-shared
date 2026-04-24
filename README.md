# AI Dev Setup

A portable Claude Code + local LLM dev environment. Everything lives in a wiki (Obsidian or any folder), symlinked into `~/.claude` so setup on a new machine is one command.

## What's included

| File | Purpose |
|---|---|
| `zshrc-snippets.sh` | Shell config: env vars, `claude-bootstrap`, `create-ai-models`, `claude()` wrapper, `wt` |
| `bin/oclaude` | Run Claude Code against a local Ollama model via LiteLLM |
| `bin/litellm_config.yaml` | LiteLLM proxy config template — maps model aliases to Ollama models |
| `bin/custom_models.yaml` | Ollama model tuning config — ctx sizes, stop tokens, parameters |
| `bin/run-ai` | AI orchestrator: generate mode (writes new code from spec) |
| `bin/patch-ai` | AI orchestrator: patch mode (modifies existing files from spec) |
| `bin/ai-spec` | Interactive spec writer — prompts for name + notes, saves to wiki |
| `claude/CLAUDE.md` | Global Claude Code behavior overrides |
| `claude/settings.json` | Permissions, statusline, plugins |
| `claude/SETUP.md` | New machine setup (symlink the wiki into `~/.claude`) |

---

## Quick Start

Follow these steps **in order**.

### 1. Install prerequisites

- macOS with ≥32GB RAM (≥16GB for smaller models)
- [Ollama](https://ollama.com) — `brew install ollama`
- [Claude Code CLI](https://docs.anthropic.com/claude-code)
- [uv](https://docs.astral.sh/uv/) — `brew install uv`
- `yq` — `brew install yq`

Install LiteLLM:

```bash
uv tool install litellm
```

### 2. Clone this repo

```bash
git clone <repo-url> ~/ai-setup
```

### 3. Add to `~/.zshrc`

Source the snippets file and add `bin/` to your PATH. **Edit `AI_WIKI` and `AI_REPO` to match your environment first.**

```bash
# Add to ~/.zshrc:
export AI_WIKI="$HOME/Documents/Obsidian Vault/wiki"  # ← your Obsidian vault path
export AI_REPO="$HOME/Repos/your-main-repo"           # ← your main git repo
export AI_WORKTREES_DIR="$HOME/Repos/worktrees"       # ← where worktrees are checked out

source ~/ai-setup/zshrc-snippets.sh
export PATH="$HOME/ai-setup/bin:$PATH"
```

Then reload:

```bash
source ~/.zshrc
```

### 4. Copy and configure LiteLLM config

```bash
mkdir -p ~/.local/bin
cp ~/ai-setup/bin/litellm_config.yaml ~/.local/bin/litellm_config.yaml
cp ~/ai-setup/bin/custom_models.yaml ~/.local/bin/custom_models.yaml
```

Edit `~/.local/bin/litellm_config.yaml` if you want to add or remove model aliases. The defaults (qwen-local, qwen-fast, mistral-local, kimi-local) match `custom_models.yaml`.

### 5. Build Ollama model variants

Pull base models and build tuned variants:

```bash
create-ai-models
```

Verify:

```bash
ollama list
# expect: qwen3-coder-pro, qwen3-coder-fast, mistral-small-mbp (+ kimi-pro if applicable)
```

> **Note on kimi-pro:** requires `kimi-k2.6:cloud` in your Ollama instance. Remove the `kimi-pro` entry from `custom_models.yaml` if you don't have it.

### 6. Link the second brain

`claude-bootstrap` symlinks `~/.claude` and `~/.claude-local` into your wiki so Claude's memory and sessions persist across reinstalls.

Run once per machine:

```bash
claude-bootstrap
```

Verify:

```bash
ls -la ~/.claude ~/.claude-local
# both should be symlinks into your wiki directory
```

> **If `~/.claude` already exists as a directory**, `claude-bootstrap` backs it up to `~/.claude.bak` before creating the symlink.

### 7. Run `oclaude`

```bash
oclaude           # qwen-local — strong coder, 24k ctx (default)
oclaude fast      # qwen-fast  — 3k ctx, fastest responses
oclaude kimi      # kimi-local — 128k ctx, best for large refactors
oclaude mistral   # mistral-local — fast and cheap, good for simple fixes
```

The `claude` command always uses the cloud model and is unaffected by `oclaude`'s env vars.

---

## AI Orchestrator

The orchestrator runs a generate → test → fix → escalate loop against a spec file.

```bash
# 1. Write a spec
ai-spec

# 2. Run the loop (generate mode — writes new code)
run-ai my-feature       # resolves to $AI_WIKI/claude/plans/my-feature.md

# 3. Or patch mode — modifies existing files
patch-ai my-feature
```

**Loop behavior:**
1. **Generate** — qwen3-coder-pro writes code from the spec
2. **Test** — runs the project's CI command
3. **Fix** — trivial failures → mistral-small-mbp; complex → qwen3-coder-pro (max 3 attempts)
4. **Escalate** — if still failing, cloud Claude audits and reports

---

## Git Worktrees

```bash
wt <branch>       # create or open a worktree (creates branch from main if new)
wt -d <branch>    # delete worktree and its branch
```

`wt` creates a per-worktree Claude memory dir in the wiki and writes a `CLAUDE.local.md` with branch context. Edit the `wt` function in `zshrc-snippets.sh` to match your team's repo paths.

---

## Troubleshooting

**`oclaude: command not found`**
→ Ensure `~/ai-setup/bin` is on your PATH and you've run `source ~/.zshrc`.

**LiteLLM not starting**
→ Check `/tmp/litellm.log`. Kill and retry: `kill $(lsof -ti :4000) && oclaude`.

**Model not found**
→ Run `create-ai-models`, then `ollama list` to confirm the variants were built.

**Garbled output or raw tool-call JSON**
→ Missing stop tokens. Verify `extra_body.stop` is set in `litellm_config.yaml` for that model.

**Session hitting cloud Claude instead of local**
→ The `claude()` wrapper in `zshrc-snippets.sh` unsets `ANTHROPIC_BASE_URL` for cloud sessions — this is correct. Inside `oclaude` the var is set to `http://localhost:4000`.

**Slow responses**
→ Reduce `ctx` in `custom_models.yaml` and rebuild with `create-ai-models`. Or use `oclaude fast`.

**Logs:**

```bash
tail -f /tmp/litellm.log   # LiteLLM proxy
tail -f /tmp/ollama.log    # Ollama server
```
