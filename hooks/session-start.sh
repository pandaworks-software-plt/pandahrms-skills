#!/usr/bin/env bash
# SessionStart hook for pandahrms-skills plugin

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build skill list from skills directory
skills_list=""
for skill_dir in "${PLUGIN_ROOT}/skills"/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name=$(basename "$skill_dir")
        # Extract description from YAML frontmatter (BSD sed compatible)
        description=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); print; exit}' "${skill_dir}SKILL.md")
        if [ -n "$skills_list" ]; then
            skills_list="${skills_list}\n- pandahrms-skills:${skill_name}: ${description}"
        else
            skills_list="- pandahrms-skills:${skill_name}: ${description}"
        fi
    fi
done

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

skills_escaped=$(escape_for_json "$skills_list")

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "PandaHRMS skills available (use Skill tool to invoke):\n${skills_escaped}"
  }
}
EOF

exit 0
