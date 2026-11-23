# shellcheck shell=bash
# Opz Browser build environment (bash). Source it:
#     . /mnt/ffbuild/opz/env.sh
# Every script in scripts/ sources this file first.
# Works on Linux (/mnt/ffbuild) and macOS (repo on an external /Volumes drive).
#
# Rule: everything (toolchains, caches, temp files) lives on /mnt/ffbuild.
# If /mnt/ffbuild is not mounted we stop here, so nothing is ever silently
# written to /home or /tmp on the system disk.
# ("return" works when sourced, "exit" when executed directly.)

case "$(uname -s)" in
    Darwin)       OPZ_OS=mac ;;
    MINGW*|MSYS*) OPZ_OS=win ;;   # MozillaBuild (MSYS2) shell or Git Bash
    *)            OPZ_OS=linux ;;
esac

# Repo root = directory holding this file. On Windows use the C:/... form:
# bash, git and the native Windows python that runs mach all understand it.
if [ "$OPZ_OS" = win ]; then
    OPZ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
else
    OPZ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fi

if [ "$OPZ_OS" = mac ]; then
    # macOS: the repo must sit on an external volume (/Volumes/<name>/...);
    # toolchains, caches, temp files and the Firefox source go to
    # /Volumes/<name>/ffbuild (override with FFB_ROOT).
    case "$OPZ_ROOT" in
        /Volumes/*/*) _opz_vol="/Volumes/$(echo "$OPZ_ROOT" | cut -d/ -f3)" ;;
        *)  echo "env.sh: ERROR: on macOS the repo must live on an external volume under /Volumes (found $OPZ_ROOT)" >&2
            return 1 2>/dev/null || exit 1 ;;
    esac
    FFB_ROOT="${FFB_ROOT:-$_opz_vol/ffbuild}"
    if [ "$(df -P "$_opz_vol" 2>/dev/null | awk 'NR==2 {print $NF}')" != "$_opz_vol" ]; then
        echo "env.sh: ERROR: $_opz_vol is not mounted (plug in the external drive)." >&2
        return 1 2>/dev/null || exit 1
    fi
    if mount | grep -F " on $_opz_vol (" | grep -q noexec; then
        echo "env.sh: ERROR: $_opz_vol is mounted noexec." >&2
        return 1 2>/dev/null || exit 1
    fi
    unset _opz_vol
    mkdir -p "$FFB_ROOT"
elif [ "$OPZ_OS" = win ]; then
    # Windows: toolchains, caches, temp files and the Firefox source go to
    # C:/ffbuild (override with FFB_ROOT). Long paths are off by default on
    # Windows and the Firefox tree is deep, so the source needs a short root;
    # <repo>/engine is a junction to it (made by scripts/fetch.sh).
    FFB_ROOT="${FFB_ROOT:-C:/ffbuild}"
    mkdir -p "$FFB_ROOT"
else
    FFB_ROOT=/mnt/ffbuild
    if ! mountpoint -q "$FFB_ROOT"; then
        echo "env.sh: ERROR: $FFB_ROOT is not mounted. Mount it first:" >&2
        echo "    sudo mount -o loop,noatime /mnt/Data/ffbuild.img $FFB_ROOT" >&2
        return 1 2>/dev/null || exit 1
    fi
    if findmnt -no OPTIONS "$FFB_ROOT" | tr ',' '\n' | grep -qx noexec; then
        echo "env.sh: ERROR: $FFB_ROOT is mounted noexec; remount without noexec." >&2
        return 1 2>/dev/null || exit 1
    fi
    case "$OPZ_ROOT" in
        "$FFB_ROOT"/*) ;;
        *)  echo "env.sh: ERROR: repo must live under $FFB_ROOT (found $OPZ_ROOT)" >&2
            return 1 2>/dev/null || exit 1 ;;
    esac
fi

# Firefox source + objdir (gitignored). The Firefox build cannot handle a
# source path containing spaces, so in that case it lives in $FFB_ROOT and
# <repo>/engine is a symlink to it.
case "$OPZ_OS:$OPZ_ROOT" in
    win:*|*" "*) OPZ_ENGINE="$FFB_ROOT/opz-engine" ;;
    *)           OPZ_ENGINE="$OPZ_ROOT/engine" ;;
esac

export FFB_ROOT OPZ_ROOT OPZ_OS OPZ_ENGINE

# Build flavour:
#   OPZ_BUILD=artifact  (default) prebuilt C++/Rust from Mozilla CI; fast, for
#                       day-to-day front-end work. No updater.
#   OPZ_BUILD=full      compiles everything (mozconfig.full); slow, but has
#                       Opz's own updater. Releases are made from this one.
# Each flavour has its own objdir, so switching does not throw away a build.
export OPZ_BUILD="${OPZ_BUILD:-artifact}"
case "$OPZ_BUILD" in
    artifact) export MOZCONFIG="$OPZ_ROOT/mozconfig"      OPZ_OBJDIR="$OPZ_ENGINE/obj-artifact" ;;
    full)     export MOZCONFIG="$OPZ_ROOT/mozconfig.full" OPZ_OBJDIR="$OPZ_ENGINE/obj-full" ;;
    *)  echo "env.sh: ERROR: OPZ_BUILD must be artifact or full (got $OPZ_BUILD)" >&2
        return 1 2>/dev/null || exit 1 ;;
esac
# OPZ_OBJDIR must match MOZ_OBJDIR in the mozconfig.

# --- Toolchains (shared between projects on this disk) ----------------------
export MOZBUILD_STATE_PATH="$FFB_ROOT/toolchain/mozbuild"
export RUSTUP_HOME="$FFB_ROOT/toolchain/rustup"
export CARGO_HOME="$FFB_ROOT/toolchain/cargo"

# --- Caches and temp files --------------------------------------------------
export XDG_CACHE_HOME="$FFB_ROOT/cache"
export SCCACHE_DIR="$XDG_CACHE_HOME/sccache"
export PIP_CACHE_DIR="$XDG_CACHE_HOME/pip"
export UV_CACHE_DIR="$XDG_CACHE_HOME/uv"
export npm_config_cache="$XDG_CACHE_HOME/npm"
# uv (used for our own Python on macOS, and by mach) keeps everything here too.
export UV_PYTHON_INSTALL_DIR="$FFB_ROOT/toolchain/python"
export UV_TOOL_DIR="$FFB_ROOT/toolchain/uv-tools"
export TMPDIR="$FFB_ROOT/tmp"
export TMP="$TMPDIR" TEMP="$TMPDIR"

# --- Build ------------------------------------------------------------------
# MOZCONFIG and OPZ_OBJDIR are set above (OPZ_BUILD).
# Turn off mach's own usage telemetry (python/mach/mach/telemetry.py).
export DISABLE_TELEMETRY=1

# --- PATH -------------------------------------------------------------------
# PATH entries need the /c/... form on Windows (the colon in C:/ splits PATH).
_opz_upath() { if [ "$OPZ_OS" = win ]; then cygpath -u "$1"; else printf '%s' "$1"; fi; }
# Drop the rust that lives in $HOME (~/.cargo/bin) so only ours is used.
_opz_path=""
IFS=':' read -r -a _opz_parts <<< "$PATH"
for _p in "${_opz_parts[@]}"; do
    case "$_p" in
        "$HOME/.cargo/bin"|"$HOME/.cargo/bin/"|"") ;;
        "$CARGO_HOME/bin") ;;
        *) _opz_path="${_opz_path:+$_opz_path:}$_p" ;;
    esac
done
export PATH="$(_opz_upath "$CARGO_HOME/bin"):$_opz_path"
unset _p _opz_parts _opz_path
# $FFB_ROOT/toolchain/bin holds our python3 (mach needs 3.10+; macOS ships 3.9).
export PATH="$(_opz_upath "$FFB_ROOT/toolchain/bin"):$PATH"
unset -f _opz_upath

mkdir -p "$MOZBUILD_STATE_PATH" "$RUSTUP_HOME" "$CARGO_HOME/bin" "$FFB_ROOT/toolchain/bin" \
         "$SCCACHE_DIR" "$PIP_CACHE_DIR" "$UV_CACHE_DIR" \
         "$npm_config_cache" "$TMPDIR"

# Show free space on the system disk and the build disk.
opz_df() { df -h "$HOME" "$FFB_ROOT"; }

# Guard for big downloads/builds: nothing should land on the system disk.
#   opz_guard_start   remember free space on the system disk ($HOME's volume)
#   opz_guard_check   fail if it lost more than OPZ_ROOT_MAX_LOSS_MB (default 500)
if [ "$OPZ_OS" = mac ]; then
    opz_root_free() { echo $(( $(df -Pk "$HOME" | awk 'NR==2 {print $4}') * 1024 )); }
elif [ "$OPZ_OS" = win ]; then
    opz_root_free() { df -B1 --output=avail "$(cygpath -u "${SYSTEMDRIVE:-C:}/")" | tail -1 | tr -d ' '; }
else
    opz_root_free() { df -B1 --output=avail / | tail -1 | tr -d ' '; }
fi
# Portable in-place sed (GNU and BSD): opz_sed_i <sed-script> <file>
opz_sed_i() { local f="$2"; sed "$1" "$f" > "$f.opz-tmp" && mv "$f.opz-tmp" "$f"; }
# Windows only: directory junction <link> -> <target>, and its removal (the
# target is left alone). Unlike symlinks, junctions need no admin rights, and
# bash treats them as symlinks ([ -L ] is true). MSYS2_ARG_CONV_EXCL stops
# msys from turning cmd's "/c" and "/J" switches into paths.
opz_junction()   { MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$(cygpath -w "$1")" "$(cygpath -w "$2")" > /dev/null; }
opz_unjunction() { MSYS2_ARG_CONV_EXCL='*' cmd /c rmdir "$(cygpath -w "$1")"; }
opz_guard_start() {
    export OPZ_ROOT_FREE0
    OPZ_ROOT_FREE0="$(opz_root_free)"
    opz_df
}
opz_guard_check() {
    local now lost limit="${OPZ_ROOT_MAX_LOSS_MB:-500}"
    now="$(opz_root_free)"
    lost=$(( (${OPZ_ROOT_FREE0:-$now} - now) / 1048576 ))
    opz_df
    # Windows: FFB_ROOT usually sits on the system drive itself, and then
    # there is nothing to guard.
    if [ "$OPZ_OS" = win ] &&
       [ "$(cygpath -m "$FFB_ROOT" | cut -c1 | tr a-z A-Z)" = "$(printf '%s' "${SYSTEMDRIVE:-C:}" | cut -c1 | tr a-z A-Z)" ]; then
        echo "guard: skipped ($FFB_ROOT is on the system drive; ${lost}MB used)"
        return 0
    fi
    if [ "$lost" -gt "$limit" ]; then
        echo "GUARD: / lost ${lost}MB (> ${limit}MB). Something wrote to the system disk; stop and investigate:" >&2
        echo "  du -xsh ~/.mozbuild ~/.cargo ~/.rustup ~/.cache ~/.npm ~/.local /tmp 2>/dev/null" >&2
        return 1
    fi
    echo "guard: / changed by ${lost}MB (limit ${limit}MB)"
}
