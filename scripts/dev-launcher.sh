#!/usr/bin/env bash
# Starts the dev build as Opz, like the installed <opz dir>/opz launcher.
# scripts/run.sh sets MOZ_APP_LAUNCHER to this file, so web app desktop
# entries and restarts made by the dev build come back through here.
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../env.sh"
export XUL_APP_FILE="$OPZ_OBJDIR/dist/bin/browser/application.ini"
export MOZ_APP_LAUNCHER="$OPZ_ROOT/scripts/dev-launcher.sh"
exec "$OPZ_OBJDIR/dist/bin/firefox" "$@"
