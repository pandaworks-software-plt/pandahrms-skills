#!/usr/bin/env bash
# Prints the working-tree hash that /verify records in .verify-result.json.
# Hash = sha256 of { git diff; git diff --cached; git status --porcelain; }
# taken from the repo root, excluding the two result files
# (.verify-result.json, .lint-gate-result.md) and, when given, the work folder.
#
# Usage: tree-hash.sh [--exclude <work-folder>]
# Portability: bash 3.2 and git-bash. Needs git plus shasum or sha256sum.
set -euo pipefail

exclude_dir=""
while [ $# -gt 0 ]; do
    case "$1" in
        --exclude) exclude_dir="${2:-}"; shift 2 ;;
        *) echo "tree-hash: unknown argument $1" >&2; exit 2 ;;
    esac
done

top="$(git rev-parse --show-toplevel)"
top_phys="$(cd "$top" && pwd -P)"

specs=". :(exclude,glob)**/.verify-result.json :(exclude,glob)**/.lint-gate-result.md"
if [ -n "$exclude_dir" ] && [ -d "$exclude_dir" ]; then
    abs="$(cd "$exclude_dir" && pwd -P)"
    case "$abs" in
        "$top_phys"/*) specs="$specs :(exclude)${abs#"$top_phys"/}" ;;
    esac
fi

hash_cmd() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum
    else echo "tree-hash: shasum or sha256sum required" >&2; exit 127
    fi
}

cd "$top"
# shellcheck disable=SC2086
{ git diff -- $specs; git diff --cached -- $specs; git status --porcelain -- $specs; } | hash_cmd | cut -d' ' -f1
