#!/usr/bin/env bash
# Checks whether <work-folder>/.verify-result.json still proves a PASS for the
# current working tree. Exit 0 and "VALID <timestamp>" when it does; otherwise
# exit 1 with MISSING | FAIL | STALE and a reason.
#
# Usage: check-result.sh <work-folder>
# Portability: bash 3.2 and git-bash. Needs git plus shasum or sha256sum.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
wf="${1:-}"
[ -n "$wf" ] || { echo "usage: check-result.sh <work-folder>" >&2; exit 2; }

f="$wf/.verify-result.json"
if [ ! -f "$f" ]; then
    echo "MISSING $f"
    exit 1
fi

field() {
    sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$f" | head -n1
}
result="$(field result)"
recorded="$(field tree_hash)"
ts="$(field timestamp)"

if [ "$result" != "PASS" ]; then
    echo "FAIL recorded result is ${result:-unknown} (${ts:-no timestamp})"
    exit 1
fi

now="$(bash "$dir/tree-hash.sh" --exclude "$wf")"
if [ "$now" != "$recorded" ]; then
    echo "STALE tree changed since PASS at ${ts:-unknown}"
    exit 1
fi

echo "VALID $ts"
