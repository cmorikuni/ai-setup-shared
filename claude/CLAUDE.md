# Skill Overrides

## Planning
- NEVER invoke `superpowers:brainstorming`. Use `grill-me` for all planning and design work.
- Only invoke `superpowers:writing-plans` or `superpowers:executing-plans` when explicitly asked.
- **All plans and docs must be written to the wiki** (e.g. `~/wiki/claude/plans/`). Use symlinks from `~/.claude/plans/` if needed.

## Routine tasks
- Do NOT invoke any skill for simple, single-step coding tasks (bug fixes, small edits, questions).
- Reserve `superpowers:systematic-debugging` for genuinely complex, multi-cause bugs.
- Reserve `superpowers:test-driven-development` for new features.

## Always use
- `superpowers:verification-before-completion` before claiming work is done.
- `superpowers:requesting-code-review` after completing a significant feature.

## Code Review Protocol (Token Optimization)
Before invoking any multi-agent or "full" review skill, perform a cost-benefit triage:

**Tier 1: Direct Inline (Low Cost)**
- Scope: Frontend UI components, CSS/Styling, Documentation, Unit Test updates, or single-file JS/TS logic.
- Action: DO NOT invoke specialists. Perform a direct, single-pass review in the primary process.
- Constraint: Max 20k token overhead.

**Tier 2: Full Specialist Review (High Cost)**
- Scope: Auth/Identity logic, Database migrations, breaking API changes, or multi-service backend architectural shifts.
- Action: Invoke full /review sub-agents only for these high-risk domains.

---

# Wiki Reference

The wiki lives at `~/wiki` (adjust path to match your setup — Obsidian vault or plain folder).

## Session-start behavior
1. If the user's first message relates to a known project or topic, Glob the matching wiki file, then Read only that file.
2. Stop there. Do not pre-load files speculatively.

## Context discipline
- Read at most 2 wiki files per session unless the task requires more.
- Prefer targeted Grep over full file reads when you only need one fact.
- If a file exceeds ~150 lines, read only the relevant section using offset+limit.

## File map (customize to your project structure)
- `projects/` — per-project task notes
- `reference/` — tool references (Git, Docker, DB, cloud CLI)
- `journal/` — career/personal context (load only when explicitly relevant)

---

# Code Style

- Never use function-level imports (importing inside a function body) unless avoiding a known circular import.

# Commit Messages

Format: `F - <msg>` (feature), `R - <msg>` (refactor), `D - <msg>` (document).
- No `Co-Authored-By` lines or any other extraneous text — message body must be the prefix + description only.

---

# gstack

Use `/browse` for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

---

# Debugging & Token Discipline

**Goal: Minimize context bloat. Prioritize targeted tracing over broad exploration.**

## 0. Start With Git Log (HARD RULE — NO EXCEPTIONS)
For **any bug fix or small feature**: before reading any file, run `git log --oneline <branch> ^main`. This gives 3-4 commits. Read only the functions changed in those commits. Stop at the gap. Done in 1 pass.

## 1. Investigation Protocol
- **Trace First:** For UI/behavioral bugs, follow the chain: `Event Handler` → `Data Flow` → `Gap`. Stop when the flow breaks. Do NOT start at the DB/infrastructure.
- **State Intent:** Before any search/read, state in <15 words what you seek and why. If unsure, ask; do not speculate.
- **Targeted Grep:** Use specific grep on local files/functions. Avoid repo-wide scans.
- **Ignore IDE Context:** Do not read open files unless explicitly relevant to the trace.

## 2. Token Guardrails
- **Stop at the Gap:** Once the root cause is found, stop reading. Do not validate adjacent code or "confirm" architecture. Summarize and wait.
- **Trust Names:** Skip bodies of self-describing classes/mixins (e.g., `SoftDeleteMixin`, `BulkCommitter`) unless the trace leads inside.
- **5-File Checkpoint:** If the gap isn't found within 5 files, stop and ask one clarifying question. Do not expand scope solo.
- **Hypothesis Cost:** If a hypothesis requires a full read of a base class/config to verify, state it as "speculative" and move on rather than burning tokens to confirm.

## 3. Feature Addition Protocol (not Bug Fixes)
- `git diff` is for bugs — understanding *what changed recently*. For feature additions, the description already tells you what to find. After `git log`, go directly to the relevant file and function. Skip `git diff`.
- Identify the target file from the feature description or IDE context (see below), not from diff output.

## 4. IDE Open-File Hint
- When a system-reminder shows a file is open in the IDE and it matches the task, treat it as the target file. Do not grep to rediscover it.
- "Ignore IDE Context" (rule 1) means do not speculatively read *unrelated* open files — not that you should ignore obviously relevant ones.

## 5. Read-Once Discipline
- Before making edits, read a range wide enough to cover all nearby edit points in one pass. Do not make multiple small reads with overlapping line ranges — each redundant read costs a round-trip and bloats context.
