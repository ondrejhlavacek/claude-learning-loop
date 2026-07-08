#!/usr/bin/env bash
# Hook script: spawns headless Claude to triage the just-ended session.
# Triggered by SessionEnd hook. Runs detached - never blocks the parent session.
# Writes per-session learnings under ${CLAUDE_PLUGIN_DATA}/sessions/.

set -u

# Cascade prevention: skip if invoked by a headless /update-learnings claude (which itself
# fires SessionEnd when done). Without this guard, every spawn fires another spawn → fork bomb.
[ "${LEARNINGS_HOOK_RUNNING:-}" = "1" ] && exit 0

# Read hook input JSON from stdin
INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r '.session_id // empty')
[ -n "$SID" ] || exit 0

# Locate transcript file
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SID}.jsonl" -type f 2>/dev/null | head -1)
[ -n "$TRANSCRIPT" ] || exit 0

# Extract origin cwd and git branch from the transcript (first record that has them)
CWD=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT" 2>/dev/null | head -1)
BRANCH=$(jq -r 'select(.gitBranch != null and .gitBranch != "") | .gitBranch' "$TRANSCRIPT" 2>/dev/null | head -1)
CWD=${CWD:-unknown}
BRANCH=${BRANCH:-}

# Persistent data directory.
# ${CLAUDE_PLUGIN_DATA} is set by Claude Code for plugin subprocesses and survives plugin updates.
# No fallback by design: if it's empty, the script is running outside Claude Code's plugin context
# and any hardcoded path would silently fragment data when Claude Code changes its ID format.
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  echo "update-learnings-hook: \$CLAUDE_PLUGIN_DATA is not set; refusing to guess a path." >&2
  exit 1
fi
SESSIONS_DIR="$CLAUDE_PLUGIN_DATA/sessions"
mkdir -p "$SESSIONS_DIR"
OUT="$SESSIONS_DIR/$(date +%Y-%m-%d-%H%M)-${SID:0:8}.md"

# Dedup: when a session is closed and resumed, SessionEnd fires again with the same SID.
# Remove any prior file for this session - the new run analyzes the full (longer) transcript
# and supersedes the older partial analysis.
shopt -s nullglob
for f in "$SESSIONS_DIR/"*"-${SID:0:8}.md"; do
  rm -f "$f"
done
shopt -u nullglob

# Tight allowlist: only Read/Write/Edit, no Bash/network. bypassPermissions skips prompts within those.
# LEARNINGS_HOOK_RUNNING=1 tells any nested SessionEnd hook to skip → prevents fork bomb.
# Detached so it survives parent session ending.
LEARNINGS_HOOK_RUNNING=1 nohup claude \
  -p "/learning-loop:update-learnings $TRANSCRIPT $OUT $CWD $BRANCH $SID" \
  --model 'claude-sonnet-5[1m]' \
  --allowed-tools "Read,Write,Edit" \
  --permission-mode bypassPermissions \
  >/dev/null 2>&1 < /dev/null &
disown
exit 0
