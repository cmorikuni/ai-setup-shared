---
name: ai-usage
description: Use when user asks how to use the AI orchestrator, run-ai, ai-spec, or the local model dev loop.
---

Print the entire content below verbatim as your response.

# AI Orchestrator Usage

## Daily Workflow

```bash
# 1. Create / enter a worktree (or just cd to your project)
wt <branch-name>

# 2. Write your spec (Ctrl+D to save)
ai-spec

# 3. Run the loop
run-ai

# Or steps 2+3 combined:
ai-run
```

## What the loop does

1. **Generate** — local code model writes code to `.ai_output.py`
2. **Test** — runs `$AI_TEST_CMD` (default: `pytest`)
3. **Fix** — trivial failures → fast model, complex → strong model (max 3 attempts)
4. **Escalate** — if still failing, `claude-sonnet-4-6` audits and reports

Outputs: `.ai_output.py` (code), `.ai_log.jsonl` (structured log)

## Patch mode (bugfixes on existing code)

Use when a bug may span multiple existing files — skips generate, patches in place.

```bash
# Write a spec describing the issue
ai-spec

# Run with --patch flag
orchestrator.py --patch .ai-spec.md
```

**What patch mode does:**
1. **Locate** — model reads the file tree + issue, identifies relevant files
2. **Patch** — model outputs changed files; applied directly to the repo
3. **Fix loop** — same test/fix/escalate as generate mode, but re-feeds patched files

Outputs: modified files in-place, `.ai_log.jsonl` (structured log)

## Spec format

`.ai-spec.md` must use this structure:

```markdown
# <Feature Name>

## Requirements
...

## Acceptance Criteria
...
```

## Key files

| File | Purpose |
|---|---|
| `~/ai-orchestrator/orchestrator.py` | Main loop — edit `TEST_CMD` and `MODELS` here |
| `~/ai-orchestrator/prompts/` | generate.txt, fix.txt, audit.txt, locate.txt, patch.txt |
| `~/.local/bin/ollama-proxy.py` | Proxy on :11435 → Ollama on :11434 |

## Configuration

Edit the top of `orchestrator.py` to set:
- `TEST_CMD` — your project's test command (or set `AI_TEST_CMD` env var)
- `MODELS` — which Ollama models to use for generate / fix / audit

## Rules

- Do NOT auto-commit
- Do NOT share `.ai_output.py` across worktrees
- Run `run-ai` inside the worktree, not the main repo
- `ANTHROPIC_API_KEY` must be set for cloud escalation
