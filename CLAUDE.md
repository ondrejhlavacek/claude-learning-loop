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

## Editing the triage prompt

`learning-loop/commands/update-learnings.md` is the most-edited file. When changing it:

- **Hard triggers are load-bearing.** They are the filter that keeps the output high-signal. Adding a trigger is fine; loosening one is risky — it cascades into noisy `PRINCIPLES.md` over time. Document the *why* in the commit message.
- **Headless mode is the default execution path** (called from the hook). Anything that assumes interactivity (asking the user, printing reports) must be gated on the "empty arguments" branch.
- **Frontmatter schema changes affect consolidation.** `update-learnings` writes session frontmatter (`origin_cwd`, `origin_branch`, `tech_stack`, `session_id`, `status`, `mode`); `consolidate-learnings` reads it for grouping. Keep them in sync — when you add a field on one side, update the other.

## Versioning

Two files carry the version, and **both must move together**:

- `learning-loop/.claude-plugin/plugin.json` → `version`
- `.claude-plugin/marketplace.json` → `plugins[0].version`

Claude Code keys updates on this version string. If you change behavior (new trigger, new command, schema change in session files) without bumping, users running `/plugin marketplace update ondrejhlavacek` see "already at latest" and nothing reloads.

Semver:
- **patch** (`0.x.Y`) — wording fix, typo, internal refactor, no behavior change.
- **minor** (`0.X.0`) — new trigger, new command, new optional frontmatter field, anything that adds capability without breaking existing sessions/PRINCIPLES.
- **major / breaking** (`X.0.0`) — frontmatter rename, marketplace rename, data-dir relocation, deleted command. Note these in the commit body — the data dir is **not** wiped by `/plugin uninstall`, so users may carry old session files into the new schema.

## Commits

- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `chore(release):` for version bumps).
- No `Co-Authored-By: Claude` trailer, no "Generated with Claude Code" footer.
- One commit per coherent change. Version bump goes in its own `chore(release):` commit so the diff is easy to inspect.

## Testing changes locally

There is no test suite — slash commands are markdown prompts evaluated by Claude. To smoke-test:

1. Edit the command file.
2. From inside Claude Code, invoke the slash command directly (`/learning-loop:update-learnings`) — it runs against the **current** conversation.
3. For the hook path: end a real session and check `${CLAUDE_PLUGIN_DATA}/sessions/` for a fresh `YYYY-MM-DD-HHMM-<sid>.md`. The hook is detached (`nohup`) and async — give it 10–30 s after session close.
4. To re-trigger without ending the session: `claude -p "/learning-loop:update-learnings <transcript.jsonl> <output.md> <cwd> <branch> <sid>"` (headless mode).

Changes to a published version require a version bump + `/plugin marketplace update` + `/plugin` (or `/reload-plugins`) for the user to pick them up.

## File / path conventions

- Communicate with the user in Czech (per the user's global instructions); **write all files in English** — code, comments, command prompts, commit messages.
- No emoji in command output or commit messages.
- No new documentation files unless explicitly asked. `README.md` and this `CLAUDE.md` are the only repo-level docs.
