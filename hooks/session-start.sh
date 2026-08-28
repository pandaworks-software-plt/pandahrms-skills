#!/usr/bin/env bash
# SessionStart hook for pandahrms-skills plugin
#
# Scope gate: the always-on execution rules (hooks/execution-rules.md, ~1.2K tokens
# per session) are injected ONLY when this session looks like Pandahrms/Pandaworks
# work, i.e. when at least ONE of the following holds:
#   1. cwd is inside a git work tree whose `origin` remote points at a
#      pandaworks-software-plt (or pandaworks-sw) GitHub org repo.
#   2. a `.pandahrms-rules` marker file exists in cwd or any parent directory --
#      lets a non-git folder under a dev workspace opt in (e.g. deployment/ops
#      folders that aren't their own git checkout).
#   3. the env var PANDAHRMS_RULES=1 is set (manual override / testing).
# Outside those cases the rules describe workflows (TDD markers, EF migrations,
# gates, B1 English) that don't apply and would just burn context on every
# unrelated session -- personal projects, other folders, etc. -- so we still emit
# the same JSON envelope, just with an empty additionalContext, rather than
# skipping output.
#
# Team-neutral: no per-member ~/.claude/rules paths, no jq/python3 dependency --
# this hook also runs under git-bash on Windows via run-hook.cmd, where jq/python3
# are not guaranteed to be installed, so cwd is pulled out of the JSON payload with
# plain sed/grep, matching the pure-bash style already used below for JSON escaping.

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

warning_message=""

# Escape outputs for JSON using pure bash
escape_for_json() {
    local input="$1"
    local output=""
    local i char
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            $'\\') output+='\\' ;;
            '"') output+='\"' ;;
            $'\n') output+='\n' ;;
            $'\r') output+='\r' ;;
            $'\t') output+='\t' ;;
            *) output+="$char" ;;
        esac
    done
    printf '%s' "$output"
}

warning_escaped=$(escape_for_json "$warning_message")

# --- Scope gate --------------------------------------------------------------

# Read the SessionStart JSON payload from stdin. Never let an empty/absent stdin
# (or any command below) abort the hook under `set -e` -- every call that can
# fail is guarded with `|| true` or an `if` test.
stdin_payload="$(cat 2>/dev/null || true)"

# Pull the "cwd" field out of the JSON with sed/grep -- no jq/python3 dependency.
extract_cwd() {
    printf '%s' "$1" \
        | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n1 \
        | sed -E 's/.*"cwd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
        || true
}

session_cwd="$(extract_cwd "$stdin_payload")"
if [ -z "$session_cwd" ]; then
    session_cwd="${CLAUDE_PROJECT_DIR:-}"
fi
if [ -z "$session_cwd" ]; then
    session_cwd="${PWD:-}"
fi

# Condition 1: cwd is inside a git work tree whose origin remote is a Pandaworks
# org repo. `git -C` walks up from $session_cwd to find the work tree itself, so
# no manual parent-walk is needed here. Any failure (not a repo, no origin, etc.)
# is swallowed and simply means "no match".
origin_is_pandaworks() {
    local dir="$1" url
    [ -n "$dir" ] || return 1
    url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    [ -n "$url" ] || return 1
    [[ "$url" =~ github\.com[:/](pandaworks-software-plt|pandaworks-sw)/ ]]
}

# Condition 2: a `.pandahrms-rules` marker file in cwd or any ancestor, up to /.
marker_file_present() {
    local dir="$1"
    [ -n "$dir" ] || return 1
    while [ -n "$dir" ]; do
        if [ -f "$dir/.pandahrms-rules" ]; then
            return 0
        fi
        if [ "$dir" = "/" ]; then
            return 1
        fi
        dir="$(dirname "$dir" 2>/dev/null || true)"
    done
    return 1
}

should_inject_rules=false
if [ "${PANDAHRMS_RULES:-}" = "1" ]; then
    should_inject_rules=true
elif origin_is_pandaworks "$session_cwd"; then
    should_inject_rules=true
elif marker_file_present "$session_cwd"; then
    should_inject_rules=true
fi

# --- Rules injection -----------------------------------------------------------

# Load compact always-on execution rules (single source of truth, ships with
# plugin) -- only when the scope gate above says this session is Pandahrms /
# Pandaworks work. When the gate says no, rules_block stays empty, which yields
# exactly the same envelope shape this hook already produced whenever the rules
# file happened to be missing.
rules_block=""
if [ "$should_inject_rules" = true ]; then
    RULES_FILE="${PLUGIN_ROOT}/hooks/execution-rules.md"
    if [ -f "$RULES_FILE" ]; then
        rules_content="$(cat "$RULES_FILE")"
        rules_escaped=$(escape_for_json "$rules_content")
        rules_block="\\n\\n${rules_escaped}"
    fi
fi

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${warning_escaped}${rules_block}"
  }
}
EOF

exit 0
