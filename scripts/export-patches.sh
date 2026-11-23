#!/usr/bin/env bash
# Write every commit on engine/ branch "opz" since $FIREFOX_TAG to
# patches/NNNN-<subject>.patch (one commit = one patch). Old patches/*.patch
# are replaced, so patches/ always mirrors the branch exactly.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
. "$OPZ_ROOT/upstream.env"
cd "$OPZ_ENGINE"

base="$(git rev-parse --verify -q "refs/tags/$FIREFOX_TAG^{commit}")" \
    || { echo "export: tag $FIREFOX_TAG not found in engine/" >&2; exit 1; }
if [ "$(git symbolic-ref -q --short HEAD || true)" != "opz" ]; then
    echo "export: engine/ is not on branch opz (run scripts/apply.sh first)" >&2
    exit 1
fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "export: engine/ has uncommitted changes; commit them first:" >&2
    git status --short --untracked-files=no | head -20 >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "export: note: untracked files in engine/ are NOT exported:" >&2
    git status --short | head -10 >&2
fi

out="$(mktemp -d "$TMPDIR/export.XXXXXX")"
git format-patch -q --zero-commit --no-signature --no-numbered \
    -o "$out" "$base..opz"

mkdir -p "$OPZ_ROOT/patches"
find "$OPZ_ROOT/patches" -maxdepth 1 -name '*.patch' -delete
shopt -s nullglob
files=("$out"/*.patch)
if [ "${#files[@]}" -gt 0 ]; then
    mv "${files[@]}" "$OPZ_ROOT/patches/"
fi
rmdir "$out"
echo "export: ${#files[@]} patch(es) written to patches/"
git -C "$OPZ_ROOT" status --short -- patches/
