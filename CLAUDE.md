# Contributing to claude-learning-loop

Notes for anyone (including future-me) editing this repo with Claude Code.

## Repo layout

```
.claude-plugin/marketplace.json   # marketplace manifest (name: ondrejhlavacek)
learning-loop/                    # the only plugin in this marketplace
├── .claude-plugin/plugin.json    # plugin manifest
├── commands/                     # slash-command prompts (markdown)
│   ├── update-learnings.md       # per-session triage (interactive + headless)
│   └── consolidate-learnings.md  # merge sessions → PRINCIPLES.md
├── hooks/
│   ├── hooks.json                # SessionEnd registration
│   └── update-learnings-hook.sh  # async detached headless trigger
└── README.md
```

## Design constraints (do not violate)

- **Advisory-only.** `consolidate-learnings` (and any future command) must **not** edit files outside `${CLAUDE_PLUGIN_DATA}`. No auto-applied changes to CLAUDE.md, skills, hooks, or any project files. Always flag suggestions and wait for the user.
- **State lives under `${CLAUDE_PLUGIN_DATA}`.** Never write to `$HOME`, project repos, or invented paths. Resolve the data dir using the exact bash snippet present in the command files (env var first, then `find` fallback for slash commands where Claude Code does not inject `${CLAUDE_PLUGIN_DATA}` as of 2.1.x).
- **No closed loop.** Do not add a `SessionStart` hook that auto-injects `PRINCIPLES.md`. The user is the gatekeeper until the triage prompts prove themselves reliable across months.
- **Cascade prevention.** The `SessionEnd` hook sets `LEARNINGS_HOOK_RUNNING=1` before spawning headless Claude. Any new hook that spawns Claude headlessly must use the same guard pattern.

## Versioning

Two files carry the version, and **both must move together**:

- `learning-loop/.claude-plugin/plugin.json` → `version`
- `.claude-plugin/marketplace.json` → `plugins[0].version`

Claude Code keys updates on this version string. If you change behavior (new trigger, new command, schema change in session files) without bumping, users running `/plugin marketplace update ondrejhlavacek` see "already at latest" and nothing reloads.

Semver:
- **patch** (`0.x.Y`) — wording fix, typo, internal refactor, no behavior change.
- **minor** (`0.X.0`) — new trigger, new command, new optional frontmatter field, anything that adds capability without breaking existing sessions/PRINCIPLES.
- **major / breaking** (`X.0.0`) — frontmatter rename, marketplace rename, data-dir relocation, deleted command. Note these in the commit body — the data dir is **not** wiped by `/plugin uninstall`, so users may carry old session files into the new schema.
