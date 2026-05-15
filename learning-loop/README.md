# learning-loop

A Claude Code plugin that turns every session into reusable knowledge.

## What it does

1. **Session triage** — when a Claude Code session ends, a `SessionEnd` hook spawns a detached headless Claude that reads the just-finished transcript and writes a per-session learnings file into `~/Coding/claude-learnings/sessions/`.
2. **Consolidation** — on demand, the `/learning-loop:consolidate-learnings` command merges all session files into `~/Coding/claude-learnings/PRINCIPLES.md` (grouped global vs. per-repo) and archives the processed sessions.

The triage looks for four kinds of findings: **skill-gap**, **friction**, **knowledge**, **automation**. Generic coding best-practices and one-off context are filtered out.

## Components

| Component | Path | Trigger |
|-----------|------|---------|
| Command | `commands/update-learnings.md` | `/learning-loop:update-learnings` (interactive) or headless from the hook |
| Command | `commands/consolidate-learnings.md` | `/learning-loop:consolidate-learnings` |
| Hook | `hooks/hooks.json` → `hooks/update-learnings-hook.sh` | `SessionEnd` (async, detached) |

## Output location

Files are written to `~/Coding/claude-learnings/`:

```
~/Coding/claude-learnings/
├── sessions/       # one .md per session (until consolidated)
├── archive/        # consolidated session files
└── PRINCIPLES.md   # global + per-repo principles distilled from sessions
```

The directory is created lazily by the hook on first run.

## Requirements

- Claude Code with plugin support (`/plugin` command available)
- `jq` and `bash` on `PATH` (used by the hook script)
- `claude` CLI on `PATH` (the hook spawns a headless run)

## Cascade prevention

The hook sets `LEARNINGS_HOOK_RUNNING=1` before spawning headless Claude. The nested `SessionEnd` of that headless run sees the env var and exits early — without this guard each session would fork another, indefinitely.

## Privacy

The session transcript stays on your machine. The hook reads it from `~/.claude/projects/<...>/<session_id>.jsonl` and feeds it to a local headless Claude. Nothing leaves your environment except whatever your local Claude Code is configured to send.
