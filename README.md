# claude-learning-loop

A Claude Code **plugin marketplace** (`ondrejhlavacek`) that ships the `learning-loop` plugin — automatic per-session triage plus on-demand consolidation into stable principles.

> Every session leaves behind a short learnings file. Periodically you consolidate them into `PRINCIPLES.md`. Over time your Claude Code setup gets smarter without you having to write CLAUDE.md rules by hand.

## What's inside

This repo is a marketplace (`.claude-plugin/marketplace.json`, name `ondrejhlavacek`) hosting one plugin:

- **[learning-loop](./learning-loop/)** — `/learning-loop:update-learnings`, `/learning-loop:consolidate-learnings` commands + a `SessionEnd` hook that auto-triages every session.

See [`learning-loop/README.md`](./learning-loop/README.md) for what the plugin does and where it writes.

## Install

Inside Claude Code:

```text
/plugin marketplace add ondrejhlavacek/claude-learning-loop
/plugin install learning-loop@ondrejhlavacek
```

That's it. The `SessionEnd` hook is registered automatically by the plugin manifest, and the slash commands become available as `/learning-loop:update-learnings` and `/learning-loop:consolidate-learnings`.

### Verify

```text
/plugin
```

You should see `learning-loop` listed under the `ondrejhlavacek` marketplace as enabled.

After your next session ends, check:

```bash
ls ~/.claude/plugins/data/learning-loop-ondrejhlavacek/sessions/
```

A new `YYYY-MM-DD-HHMM-<sid>.md` file should appear within a few seconds of the session closing.

## Update

```text
/plugin marketplace update ondrejhlavacek
```

Claude Code pulls the latest commit and re-loads the plugin. No manual file syncing.

## Uninstall

```text
/plugin uninstall learning-loop@ondrejhlavacek
/plugin marketplace remove ondrejhlavacek
```

Data in `~/.claude/plugins/data/learning-loop-ondrejhlavacek/` is **not** removed by uninstall — delete it manually if you want a clean slate.

## Requirements

- Claude Code with plugin marketplace support (`/plugin` available)
- `bash`, `jq`, `claude` CLI on `PATH`

## How it works

```
┌─────────────────────┐   SessionEnd     ┌──────────────────────────┐
│  Claude Code session│ ───────────────▶ │ update-learnings-hook.sh │
└─────────────────────┘   (async)        └────────────┬─────────────┘
                                                      │ nohup, detached
                                                      ▼
                                       ┌─────────────────────────────────┐
                                       │ headless `claude -p`            │
                                       │  /learning-loop:update-learnings│
                                       │  → ${CLAUDE_PLUGIN_DATA}/       │
                                       │       sessions/*.md             │
                                       └─────────────────────────────────┘

   /learning-loop:consolidate-learnings  (manual, on demand)
              │
              ▼
   sessions/*.md  ─▶  PRINCIPLES.md  +  archive/
```

State lives entirely under `${CLAUDE_PLUGIN_DATA}` (resolves to `~/.claude/plugins/data/learning-loop-ondrejhlavacek/`) — Claude Code's official per-plugin data directory. Nothing leaks into `$HOME` or any project repo.

The hook is async, detached (`nohup`), and uses a `LEARNINGS_HOOK_RUNNING` guard so the nested headless session doesn't trigger another triage — preventing a fork bomb.

## License

MIT — see [LICENSE](./LICENSE).
