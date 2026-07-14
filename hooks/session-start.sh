#!/usr/bin/env bash
# SessionStart hook for pandahrms-skills plugin

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

# Load compact always-on execution rules (single source of truth, ships with plugin)
rules_block=""
RULES_FILE="${PLUGIN_ROOT}/hooks/execution-rules.md"
if [ -f "$RULES_FILE" ]; then
    rules_content="$(cat "$RULES_FILE")"
    rules_escaped=$(escape_for_json "$rules_content")
    rules_block="\\n\\n${rules_escaped}"
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
