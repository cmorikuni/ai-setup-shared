# Wiki Maintenance Protocol

## On processing a new item in inbox/

1. Read `INDEX.md`.
2. Identify distinct concepts, ideas, or topics in the inbox file.
3. For each concept:
   - If a matching article exists in `projects/`, `reference/`, or `research/`: append to it.
   - If no article exists and warrants its own entry: create a new `.md` in the appropriate folder.
   - Personal ideas/inventions: file under `research/` or create a dedicated note.
4. Add backlinks between related articles using `[[article-name]]` syntax.
5. Update `INDEX.md` with any new entries.
6. Do NOT delete or modify source files in `inbox/` — append-only.

## On answering a query about wiki content

1. Read `INDEX.md`.
2. Read only relevant articles.
3. Answer inline, or write to `research/YYYY-MM-DD-query-slug.md` if the answer warrants a persistent record.

## On a linting pass

1. Read all articles in `projects/`, `reference/`, and `research/`.
2. Flag: contradictions, concepts without entries, broken `[[links]]`, stale/missing INDEX.md entries.
3. Create stub articles for missing entries.
4. Update `INDEX.md`.

## INDEX.md format

One line per article, grouped by folder:
- [Article Title](folder/filename.md) — one-sentence description

## What NOT to auto-compile

`journal/`, `meetings/`, `recipes/` — human-authored only.
