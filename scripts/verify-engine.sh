#!/usr/bin/env bash
# Re-hash every tracked file in engine/ and compare with git's objects.
# `git status` trusts cached stat data and cannot see silent disk corruption;
# this uses a throw-away index with no stat data, so git must read every file.
# Local edits (patches applied, uncommitted work) also show up as mismatches.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
cd "$OPZ_ENGINE"

export GIT_INDEX_FILE="$TMPDIR/verify-engine.index"
: > "$GIT_INDEX_FILE.list"
start=$(date +%s)
git read-tree HEAD
git update-index -q --refresh > /dev/null || true
git diff-files --name-only > "$GIT_INDEX_FILE.list"
bad=$(wc -l < "$GIT_INDEX_FILE.list")
total=$(git ls-files | wc -l)
echo "verify: $total files checked in $(( $(date +%s) - start ))s, $bad differ from HEAD"
if [ "$bad" -ne 0 ]; then
    head -20 "$GIT_INDEX_FILE.list"
    echo "verify: full list in $GIT_INDEX_FILE.list" >&2
    exit 1
fi
