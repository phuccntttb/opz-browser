#!/usr/bin/env bash
# Download mach's toolchains (node, fix-stacks, ...) into $MOZBUILD_STATE_PATH.
#   scripts/bootstrap.sh                 for "Firefox for Desktop Artifact Mode"
#   OPZ_BUILD=full scripts/bootstrap.sh  also the compilers (clang, cbindgen,
#                                        macOS SDK, ...) and Rust
# --no-system-changes: mach must not run apt/sudo/brew (it would otherwise try
# to `sudo apt-get install watchman`). System packages are listed in README.md.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
[ -d "$OPZ_ENGINE" ] || { echo "bootstrap: run scripts/fetch.sh first" >&2; exit 1; }

opz_guard_start
cd "$OPZ_ENGINE"
case "$OPZ_BUILD" in
    full) choice=browser ;;
    *)    choice=browser_artifact_mode ;;
esac
./mach --no-interactive bootstrap \
    --application-choice "$choice" \
    --no-system-changes "$@"

# With --no-system-changes mach stops before installing Rust. Do that step
# here with mach's own pinned rustup-init (URL + sha256 from mozboot), into
# $CARGO_HOME/$RUSTUP_HOME on the build disk, and without --modify-path
# (rustup would otherwise edit ~/.profile / ~/.zshrc; env.sh sets PATH).
if [ "$OPZ_BUILD" = full ] && [ ! -x "$CARGO_HOME/bin/rustc" ]; then
    ./mach python - <<'EOF'
import os, stat, subprocess, tempfile
from pathlib import Path
from mozboot import rust
from mozboot.util import http_download_and_save

platform = rust.platform()
url, checksum = rust.rustup_url(platform), rust.rustup_hash(platform)
fd, init = tempfile.mkstemp(prefix="rustup-init-")
os.close(fd)
init = Path(init)
try:
    print(f"bootstrap: downloading {url}")
    http_download_and_save(url, init, checksum)
    init.chmod(init.stat().st_mode | stat.S_IRWXU)
    subprocess.check_call([str(init), "-y", "--no-modify-path",
                           "--profile", "minimal",
                           "--default-toolchain", "stable",
                           "--default-host", platform,
                           "--component", "rustfmt"])
finally:
    init.unlink(missing_ok=True)
EOF
fi
[ "$OPZ_BUILD" != full ] || "$CARGO_HOME/bin/rustc" --version
opz_guard_check
