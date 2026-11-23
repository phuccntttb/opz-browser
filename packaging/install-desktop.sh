#!/bin/sh
# Add (or remove) the Opz Browser menu entry for the current user.
#   ./install-desktop.sh            write ~/.local/share/applications/opz.desktop
#   ./install-desktop.sh --remove   delete it again
# Only that one file is touched; nothing needs root.
set -eu
here="$(dirname "$(readlink -f "$0")")"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
target="$apps/opz.desktop"

if [ "${1:-}" = "--remove" ]; then
    rm -f "$target"
    echo "removed $target"
    exit 0
fi

mkdir -p "$apps"
sed "s|@OPZ_DIR@|$here|g" "$here/opz.desktop.in" > "$target"
echo "wrote $target (Opz at $here)"
echo "Move the opz/ folder later? Run this script again from the new place."
