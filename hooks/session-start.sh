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
# Team-neutral: no per-member host configuration paths, no jq/python3 dependency --
# this hook also runs under git-bash on Windows via run-hook.cmd, where jq/python3
# are not guaranteed to be installed, so cwd is pulled out of the JSON payload with
# plain sed/grep, matching the pure-bash style already used below for JSON escaping.
#
# Portability contract: bash 3.2 (macOS /bin/bash) and git-bash on Windows. No
# bash 4 syntax (no associative arrays, no ${var^^}, no printf '\uXXXX').

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

warning_message=""

# Escape a string for embedding in a JSON string literal.
#
# Uses bash's native global substitution rather than a character-by-character
# loop: the loop cost ~0.6s for the 4.9KB rules file on macOS and several times
# that under MSYS2, on every startup/resume/clear/compact of a blocking hook.
# The backslash pass MUST run first, or the backslashes introduced by the later
# passes would themselves be escaped again.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

warning_escaped=$(escape_for_json "$warning_message")

# --- Scope gate --------------------------------------------------------------

# Read the SessionStart JSON payload from stdin. Never let an empty/absent stdin
# (or any command below) abort the hook under `set -e` -- every call that can
# fail is guarded with `|| true` or an `if` test.
#
# `read -t` rather than `cat`: a plain `cat` blocks forever when stdin is an open
# pipe that never sends EOF, which is reachable on Windows where the payload
# crosses cmd.exe -> bash.exe. This is a BLOCKING SessionStart hook, so that hang
# freezes the whole CLI -- the spinner never stops and later slash commands queue
# behind it. `-d ''` reads to EOF (JSON contains no NUL) and still populates the
# variable when the timeout fires, so a slow writer degrades to a partial read
# rather than a hang.
stdin_payload=""
if [ ! -t 0 ]; then
    IFS= read -r -d '' -t 5 stdin_payload 2>/dev/null || true
fi

# Pull the "cwd" field out of the JSON with sed/grep -- no jq/python3 dependency.
extract_cwd() {
    printf '%s' "$1" \
        | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n1 \
        | sed -E 's/.*"cwd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
        || true
}

# Decode JSON string escapes in an extracted path.
#
# grep/sed hand back the RAW string body, so a Windows cwd arrives as
# `C:\\Works\\Repo` (JSON for `C:\Works\Repo`). Feeding that to `git -C` or a
# `[ -f ... ]` test looks up a path that does not exist, so without this the
# scope gate could never match on Windows and the rules silently never loaded.
#
# Scans left to right rather than running global replaces, because `\\n` (a
# literal backslash then n) and `\n` (a newline) only stay distinct in a
# single ordered pass. Paths are short, so the loop cost is negligible.
# `\uXXXX` is left verbatim: decoding it needs bash 4.2 printf, and a non-ASCII
# repo path can still opt in via .pandahrms-rules or PANDAHRMS_RULES=1.
json_unescape() {
    local s="$1" out="" i=0 c n
    while [ "$i" -lt "${#s}" ]; do
        c="${s:$i:1}"
        if [ "$c" = '\' ] && [ "$i" -lt "$(( ${#s} - 1 ))" ]; then
            i=$(( i + 1 ))
            n="${s:$i:1}"
            case "$n" in
                n)  out="$out"$'\n' ;;
                r)  out="$out"$'\r' ;;
                t)  out="$out"$'\t' ;;
                b)  out="$out"$'\b' ;;
                f)  out="$out"$'\f' ;;
                u)  out="$out\\u" ;;
                *)  out="$out$n" ;;
            esac
        else
            out="$out$c"
        fi
        i=$(( i + 1 ))
    done
    printf '%s' "$out"
}

session_cwd="$(extract_cwd "$stdin_payload")"
if [ -n "$session_cwd" ]; then
    session_cwd="$(json_unescape "$session_cwd")"
fi
if [ -z "$session_cwd" ]; then
    session_cwd="${CODEX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
fi
if [ -z "$session_cwd" ]; then
    session_cwd="${PWD:-}"
fi

# Normalise a Windows drive path to forward slashes. git and the `[ -f ]` test
# both accept them under git-bash, and POSIX `dirname` only walks on "/" -- given
# backslashes it collapses `C:\Works\Repo` to "." in a single step, which killed
# the ancestor walk below. Only drive-letter paths are touched, so a backslash in
# a genuine POSIX filename is left alone.
case "$session_cwd" in
    [A-Za-z]:*) session_cwd="${session_cwd//\\//}" ;;
esac

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

# Condition 2: a `.pandahrms-rules` marker file in cwd or any ancestor, up to the
# filesystem root -- "/" on Unix, or a drive root such as `C:/` on Windows. Stop
# as soon as the parent stops changing too: `dirname` is a fixed point at both
# roots and at ".", and because this is a blocking SessionStart hook an unguarded
# walk spun forever and hung the whole session.
marker_file_present() {
    local dir="$1" parent
    [ -n "$dir" ] || return 1
    while [ -n "$dir" ]; do
        if [ -f "$dir/.pandahrms-rules" ]; then
            return 0
        fi
        case "$dir" in
            /|//|.|[A-Za-z]:|[A-Za-z]:/) return 1 ;;
        esac
        parent="$(dirname "$dir" 2>/dev/null || true)"
        if [ -z "$parent" ] || [ "$parent" = "$dir" ]; then
            return 1
        fi
        dir="$parent"
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
