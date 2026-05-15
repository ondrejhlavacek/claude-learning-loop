---
description: Triage a Claude Code session. Without arguments analyses the current conversation; with arguments runs headless from the SessionEnd hook.
---

Arguments: `$ARGUMENTS`

## Plugin data directory

This plugin stores session learnings in `<DATA_DIR>/sessions/`. Resolve `DATA_DIR` with this exact bash snippet:

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

## Mode detection

If `$ARGUMENTS` contains **2–5 space-separated items** (`<transcript.jsonl> <output.md> [cwd] [git_branch] [session_id]`):
- **Headless mode** (invoked by the hook): read the transcript, write the output to `output.md`.
- Do **not** read the current conversation — work only from the transcript.
- 3rd arg = absolute path to the repo/cwd where the session ran (record as `origin_cwd`).
- 4th arg = git branch (record as `origin_branch`; omit the line if empty or `HEAD`).
- 5th arg = full session_id (UUID, record as `session_id` — used to dedup on `/resume`).

If `$ARGUMENTS` is **empty**:
- **Interactive mode**: analyse the current conversation.
- Output path = `<DATA_DIR>/sessions/YYYY-MM-DD-HHMM.md`, where `<DATA_DIR>` comes from the snippet above.
- `origin_cwd` = current working directory (`pwd`).
- `origin_branch` = current git branch if inside a repo (`git branch --show-current`); otherwise omit.
- Omit `session_id` (interactive runs don't have a deterministically known one).

## 1. Collecting findings

Look for findings in four categories:

- **skill-gap** — things Claude failed at, repeatedly got wrong, or that took multiple tries.
- **friction** — repeated manual steps; things the user had to say explicitly that should have been default behaviour.
- **knowledge** — facts about the project/preferences/setup Claude didn't know but should.
- **automation** — recurring patterns → candidates for a skill, hook, or script.

### Hard triggers — record an insight ONLY if at least one applies

1. **The user corrected Claude's code** (wrong API, bad syntax, non-existent function, wrong import).
2. **The user explicitly refused a course of action** ("no, not like that", "stop", "don't do X", "revert that", "do Y instead").
3. **More than 2 iterations on a trivial goal** (Claude had to fix the same kind of issue 3+ times — typos in filenames, wrong paths, repeated lint failures).
4. **The user revealed an unknown fact about the setup/project** ("we use X here", "watch out, Y is in Z", "it's in repo W") — something you could not have guessed from the code.
5. **A user repeated a manual step** that should have been automated (3+ identical fix-ups in one session).

Without at least one of these triggers → **do not record**. Subjective vibes ("the user probably prefers X") are not enough.

**Do not record even if a trigger fired:**
- Generic coding best practices (those belong in CLAUDE.md, not in learnings).
- One-off situations with no future relevance.
- Things already documented in the code/git/CLAUDE.md.
- Current task progress.
- Banalities ("user prefers clean code", "user wants tests").

If there's nothing to record (no trigger fired), create a file with an empty Entries section anyway — empty is better than fabricated.

In headless mode, be extra conservative — without interactive context the false-positive risk is higher. When in doubt, leave it out.

## 2. Action triage

For each finding, propose an action (just a proposal — **apply nothing**):
- **CLAUDE.md (global / project)** — a rule that always applies.
- **New skill** — situational workflow loaded on demand.
- **Hook** — event-driven automation.
- **Auto-memory** — a specific fact (type user/feedback/project/reference).
- **None** — just record it.

## 3. Writing the file

Create the output file (path per mode above) in this format:

```markdown
---
date: YYYY-MM-DD
session_id: 779a15ef-dea0-4814-b682-34ea1b5d2f4b   # omit in interactive mode
origin_cwd: /Users/<you>/Coding/<repo>
origin_branch: main             # omit if not a git repo or "HEAD"
tech_stack: [typescript, react, pnpm]   # technologies of the session — see rules below
session_summary: one sentence describing what the session was about
status: open
mode: headless | interactive
---

# Session learnings — YYYY-MM-DD HH:MM

## Entries

### 1. Short title (max 60 chars)
- **Category:** skill-gap | friction | knowledge | automation
- **Tech:** [python, fastapi] — if the entry applies only to a specific stack; omit if universal
- **Context:** 1–2 sentences describing what happened
- **Insight:** 1–3 sentences with the takeaway (and *why* — without a "why" the entry can't be judged later)
- **Action:** type + short spec (e.g. "CLAUDE.md global: add rule X")

### 2. ...
```

### Rules for `tech_stack`

- Session-level `tech_stack` = primary technologies/languages/frameworks of the session, max 4 items, lowercase kebab-case (`typescript`, `react`, `pnpm`, `terraform`, `python`, `fastapi`, `keboola-cli`, `sql`, `bash`, ...).
- Per-entry `Tech:` = narrower stack if the entry applies only to it. If it applies universally (e.g. user language preference, git workflow), omit the field.
- Without tech context, consolidation can't decide whether "avoid export default" is a global rule or just a React-project rule.

When there are 0 findings, the Entries section gets a single line: `_No durable insights in this session._`

## 4. Report

**Headless mode:** no report (nobody reads it). Just write the file and exit.

**Interactive mode:** print briefly:
- Path of the created file.
- Entry count (with titles if ≤5; otherwise count broken down by category).
- Optionally ask about 1–2 borderline findings the user might want to include.

No long session summary.
