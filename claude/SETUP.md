# Claude Code Setup — New Machine

**Everything lives in the wiki** (`wiki/claude/`) as the source of truth — global config, skills, plans, memory, and settings.

## Setup

**One-time symlink (on new machine):**

```bash
ln -s "/path/to/your/wiki/claude" ~/.claude
```

That's it. This single symlink brings in everything:
- `CLAUDE.md` — global skill overrides and instructions
- `plans/` — all plans (source of truth in wiki)
- `projects/*/memory/` — auto memory files
- `settings.json` — Claude Code configuration
- `keybindings.json` — custom keybindings (optional)
- All skills

No files in `~/.claude/` are written to local disk — everything points to the wiki. Recreate your environment on any machine with one symlink.

## VSCode Settings (optional)

VSCode settings can live in the wiki at `reference/vscode/`. To wire them up on a new machine:

```bash
VSCODE_DIR="$HOME/Library/Application Support/Code/User"
WIKI_VSCODE="/path/to/your/wiki/reference/vscode"

# Back up any existing settings
mv "$VSCODE_DIR/settings.json" "$VSCODE_DIR/settings.json.bak" 2>/dev/null
mv "$VSCODE_DIR/keybindings.json" "$VSCODE_DIR/keybindings.json.bak" 2>/dev/null

# Symlink to wiki
ln -s "$WIKI_VSCODE/settings.json" "$VSCODE_DIR/settings.json"
ln -s "$WIKI_VSCODE/keybindings.json" "$VSCODE_DIR/keybindings.json"
```

After this, any changes you make in VSCode settings are saved directly to the wiki.

## Statusline (optional)

`settings.json` references `~/.claude/statusline.sh`. Create or symlink that script to show context (branch, token count, etc.) in the Claude Code statusline.
