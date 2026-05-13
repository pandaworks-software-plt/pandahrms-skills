#!/usr/bin/env bash
# UserPromptSubmit hook for pandahrms-skills plugin
# Injects a reminder to run pandahrms:optimise-prompt as the first tool call of every user turn.

set -euo pipefail

reminder='ENFORCE optimise-prompt on this turn.

Before any other tool call, invoke `Skill: pandahrms:optimise-prompt` UNLESS the user message matches one of these mechanical exemptions:
- A pure ack with no new verb or object: "yes", "ok", "got it", "continue", "stop", "skip", "cancel", "nevermind", "sounds good", "go ahead".
- A direct reply to an in-flight AskUserQuestion.
- A recursive self-call when optimise-prompt is already running.
- A message whose first non-whitespace character is "/" (slash-command skill trigger -- the slash command itself is the explicit intent).

This rule applies even in Auto mode. Auto mode is satisfied because optimise-prompt proceeds silently on CLEAR intent (it only calls AskUserQuestion when the request is genuinely AMBIGUOUS or UNDER-SPECIFIED). Running the skill on every turn costs one extra tool call; skipping it costs intent drift and rework.'

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
