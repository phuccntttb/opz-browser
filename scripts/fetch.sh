#!/usr/bin/env bash
# Shallow-clone the Firefox release tag from upstream.env into engine/.
#   scripts/fetch.sh           fail if engine/ already exists
#   scripts/fetch.sh --force   delete engine/ (incl. objdir) and clone again
set -euo pipefail
. "$(dirname "$0")/../env.sh"
. "$OPZ_ROOT/upstream.env"

if [ -e "$OPZ_ENGINE" ]; then
    if [ "${1:-}" = "--force" ]; then
        # Never lose work: engine/ must match patches/ before it is deleted.
        if [ -d "$OPZ_ENGINE/.git" ]; then
            if [ -n "$(git -C "$OPZ_ENGINE" status --porcelain --untracked-files=no)" ]; then
                echo "fetch: engine/ has uncommitted changes; commit + scripts/export-patches.sh first" >&2
                exit 1
            fi
            if git -C "$OPZ_ENGINE" rev-parse --verify -q refs/heads/opz >/dev/null; then
                root="$(git -C "$OPZ_ENGINE" rev-list --max-parents=0 opz | tail -1)"
                chk="$TMPDIR/fetch-check"
                rm -rf "$chk"; mkdir -p "$chk"
                git -C "$OPZ_ENGINE" format-patch -q --zero-commit --no-signature --no-numbered \
                    -o "$chk" "$root..opz"
                if ! diff -rq -x .gitkeep "$chk" "$OPZ_ROOT/patches" >/dev/null; then
                    echo "fetch: branch opz in engine/ differs from patches/; run scripts/export-patches.sh first" >&2
                    diff -rq -x .gitkeep "$chk" "$OPZ_ROOT/patches" >&2 || true
                    exit 1
                fi
                rm -rf "$chk"
            fi
        fi
        echo "fetch: removing existing $OPZ_ENGINE"
        rm -rf "$OPZ_ENGINE"
    else
        echo "fetch: $OPZ_ENGINE already exists (use --force to re-fetch)" >&2
        exit 1
    fi
fi

opz_guard_start
echo "fetch: cloning $FIREFOX_TAG (depth 1) from $FIREFOX_REPO"
# core.autocrlf=false: Git for Windows usually defaults to true, which would
# rewrite the line endings of the whole tree (breaking scripts and patches).
clone_opts=(--config core.autocrlf=false)
if [ "$OPZ_OS" = win ]; then
    clone_opts+=(--config core.longpaths=true)
fi
git clone "${clone_opts[@]}" --depth 1 --single-branch --branch "$FIREFOX_TAG" \
    "$FIREFOX_REPO" "$OPZ_ENGINE"
# Windows: the source lives at a short path outside the repo (env.sh);
# <repo>/engine points to it.
if [ "$OPZ_OS" = win ] && [ ! -e "$OPZ_ROOT/engine" ]; then
    opz_junction "$OPZ_ROOT/engine" "$OPZ_ENGINE"
fi
# Local identity for the patch branch commits inside engine/.
git -C "$OPZ_ENGINE" config user.name  "Opz Browser"
git -C "$OPZ_ENGINE" config user.email "opz@localhost"
"$OPZ_ROOT/scripts/verify-engine.sh"
echo "fetch: engine at $(git -C "$OPZ_ENGINE" rev-parse HEAD) ($FIREFOX_TAG)"
opz_guard_check
