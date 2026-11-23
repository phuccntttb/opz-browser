#!/usr/bin/env bash
# macOS: install (or update) the Opz you use every day from this repo's build.
# Called by scripts/install-local.sh on macOS; same options:
#
#   scripts/install-local.sh              build.sh, then install into ~/Applications/Opz.app
#   scripts/install-local.sh --no-package install the current build as is (no build.sh)
#   scripts/install-local.sh --wait       if Opz is open: wait until you quit it,
#                                         install, then start it again
#   scripts/install-local.sh --rollback   put back the previous install (Opz.prev.app)
#   OPZ_INSTALL_DIR=/path/Opz.app scripts/install-local.sh   install somewhere else
#
# Daily-use vs dev:
#   installed  ~/Applications/Opz.app      profile ~/Library/Application Support/Opz
#              bundle id org.opz.browser   (independent of the repo and objdir)
#   dev        scripts/run.sh              throw-away profile in the objdir
#              bundle id org.mozilla.opzbrowser
# Both can run at the same time.
#
# The dev bundle (objdir/dist/Opz Browser.app) is full of symlinks into the
# source tree and the objdir, and its "firefox" binary uses Firefox's
# compiled-in app data unless XUL_APP_FILE is set (scripts/run.sh does that).
# The installed copy therefore gets:
#   - every absolute symlink replaced by the file it points to
#   - Contents/MacOS/opz: launcher that sets XUL_APP_FILE to
#     Contents/Resources/browser/application.ini and execs firefox
#     (CFBundleExecutable=opz, so Finder/Dock/open use it)
#   - its own name and bundle id, then an ad-hoc signature
# The profile is never touched.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
[ "$OPZ_OS" = mac ] || { echo "install-local-mac: macOS only" >&2; exit 1; }

dest="${OPZ_INSTALL_DIR:-$HOME/Applications/Opz.app}"
bundle_id="org.opz.browser"
do_build=1 wait=0 rollback=0
for a in "$@"; do
    case "$a" in
        --no-package) do_build=0 ;;
        --wait)       wait=1 ;;
        --rollback)   rollback=1 ;;
        -h|--help)    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install-local: unknown argument $a (see --help)" >&2; exit 1 ;;
    esac
done

case "$dest" in *.app) ;; *)
    echo "install-local: install dir must end in .app (got $dest)" >&2; exit 1 ;;
esac
parent="$(dirname "$dest")"
mkdir -p "$parent"
parent="$(cd "$parent" && pwd -P)"
name="$(basename "$dest" .app)"
dest="$parent/$name.app"
prev="$parent/$name.prev.app"

# PIDs of processes running from the installed bundle.
running_pids() { pgrep -f "^$dest/Contents/MacOS/" || true; }

was_running=0
wait_closed() {
    [ -n "$(running_pids)" ] || return 0
    was_running=1
    if [ "$wait" -eq 0 ]; then
        echo "install-local: Opz is running from $dest. Quit it first (Cmd+Q), or rerun with --wait." >&2
        exit 1
    fi
    echo "install-local: Opz is running; quit it (Cmd+Q, tabs are restored on the next start). Waiting..."
    while [ -n "$(running_pids)" ]; do sleep 1; done
}

start_again() {
    [ "$was_running" -eq 1 ] || return 0
    echo "install-local: starting Opz again"
    open "$dest"
}

if [ "$rollback" -eq 1 ]; then
    [ -x "$prev/Contents/MacOS/opz" ] || { echo "install-local: no previous install at $prev" >&2; exit 1; }
    wait_closed
    tmp="$parent/.opz-swap.$$.app"
    mv "$dest" "$tmp" 2>/dev/null || true
    mv "$prev" "$dest"
    [ -d "$tmp" ] && mv "$tmp" "$prev"
    echo "install-local: rolled back to $("$dest/Contents/MacOS/opz" --version 2>/dev/null)"
    start_again
    exit 0
