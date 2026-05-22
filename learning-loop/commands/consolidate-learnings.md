---
description: Consolidate session files in the plugin data directory into PRINCIPLES.md and archive the processed sessions. Does not edit anything outside the data directory — only flags suggestions.
---

## Plugin data directory

This command operates on the plugin data directory. Resolve `DATA_DIR` with this exact bash snippet:

```bash
resolve_data_dir() {
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  # Fallback for interactive runs: Claude Code (as of 2.1.x) does not inject
  # CLAUDE_PLUGIN_DATA into the Bash tool of the main session. Locate the
  # data directory via `find` on the plugin name. We use `find` instead of a
  # shell glob because zsh (macOS default) and bash disagree on array indexing.
  local matches
  matches=$(find "$HOME/.claude/plugins/data" -mindepth 1 -maxdepth 1 -type d -name 'learning-loop-*' 2>/dev/null)
  [ -n "$matches" ] || return 1
  if [ "$(printf '%s\n' "$matches" | wc -l | tr -d ' ')" = "1" ]; then
    printf '%s\n' "$matches"
    return 0
  fi
  return 1
}
DATA_DIR=$(resolve_data_dir) || { echo "Cannot locate learning-loop plugin data directory." >&2; exit 1; }
echo "$DATA_DIR"
```

If the snippet fails (no data directory, or multiple candidates), tell the user and stop — do **not** guess a path.

`$DATA_DIR` is used throughout the rest of this command. Layout:

```
$DATA_DIR/
├── sessions/       # per-session learnings (input for consolidation)
├── archive/        # processed session files
└── PRINCIPLES.md   # consolidated principles
```

**Do not modify anything outside `$DATA_DIR`** (no edits to CLAUDE.md, skills, hooks, etc.). Cross-directory changes are only flagged as suggestions.

## 1. Load input

```bash
ls "$DATA_DIR/sessions/"*.md 2>/dev/null
```

If the list is empty, say "nothing to consolidate" and stop.

Read every session file plus the current `$DATA_DIR/PRINCIPLES.md` (if it exists).

## 2. Cross-entry analysis

Collect all `### N. ...` entries from every session file. Then:

- **Find duplicates** — entries saying the same thing in different words across sessions.
- **Find neighbours** — 2–3 entries covering the same domain.
- **Find patterns** — 3+ entries across different sessions pointing at the same principle → candidate for promotion.
- **Find stale entries** — those superseded by newer ones or no longer relevant.

## 3. Update PRINCIPLES.md

**First group by `origin_cwd` and `tech_stack`** from the frontmatter of each session file. Some principles are **global** (apply across all repos), others are **repo-specific** (e.g. conventions in `~/Coding/oncall/`), still others are **tech-specific** (only React, only Python, ...).

Heuristics:
- 3+ entries from 2+ different `origin_cwd` **with** the same/overlapping `tech_stack` → **global principle for that stack**.
- 3+ entries from 2+ different `origin_cwd` across different stacks → **truly global principle** (not tied to a specific technology).
- 3+ entries from a single `origin_cwd` → **repo-specific principle**.

Maintain sections in `PRINCIPLES.md`:

```
## Principles — global

- **Short rule.** Why: ... | Source: N entries (YYYY-MM-DD to YYYY-MM-DD)

## Principles — tech: typescript+react

- **Short rule that applies only to this stack.** Why: ... | Source: ...

## Principles — repo: /Users/<you>/Coding/oncall

- **Short repo-specific rule.** Why: ... | Source: ...

## Principles — repo: /Users/<you>/Coding/foo

...
```

Before adding, check the same/similar principle isn't there already (if so, just update Source/date).

If a principle is no longer relevant (superseded, or already in CLAUDE.md), delete it.

PRINCIPLES.md should stay **short and stable** — ideally under ~30 bullets. If it grows beyond that, merge more aggressively.

### Rules for formulating a principle

- **Preserve concrete names** of classes, flags, APIs, commands, and files mentioned in the source entries. Don't reduce them to vague phrases.
  - Bad: "When running the test framework, use the right flags."
  - Good: "With `pnpm test`, use `-- <file>`, not workspace-wide tests — workspace timeouts kill subagents at the 2-minute mark."
- **Always state the why** ("Why: ...") — without a reason it's impossible to judge later whether the principle still applies, or whether it was just reacting to a one-off trap already fixed elsewhere.
- **Tech-specific principles need explicit tech context** — either place them under `Principles — tech:`, or state the stack in the rule itself ("In React projects: ...").
- Avoid generic banalities like "write clean code" or "test your code" — those belong in CLAUDE.md or are already obvious.

## 4. Archive processed sessions

Move every session file you processed into `$DATA_DIR/archive/`:

```bash
mkdir -p "$DATA_DIR/archive"
mv "$DATA_DIR/sessions/<file>.md" "$DATA_DIR/archive/"
```

**Exception:** a session file with `status: open` in its frontmatter, where no entry was used for a principle or merged — leave it in `sessions/` (it might become relevant later, combined with future entries). Use this exception sparingly; the default is to archive.

## 5. Report and flagging

Print:

**Consolidation:**
- Sessions processed: N (archived: M, kept: K)
- New principles: N (list titles)
- Updated principles: N
- Removed principles (superseded): N

**Suggestions for the user to review (NOTHING applied):**

For each principle or high-impact entry, propose a target file:

```
1. [PRINCIPLE→CLAUDE.md global] "..." → add to ~/.claude/CLAUDE.md section X
2. [PRINCIPLE→CLAUDE.md project] "..." → add to <origin_cwd>/CLAUDE.md (repo-specific convention)
3. [GAP→EXISTING SKILL] entries Y, Z reveal a gap in skill <name> — add rule "..." to that skill
4. [PATTERN→NEW SKILL] entries Y, Z suggest a new skill for domain D
5. [FRICTION→HOOK] friction Q recurs → PostToolUse hook with X
```

When the source entries came from trigger 6 (bot / second-opinion reviews), strongly prefer **EXISTING SKILL** or **CLAUDE.md project** targets — bots flag concrete rules in concrete contexts, not generic principles.

End by asking: "Want to apply any of these?" — wait for an explicit OK before applying anything.
