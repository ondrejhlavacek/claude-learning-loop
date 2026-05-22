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
6. **An automated reviewer flagged something Claude should have anticipated** — a bot review (GitHub Copilot, CodeRabbit, Codiumate, Codium PR Agent, etc.) or the `/second-opinion` skill (Gemini) pointed out an issue Claude didn't catch (bug, security flaw, missing validation, edge case, convention mismatch) and the user accepted the fix. Record the pattern the reviewer flagged + why Claude missed it.

Without at least one of these triggers → **do not record**. Subjective vibes ("the user probably prefers X") are not enough.

**Do not record even if a trigger fired:**
- Generic coding best practices (those belong in CLAUDE.md, not in learnings).
- One-off situations with no future relevance.
- Things already documented in the code/git/CLAUDE.md.
- Current task progress.
- Banalities ("user prefers clean code", "user wants tests").
- Cosmetic bot nits the user dismissed ("Copilot is wrong here, leave it", "ignore CodeRabbit on this one").
- Style preferences already enforced by a linter/formatter in the repo.

If there's nothing to record (no trigger fired), create a file with an empty Entries section anyway — empty is better than fabricated.

In headless mode, be extra conservative — without interactive context the false-positive risk is higher. When in doubt, leave it out.

### Detecting bot / second-opinion reviews (trigger 6)

Where to look in the transcript:
- `Bash` output from `gh pr view`, `gh pr view --comments`, `gh api repos/.../pulls/.../comments`, `gh api repos/.../pulls/.../reviews`, `gh pr review` — look for bot authors like `copilot-pull-request-reviewer[bot]`, `Copilot`, `coderabbitai[bot]`, `codiumai-pr-agent[bot]`, `github-actions[bot]`, `sonarqubecloud[bot]`.
- Output of the `second-opinion` skill (calls Gemini CLI) — treat findings the user agreed with as the same kind of signal.
- Claude's edits/commits that **followed** such a review and addressed the reviewer's point.

For each reviewer finding that the user accepted, ask:
- **What pattern did the bot flag?** State it concretely (e.g. "missing null check on `response.data` before `.map()`", "string-concatenated SQL in `getUser()`", "race condition: cache invalidation runs after the write returns", "function returns `Promise<any>` instead of typed result").
- **Why did Claude miss it?** Pick one: no relevant skill was loaded; wrong default behavior; missing project context; Claude knew the rule but didn't apply it under the current load.
- **What's the durable rule?** The fix itself isn't a learning — the *general pattern* the bot taught is. ("Always validate API response shape before destructuring." not "Add `if (!data) return;` to this specific function.")

Bot reviews are a **higher-signal source than general session noise** — a human took the time to integrate the fix. Lean toward recording (but still under the existing "don't record" filters).

## 2. Action triage

For each finding, propose an action (just a proposal — **apply nothing**):
- **CLAUDE.md global** (`~/.claude/CLAUDE.md`) — a rule that always applies, across every repo.
- **CLAUDE.md project** (`<repo>/CLAUDE.md`) — a rule specific to the repo where the session ran. Prefer this over global for repo-conventions, project-specific stacks, internal tooling, etc.
- **Existing skill update** — name the skill (e.g. "feature-dev:feature-dev", "superpowers:test-driven-development") if a skill *should* have caught this but didn't. Bot reviews often surface gaps in existing skills.
- **New skill** — situational workflow loaded on demand. Only when no existing skill covers the area.
- **Hook** — event-driven automation.
- **Auto-memory** — a specific fact (type user/feedback/project/reference).
- **None** — just record it.

For trigger 6 (bot/second-opinion reviews), the most common targets are **Existing skill update** (the skill that *should* have prevented the bot's finding) or **CLAUDE.md project** (when the rule is repo-specific). Global CLAUDE.md is rare — only for cross-stack, cross-repo conventions.

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
