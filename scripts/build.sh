#!/usr/bin/env bash
# Build engine/ with $MOZCONFIG (artifact build: downloads the prebuilt
# C++/Rust parts matching the checked-out revision, builds JS/CSS locally).
#   scripts/build.sh            full (artifact) build
#   scripts/build.sh faster     only browser front-end files (JS/CSS/HTML)
set -euo pipefail
. "$(dirname "$0")/../env.sh"
[ -d "$OPZ_ENGINE" ] || { echo "build: run scripts/fetch.sh first" >&2; exit 1; }

opz_guard_start
cd "$OPZ_ENGINE"
start=$(date +%s)
# Full builds: one build ID for the whole build. Left alone, an incremental
# build writes several (binaries, platform.ini and application.ini end up
# with different IDs), and the updater compares the compiled-in one with
# update.xml, so an installed copy would keep "updating" to itself.
# scripts/release.sh packages with the same MOZ_BUILD_DATE (saved below).
if [ "$OPZ_BUILD" = full ] && [ "${1:-}" != faster ]; then
    export MOZ_BUILD_DATE="${MOZ_BUILD_DATE:-$(date +%Y%m%d%H%M%S)}"
    mkdir -p "$OPZ_OBJDIR"
    echo "$MOZ_BUILD_DATE" > "$OPZ_OBJDIR/.opz-build-date"
    echo "build: build ID $MOZ_BUILD_DATE"
    # libxul gets its own copy of the build ID (toolkit/library/buildid.cpp),
    # regenerated only when libxul is relinked. Dropping its make stamp makes
    # every full build regenerate it with this ID and relink libxul
    # (scripts/release.sh checks that all IDs match).
    rm -f "$OPZ_OBJDIR/toolkit/library/.deps/buildid.cpp.stub"
elif [ "$OPZ_BUILD" = full ] && [ -f "$OPZ_OBJDIR/.opz-build-date" ]; then
    MOZ_BUILD_DATE="$(cat "$OPZ_OBJDIR/.opz-build-date")"
    export MOZ_BUILD_DATE
fi
./mach build "$@"
# The artifact binary uses Firefox's compiled-in app data (Name=Firefox,
# RemotingName=firefox, browser/app/nsBrowserApp.cpp kStaticAppData). Opz's own
# application.ini (Name=Opz, RemotingName=opz -> profile ~/.config/mozilla/opz,
# Wayland app_id opz) is used by pointing XUL_APP_FILE at a copy placed in the
# app directory dist/bin/browser/ (see scripts/run.sh).
cp "$OPZ_OBJDIR/dist/bin/application.ini" "$OPZ_OBJDIR/dist/bin/browser/application.ini"
# Keep the web-facing User-Agent identical to Firefox ("... Firefox/159.0").
# Without this the UA ends in "Opz/159.0.1" and sites such as Google sign-in
# treat Opz as an unknown browser (they served the "WebLiteSignIn" page).
# UAName is read from [App] by toolkit/xre/CreateAppData.cpp and used by
# netwerk/protocol/http/nsHttpHandler.cpp (MOZ_APP_UA_NAME is compiled into the
# prebuilt binary, so it cannot be set from the mozconfig).
opz_sed_i '/^Name=/a\
UAName=Firefox
' "$OPZ_OBJDIR/dist/bin/browser/application.ini"
# Debloat settings (milestone 4), linked so edits only need a browser restart:
#   prefs/policies.json -> dist/bin/distribution/policies.json   (enterprise policies)
#   prefs/opz.js        -> dist/bin/browser/defaults/preferences/00-opz.js (default prefs)
# Pref files in a directory are read in REVERSE alphabetical order
# (modules/libpref/Preferences.cpp pref_CompareFileNames), so the "00-" name
# makes ours load after firefox.js and win.
mkdir -p "$OPZ_OBJDIR/dist/bin/distribution"
if [ "$OPZ_OS" = win ]; then
    # Windows: copies, since symlinks need admin rights there. After editing
    # prefs/, run scripts/build.sh again (or build.sh faster).
    cp -f "$OPZ_ROOT/prefs/policies.json" "$OPZ_OBJDIR/dist/bin/distribution/policies.json"
    cp -f "$OPZ_ROOT/prefs/opz.js" "$OPZ_OBJDIR/dist/bin/browser/defaults/preferences/00-opz.js"
else
    ln -sfn "$OPZ_ROOT/prefs/policies.json" "$OPZ_OBJDIR/dist/bin/distribution/policies.json"
    ln -sfn "$OPZ_ROOT/prefs/opz.js" "$OPZ_OBJDIR/dist/bin/browser/defaults/preferences/00-opz.js"
fi
# macOS: mach copies dist/bin into dist/<Name>.app/Contents/Resources during
# the build, i.e. before the links above exist; link them there as well so a
# build on a clean objdir is complete without a second run.
if [ "$OPZ_OS" = mac ]; then
    for app in "$OPZ_OBJDIR"/dist/*.app; do
        mkdir -p "$app/Contents/Resources/distribution"
        ln -sfn "$OPZ_ROOT/prefs/policies.json" "$app/Contents/Resources/distribution/policies.json"
        ln -sfn "$OPZ_ROOT/prefs/opz.js" "$app/Contents/Resources/browser/defaults/preferences/00-opz.js"
    done
fi
echo "build: finished in $(( $(date +%s) - start ))s"
opz_guard_check
