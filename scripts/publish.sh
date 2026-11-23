#!/usr/bin/env bash
# Copy a release's update-server files to $OPZ_UPDATE_PUBLISH (rsync).
#   scripts/publish.sh [site-dir]     default: dist/release/site
# scripts/release.sh --publish runs it; run it on its own for a release made
# on a machine without rsync (Windows; the GitHub Actions release does that).
# Needs only rsync and updates/update.env, not the build environment.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$root/updates/update.env"
site="${1:-$root/dist/release/site}"
die() { echo "publish: $*" >&2; exit 1; }
[ -n "$OPZ_UPDATE_PUBLISH" ] || die "OPZ_UPDATE_PUBLISH is empty (updates/update.env)"
[ -d "$site/files" ] || die "$site/files missing; run scripts/release.sh first"
ls "$site"/*/update.xml > /dev/null 2>&1 || die "no */update.xml in $site"
command -v rsync > /dev/null || die "rsync not found"

# latest/* must be symlinks into files/. Where it is a copy (made on Windows,
# or by a download of the release), point it back at the same file in files/.
for f in "$site"/latest/*; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    size="$(wc -c < "$f" | tr -d ' ')"
    match=""
    for g in "$site"/files/*; do
        [ -f "$g" ] && [ ! -L "$g" ] || continue
        [ "$(wc -c < "$g" | tr -d ' ')" = "$size" ] && cmp -s "$f" "$g" && { match="$(basename "$g")"; break; }
    done
    [ -n "$match" ] || die "latest/$(basename "$f") is not a copy of anything in files/"
    ln -sfn "../files/$match" "$f"
done

dest="${OPZ_UPDATE_PUBLISH%/}"
echo "publish: $site -> $dest"
# Files first, update.xml last: a client must never see an update.xml whose
# MAR is not there yet. Nothing is deleted on the server.
# -l: latest/* are symlinks; files/ sorts before latest/, so a link's target
# is always uploaded first.
rsync -rtlv --exclude update.xml "$site/" "$dest/"
rsync -rtlv "$site/" "$dest/"
echo "publish: done; installed copies pick it up at their next update check"
