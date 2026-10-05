#!/usr/bin/env bash
# Audits every skill file against the plugin layout rules in CLAUDE.md:
#   1. SKILL.md body is 500 lines or fewer.
#   2. Any skills/**/*.md over 100 lines opens with a "## Contents" list whose
#      entries match the file's H2 headings (outside fenced code), and every
#      indented sub-entry names a heading or bold phase line in the file.
#   3. A reference file never links another reference file (one level deep).
#   4. Frontmatter has name + description and no runtime "model:" key.
#
# Usage: scripts/skill-audit.sh        (from anywhere; resolves the plugin root)
# Exit 0 when clean, 1 when any check fails. Portability: bash 3.2, git-bash.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$root"
fail=0
tmpdir="${TMPDIR:-/tmp}"
problem() { printf 'FAIL  %s\n' "$1"; fail=1; }

# H2 headings outside fenced code blocks (excluding "Contents").
h2_outside_fences() {
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { next }
        /^## / { t = substr($0, 4); sub(/[[:space:]]+$/, "", t); if (t != "Contents") print t }
    ' "$1"
}
# Entries listed under "## Contents" until the next H2: "<level>\t<text>".
contents_entries() {
    awk '
        /^## Contents[[:space:]]*$/ { on = 1; next }
        on && /^## / { exit }
        on && /^- / { print "0\t" substr($0, 3) }
        on && /^  - / { print "1\t" substr($0, 5) }
    ' "$1"
}

for f in $(find skills -name '*.md' | sort); do
    lines=$(wc -l < "$f" | tr -d ' ')
    base=$(basename "$f")

    if [ "$base" = "SKILL.md" ]; then
        [ "$lines" -le 500 ] || problem "$f has $lines lines (limit 500) -- split into references/"
        head -n1 "$f" | grep -q '^---$' || problem "$f has no frontmatter"
        awk 'NR==1{next} /^---$/{exit} {print}' "$f" > "$tmpdir/skill-audit-fm.$$"
        grep -q '^name:' "$tmpdir/skill-audit-fm.$$" || problem "$f frontmatter lacks name"
        grep -q '^description:' "$tmpdir/skill-audit-fm.$$" || problem "$f frontmatter lacks description"
        grep -q '^model:' "$tmpdir/skill-audit-fm.$$" && problem "$f frontmatter sets model: (runtime override, not documentation)"
        rm -f "$tmpdir/skill-audit-fm.$$"
    fi

    if [ "$lines" -gt 100 ]; then
        if ! grep -q '^## Contents[[:space:]]*$' "$f"; then
            problem "$f has $lines lines and no '## Contents' list"
        else
            h2_outside_fences "$f" > "$tmpdir/skill-audit-h2.$$"
            contents_entries "$f" > "$tmpdir/skill-audit-ce.$$"
            while IFS= read -r h; do
                [ -n "$h" ] || continue
                grep -qxF "0	$h" "$tmpdir/skill-audit-ce.$$" || problem "$f: heading '$h' missing from Contents"
            done < "$tmpdir/skill-audit-h2.$$"
            while IFS='	' read -r lvl e; do
                [ -n "$e" ] || continue
                if [ "$lvl" = "0" ]; then
                    grep -qxF "$e" "$tmpdir/skill-audit-h2.$$" || problem "$f: Contents entry '$e' is not an H2 heading"
                else
                    grep -qF "$e" "$f" || problem "$f: Contents sub-entry '$e' not found in file"
                fi
            done < "$tmpdir/skill-audit-ce.$$"
            rm -f "$tmpdir/skill-audit-h2.$$" "$tmpdir/skill-audit-ce.$$"
        fi
    fi

    case "$f" in
        */references/*)
            # A reference may name SKILL.md, CLAUDE.md, AGENTS.md or itself; never another reference.
            hits=$(grep -oE '[A-Za-z0-9_./-]+\.md' "$f" | grep -vE '^(SKILL|CLAUDE|AGENTS)\.md$' | grep -vF "$base" | sort -u || true)
            [ -z "$hits" ] || problem "$f links other files ($(echo "$hits" | tr '\n' ' ')) -- keep references one level deep"
            ;;
    esac
done

if [ "$fail" -eq 0 ]; then
    echo "skill-audit: PASS"
else
    echo "skill-audit: FAIL"
fi
exit "$fail"
