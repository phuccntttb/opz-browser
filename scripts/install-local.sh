#!/usr/bin/env bash
# Install (or update) the Opz you use every day from this repo's build.
#
#   scripts/install-local.sh              package.sh, then install into ~/Apps/opz
#   scripts/install-local.sh --no-package install the newest dist/ tarball as is
#   scripts/install-local.sh --wait       if Opz is open: wait until you close it,
#                                         install, then start it again
#   scripts/install-local.sh --rollback   put back the previous install (~/Apps/opz.prev)
#   OPZ_INSTALL_DIR=/path/opz scripts/install-local.sh   install somewhere else
#
# The swap is safe: the new copy is unpacked next to the old one and checked
# ("opz --version" must say Opz) before it replaces it. The old copy is kept as
# <dir>.prev. The profile (~/.config/mozilla/opz) is never touched.
# A running Opz must not have its files replaced under it, so the script stops
# (or waits with --wait) while one is running from the install dir.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
# macOS has its own installer (an .app bundle in ~/Applications).
[ "$OPZ_OS" = mac ] && exec "$OPZ_ROOT/scripts/install-local-mac.sh" "$@"

dest="${OPZ_INSTALL_DIR:-$HOME/Apps/opz}"
do_package=1 wait=0 rollback=0
for a in "$@"; do
    case "$a" in
        --no-package) do_package=0 ;;
        --wait)       wait=1 ;;
        --rollback)   rollback=1 ;;
        -h|--help)    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install-local: unknown argument $a (see --help)" >&2; exit 1 ;;
    esac
done

case "$(basename "$dest")" in opz) ;; *)
    echo "install-local: install dir must end in /opz (got $dest)" >&2; exit 1 ;;
esac
parent="$(dirname "$dest")"
mkdir -p "$parent"
parent="$(cd "$parent" && pwd -P)"
dest="$parent/opz"
prev="$dest.prev"

# PIDs of processes running $dest/opz-bin (main process and content processes).
running_pids() {
    local p exe
    for p in /proc/[0-9]*; do
        exe="$(readlink "$p/exe" 2>/dev/null)" || continue
        case "$exe" in "$dest/opz-bin"|"$dest/opz-bin (deleted)") echo "${p#/proc/}" ;; esac
    done
}

was_running=0
wait_closed() {
    [ -n "$(running_pids)" ] || return 0
    was_running=1
    if [ "$wait" -eq 0 ]; then
        echo "install-local: Opz is running from $dest. Close it first, or rerun with --wait." >&2
        exit 1
    fi
    echo "install-local: Opz is running; close it (your tabs are restored on the next start). Waiting..."
    while [ -n "$(running_pids)" ]; do sleep 1; done
}

start_again() {
    [ "$was_running" -eq 1 ] || return 0
    echo "install-local: starting Opz again"
    setsid -f "$dest/opz" >/dev/null 2>&1 </dev/null
}

if [ "$rollback" -eq 1 ]; then
    [ -x "$prev/opz" ] || { echo "install-local: no previous install at $prev" >&2; exit 1; }
    wait_closed
    tmp="$parent/.opz-swap.$$"
    mv "$dest" "$tmp" 2>/dev/null || true
    mv "$prev" "$dest"
    [ -d "$tmp" ] && mv "$tmp" "$prev"
    echo "install-local: rolled back to $("$dest/opz" --version 2>/dev/null)"
    start_again
    exit 0
fi

[ "$do_package" -eq 1 ] && "$OPZ_ROOT/scripts/package.sh"

# Newest tarball in dist/.
tarball="$(ls -t "$OPZ_ROOT"/dist/opz-*.linux-x86_64.tar.xz 2>/dev/null | head -1 || true)"
[ -n "$tarball" ] || { echo "install-local: no dist/opz-*.tar.xz; run scripts/package.sh" >&2; exit 1; }
if [ -f "$tarball.sha256" ]; then
    (cd "$(dirname "$tarball")" && sha256sum -c --quiet "$(basename "$tarball").sha256")
fi
echo "install-local: installing $(basename "$tarball") into $dest"

# Unpack next to the target (same filesystem, so the swap is a rename).
new="$parent/.opz-new.$$"
trap 'rm -rf "$new"' EXIT
mkdir "$new"
tar -xJf "$tarball" -C "$new"
[ -x "$new/opz/opz" ] || { echo "install-local: $tarball has no opz/opz" >&2; exit 1; }
ver_line="$("$new/opz/opz" --version 2>/dev/null || true)"
case "$ver_line" in *"Opz "*) ;; *) echo "install-local: version check failed: '$ver_line'" >&2; exit 1 ;; esac

wait_closed
rm -rf "$prev"
[ -d "$dest" ] && mv "$dest" "$prev"
mv "$new/opz" "$dest"
rm -rf "$new"
trap - EXIT

"$dest/install-desktop.sh" >/dev/null
# The build ID does not change between builds of the same Firefox version, so
# a profile's startup cache (compiled chrome JS/CSS) would keep running the old
# code. It is rebuilt on the next start.
rm -rf "$HOME"/.cache/mozilla/opz/*/startupCache
echo "install-local: installed $ver_line"
[ -d "$prev" ] && echo "install-local: previous copy kept at $prev (undo: scripts/install-local.sh --rollback)"
start_again
