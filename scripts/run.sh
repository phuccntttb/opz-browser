#!/usr/bin/env bash
# Run the built browser with a throw-away profile inside the objdir.
# Extra arguments go to the browser, e.g.:  scripts/run.sh --headless --screenshot
set -euo pipefail
. "$(dirname "$0")/../env.sh"
cd "$OPZ_ENGINE"
# Use Opz's application.ini instead of the compiled-in Firefox app data.
export XUL_APP_FILE="$OPZ_OBJDIR/dist/bin/browser/application.ini"
[ -f "$XUL_APP_FILE" ] || { echo "run: $XUL_APP_FILE missing; run scripts/build.sh" >&2; exit 1; }
if [ "$OPZ_OS" = win ]; then
    XUL_APP_FILE="$(cygpath -w "$XUL_APP_FILE")"   # firefox.exe wants C:\...
fi
# Web app desktop entries (patch 0059) run MOZ_APP_LAUNCHER; without it they
# would start the bare binary, which is not Opz.
if [ "$OPZ_OS" = linux ]; then
    export MOZ_APP_LAUNCHER="$OPZ_ROOT/scripts/dev-launcher.sh"
fi
# -purgecaches: "build.sh faster" keeps the same build ID, so without it the
# profile's startup cache can keep running the old browser code.
exec ./mach run -purgecaches "$@"