fi

[ "$do_build" -eq 1 ] && "$OPZ_ROOT/scripts/build.sh"

shopt -s nullglob
apps=("$OPZ_OBJDIR"/dist/*.app)
[ "${#apps[@]}" -eq 1 ] || { echo "install-local: expected one .app in $OPZ_OBJDIR/dist, found ${#apps[@]}; run scripts/build.sh" >&2; exit 1; }
src="${apps[0]}"
ini="$OPZ_OBJDIR/dist/bin/browser/application.ini"
grep -qx "UAName=Firefox" "$ini" || { echo "install-local: $ini lacks UAName; run scripts/build.sh" >&2; exit 1; }
echo "install-local: installing $(basename "$src") into $dest"

# Copy next to the target (same volume, so the swap is a rename).
new="$parent/.opz-new.$$.app"
trap 'rm -rf "$new"' EXIT
ditto "$src" "$new"

# Replace absolute symlinks (into the source tree / objdir) by real copies.
find "$new" -type l | while IFS= read -r l; do
    t="$(readlink "$l")"
    case "$t" in /*) ;; *) continue ;; esac
    [ -e "$t" ] || { echo "install-local: dangling link $l -> $t" >&2; exit 1; }
    rm "$l"
    cp -RL "$t" "$l"
done
[ -z "$(find "$new" -type l -lname '/*')" ] || { echo "install-local: absolute symlinks left in bundle" >&2; exit 1; }

res="$new/Contents/Resources"
# Opz app data (Name=Opz -> profile "Opz", UAName=Firefox), same as dist/bin.
install -m 644 "$ini" "$res/browser/application.ini"
mkdir -p "$res/distribution" "$res/browser/defaults/preferences"
install -m 644 "$OPZ_ROOT/prefs/policies.json" "$res/distribution/policies.json"
install -m 644 "$OPZ_ROOT/prefs/opz.js" "$res/browser/defaults/preferences/00-opz.js"

cat > "$new/Contents/MacOS/opz" <<'EOF'
#!/bin/sh
# Opz launcher: use Opz's app data instead of Firefox's compiled-in one.
here="$(cd "$(dirname "$0")" && pwd -P)"
export XUL_APP_FILE="$here/../Resources/browser/application.ini"
exec "$here/firefox" "$@"
EOF
chmod 755 "$new/Contents/MacOS/opz"

plist="$new/Contents/Info.plist"
plutil -replace CFBundleExecutable -string opz "$plist"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$plist"
plutil -replace CFBundleName -string "$name" "$plist"
plutil -replace CFBundleDisplayName -string "$name" "$plist"

xattr -cr "$new"
codesign --force --deep --sign - "$new" >/dev/null 2>&1 \
    || { echo "install-local: codesign failed" >&2; codesign --force --deep --sign - "$new"; exit 1; }

ver_line="$("$new/Contents/MacOS/opz" --version 2>/dev/null || true)"
case "$ver_line" in *"Opz "*) ;; *) echo "install-local: version check failed: '$ver_line'" >&2; exit 1 ;; esac

wait_closed
rm -rf "$prev"
[ -d "$dest" ] && mv "$dest" "$prev"
mv "$new" "$dest"
trap - EXIT
# Tell LaunchServices about the (new) bundle so Spotlight/Launchpad/Dock see it.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest" 2>/dev/null || true
# The build ID does not change between builds of the same Firefox version, so
# a profile's startup cache (compiled chrome JS/CSS) would keep running the old
# code. It is rebuilt on the next start.
rm -rf "$HOME/Library/Caches/$name"/Profiles/*/startupCache

echo "install-local: installed $ver_line"
echo "install-local: open it with: open \"$dest\"  (profile: ~/Library/Application Support/Opz)"
[ -d "$prev" ] && echo "install-local: previous copy kept at $prev (undo: scripts/install-local.sh --rollback)"
start_again
