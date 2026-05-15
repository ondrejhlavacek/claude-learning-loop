# learning-loop

A Claude Code plugin that turns every session into reusable knowledge.

## What it does

1. **Session triage** — when a Claude Code session ends, a `SessionEnd` hook spawns a detached headless Claude that reads the just-finished transcript and writes a per-session learnings file into the plugin's persistent data directory.
2. **Consolidation** — on demand, the `/learning-loop:consolidate-learnings` command merges all session files into `PRINCIPLES.md` (grouped global vs. per-repo) and archives the processed sessions.

The triage looks for four kinds of findings: **skill-gap**, **friction**, **knowledge**, **automation**. Generic coding best-practices and one-off context are filtered out.

## Design: advisory-only, no closed loop

By design this plugin **does not close the learning loop automatically.** Concretely:

- `PRINCIPLES.md` is **not** auto-loaded into future sessions' context (no `SessionStart` hook, no auto-injection).
- `consolidate-learnings` **never edits** `CLAUDE.md`, skills, hooks, or anything outside `${CLAUDE_PLUGIN_DATA}`. It only emits *suggestions* that the user can decide to apply manually.

The reasoning: the prompts in this plugin are still being tuned. Until the triage produces stable, high-signal output across months of usage, auto-injecting its conclusions into every session would silently amplify any noise. An advisory-only system lets the user stay the gatekeeper. When the prompts prove themselves reliable, closing the loop (e.g. a `SessionStart` hook that loads `PRINCIPLES.md`) is a deliberate, opt-in next step — not the default.

## Components

| Component | Path | Trigger |
|-----------|------|---------|
| Command | `commands/update-learnings.md` | `/learning-loop:update-learnings` (interactive) or headless from the hook |
| Command | `commands/consolidate-learnings.md` | `/learning-loop:consolidate-learnings` |
| Hook | `hooks/hooks.json` → `hooks/update-learnings-hook.sh` | `SessionEnd` (async, detached) |

## Data location

The plugin writes everything into Claude Code's per-plugin persistent data directory, exposed as `${CLAUDE_PLUGIN_DATA}`. For this plugin it resolves to `~/.claude/plugins/data/learning-loop-ondrejhlavacek/` with this layout:

```
${CLAUDE_PLUGIN_DATA}/
├── sessions/       # one .md per session (until consolidated)
├── archive/        # consolidated session files
└── PRINCIPLES.md   # global + per-repo principles distilled from sessions
```

This directory is **managed by Claude Code** — it survives plugin updates and re-installs, but is not touched by `/plugin marketplace update`. To wipe everything, `rm -rf` it manually.

The path is portable: nothing leaks into your `$HOME` or any project repo. Hook scripts and slash commands both read the path strictly from `${CLAUDE_PLUGIN_DATA}` — **no hardcoded fallback** by design, so the plugin tracks whatever path Claude Code provides today and in the future.

## Requirements

- Claude Code with plugin support (`/plugin` command available)
- `jq` and `bash` on `PATH` (used by the hook script)
- `claude` CLI on `PATH` (the hook spawns a headless run)

## Cascade prevention

The hook sets `LEARNINGS_HOOK_RUNNING=1` before spawning headless Claude. The nested `SessionEnd` of that headless run sees the env var and exits early — without this guard each session would fork another, indefinitely.

## Privacy

The session transcript stays on your machine. The hook reads it from `~/.claude/projects/<...>/<session_id>.jsonl` and feeds it to a local headless Claude. Nothing leaves your environment except whatever your local Claude Code is configured to send.
