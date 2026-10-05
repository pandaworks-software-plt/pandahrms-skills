#!/usr/bin/env bash
# Writes <work-folder>/.verify-result.json for /verify.
# Computes timestamp and tree_hash itself; prints the written path.
#
# Usage: write-result.sh --work-folder <dir> --result PASS|FAIL \
#          --build "<stage status>" --tests "<stage status>" --coverage "<stage status>"
# Portability: bash 3.2 and git-bash. Needs git plus shasum or sha256sum.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
wf=""; result=""; build=""; tests=""; coverage=""
while [ $# -gt 0 ]; do
    case "$1" in
        --work-folder) wf="${2:-}"; shift 2 ;;
        --result)      result="${2:-}"; shift 2 ;;
        --build)       build="${2:-}"; shift 2 ;;
        --tests)       tests="${2:-}"; shift 2 ;;
        --coverage)    coverage="${2:-}"; shift 2 ;;
        *) echo "write-result: unknown argument $1" >&2; exit 2 ;;
    esac
done

if [ -z "$wf" ] || [ -z "$result" ] || [ -z "$build" ] || [ -z "$tests" ] || [ -z "$coverage" ]; then
    echo "usage: write-result.sh --work-folder <dir> --result PASS|FAIL --build <s> --tests <s> --coverage <s>" >&2
    exit 2
fi
case "$result" in
    PASS|FAIL) ;;
    *) echo "write-result: --result must be PASS or FAIL" >&2; exit 2 ;;
esac
[ -d "$wf" ] || { echo "write-result: work folder not found: $wf" >&2; exit 1; }

esc() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
th="$(bash "$dir/tree-hash.sh" --exclude "$wf")"
out="$wf/.verify-result.json"
tmp="$out.tmp.$$"
printf '{\n  "result": "%s",\n  "build": "%s",\n  "tests": "%s",\n  "coverage": "%s",\n  "timestamp": "%s",\n  "tree_hash": "%s"\n}\n' \
    "$result" "$(esc "$build")" "$(esc "$tests")" "$(esc "$coverage")" "$ts" "$th" > "$tmp"
mv "$tmp" "$out"
echo "$out"
