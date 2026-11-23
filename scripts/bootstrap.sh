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
# Cross build for Windows (OPZ_TARGET=win on Linux, see mozconfig.full): the
# Rust standard library for Windows, and the MSVC headers/libraries and the
# Windows SDK, downloaded from Microsoft by Firefox's own get_vs.py (needs
# msiextract: apt install msitools).
if [ "$OPZ_TARGET" = win ] && [ "$OPZ_OS" != win ]; then
    "$CARGO_HOME/bin/rustup" target add x86_64-pc-windows-msvc
    vs="$FFB_ROOT/toolchain/vs"
    if [ ! -d "$vs/VC" ]; then
        command -v msiextract >/dev/null || { echo "bootstrap: msiextract not found (apt install msitools)" >&2; exit 1; }
        rm -rf "$vs.tmp"
        ./mach python --virtualenv build taskcluster/scripts/misc/get_vs.py build/vs/vs2026.yaml "$vs.tmp"
        mv "$vs.tmp" "$vs"
    fi
    echo "bootstrap: Windows SDK and MSVC in $vs"
fi
[ "$OPZ_BUILD" != full ] || "$CARGO_HOME/bin/rustc" --version
opz_guard_check
