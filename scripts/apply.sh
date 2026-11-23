#!/usr/bin/env bash
# Put engine/ on branch "opz" = $FIREFOX_TAG + patches/*.patch (in file-name order).
#   scripts/apply.sh           refuse if engine/ has local changes
#   scripts/apply.sh --force   throw away local changes in engine/ first
#                              (ignored files such as the objdir are kept)
# The previous "opz" branch is kept as opz-backup-<time> before being reset.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
. "$OPZ_ROOT/upstream.env"
[ -d "$OPZ_ENGINE/.git" ] || { echo "apply: run scripts/fetch.sh first" >&2; exit 1; }
cd "$OPZ_ENGINE"

if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
    echo "apply: a git am/rebase is in progress in engine/." >&2
    echo "       Finish it (git am --continue) or abort it (git am --abort) first." >&2
    exit 1
fi

base="$(git rev-parse --verify -q "refs/tags/$FIREFOX_TAG^{commit}")" \
    || { echo "apply: tag $FIREFOX_TAG not found in engine/ (re-run scripts/fetch.sh --force)" >&2; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
    if [ "${1:-}" = "--force" ]; then
        echo "apply: discarding local changes in engine/"
        git reset -q --hard
        git clean -q -fd
    else
        echo "apply: engine/ has local changes. Commit them and run scripts/export-patches.sh," >&2
        echo "       or re-run with --force to throw them away:" >&2
        git status --short | head -20 >&2
        exit 1
    fi
fi

if git rev-parse --verify -q refs/heads/opz >/dev/null &&
   [ "$(git rev-parse opz)" != "$base" ]; then
    backup="opz-backup-$(date +%Y%m%d-%H%M%S)"
    git branch -q "$backup" opz
    echo "apply: previous opz branch saved as $backup"
fi

git checkout -q -B opz "$base"

shopt -s nullglob
patches=("$OPZ_ROOT"/patches/*.patch)
n=0
for p in "${patches[@]}"; do
    if ! git am -q --3way "$p"; then
        echo "apply: FAILED on $(basename "$p")." >&2
        echo "       Fix the conflict in engine/, then: git add <files> && git am --continue" >&2
        echo "       and re-run scripts/export-patches.sh. Or: git am --abort" >&2
        exit 1
    fi
    n=$((n + 1))
done
# Overlays: directories that live in this repo are symlinked into engine/
# (and git-excluded there), so they are never part of the patches and edits
# in the repo are picked up directly.
overlay() {  # overlay <repo-relative source> <engine-relative target>
    local src="$OPZ_ROOT/$1" dst="$OPZ_ENGINE/$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "apply: $2 exists in engine/ and is not our symlink; refusing" >&2
        exit 1
    fi
    if [ "$OPZ_OS" = win ]; then
        # Windows: a junction (symlinks need admin rights there).
        if [ -L "$dst" ]; then opz_unjunction "$dst"; fi
        opz_junction "$dst" "$src"
    else
        # Relative link (portable: BSD realpath has no --relative-to).
        ln -sfn "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.path.realpath(sys.argv[2])))' "$src" "$(dirname "$dst")")" "$dst"
    fi
    grep -qxF "/$2" .git/info/exclude 2>/dev/null || echo "/$2" >> .git/info/exclude
    echo "apply: overlay $2 -> $1"
}
overlay branding/opz browser/branding/opz
# MAR signing certificates compiled into the updater (full builds only).
overlay updates/certs toolkit/mozapps/update/updater/opz-certs

echo "apply: engine/ is on branch opz = $FIREFOX_TAG + $n patch(es)"
