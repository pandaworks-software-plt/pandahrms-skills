#!/usr/bin/env bash
# UserPromptSubmit hook for pandahrms-skills plugin
# Injects the slim per-turn repeat-back reminder. Full rubric: hooks/execution-rules.md, "Repeat-back (intent lock)".

set -euo pipefail

reminder='Repeat-back rule (rubric: execution-rules "Repeat-back (intent lock)").

Before any other tool call, restate the request in one B1-English line: "You want to <verb> <object> [qualifier]." Then proceed in the same turn.
If any rubric trigger fires (hedging, fragment/single noun, trailing "?", pronoun with 2+ referents, verb with two meanings, two readings, missing required field, two tasks in one request), call AskUserQuestion FIRST.
Exemptions: message starts with "/", "!" or "$"; pure acks ("yes", "ok", "go ahead", "stop", ...); a direct reply to an in-flight AskUserQuestion.
This applies even in Auto mode -- the restatement line does not pause the turn.'

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

reminder_escaped=$(escape_for_json "$reminder")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "${reminder_escaped}"
  }
}
EOF

exit 0
