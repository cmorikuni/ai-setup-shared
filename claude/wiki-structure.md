# Wiki / Second Brain Structure

The wiki is a folder (ideally an Obsidian vault) that serves as the single source of truth for:
- Claude Code config (`claude/`)
- Project task notes (`projects/`)
- Tool references (`reference/`)
- Research and scratch (`research/`)

## Recommended folder layout

```
wiki/
├── INDEX.md                        # One-line index of all articles
├── claude/                         # Symlinked to ~/.claude
│   ├── CLAUDE.md                   # Global Claude instructions
│   ├── SETUP.md                    # New-machine setup guide
│   ├── settings.json               # Claude Code permissions + config
│   ├── wiki-maintenance.md         # Protocol for maintaining this wiki
│   ├── plans/                      # Implementation plans (written by Claude)
│   ├── projects/                   # Per-worktree Claude memory
│   │   └── <worktree-slug>/
│   │       └── memory/             # Auto-memory files for this project
│   └── skills/                     # Custom slash commands
│       └── <skill-name>/
│           └── SKILL.md
├── projects/                       # Human task notes per project/ticket
│   └── <project-slug>.md
├── reference/                      # Tool and process references
│   ├── git.md
│   ├── docker.md
│   └── vscode/
│       ├── settings.json
│       └── keybindings.json
├── research/                       # Scratch, exploration, one-off queries
│   └── YYYY-MM-DD-topic.md
├── journal/                        # Human-only, not read by Claude
└── inbox/                          # Unprocessed notes (append-only)
```

## The key insight: `~/.claude` is a symlink

```bash
ln -s ~/wiki/claude ~/.claude
```

All Claude memory, plans, settings, and skills live in your wiki under version control. Nothing is scattered across your home directory.

## Per-project memory

When you create a git worktree, also create a memory folder and link it:

```bash
# Create project memory dir
mkdir -p ~/wiki/claude/projects/<worktree-slug>/memory

# The memory/ dir is auto-populated by Claude with .md files
```

Claude Code reads `MEMORY.md` (the index) from `~/.claude/projects/<project>/memory/` at session start.

## Maintenance

See `wiki-maintenance.md` for the inbox processing and linting protocol.
