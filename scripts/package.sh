#!/usr/bin/env bash
# Build the Opz Browser Linux tarball: dist/opz-<version>.linux-x86_64.tar.xz
#
# "./mach package" makes a Firefox-shaped tarball (firefox/ folder, binary
# "firefox", Firefox app data compiled in, see mozconfig). We repack it:
#   firefox/              -> opz/
#   firefox (no-PIE stub) -> removed; firefox-bin -> opz-bin (real binary;
#                            child processes re-exec the same file)
#   + opz                    launcher (packaging/opz, sets XUL_APP_FILE)
#   + browser/application.ini   Opz app data (Name=Opz, UAName=Firefox, ...)
#   + browser/defaults/preferences/00-opz.js   (prefs/opz.js)
#   + distribution/policies.json               (prefs/policies.json)
#   + opz.desktop.in, install-desktop.sh       (menu entry, run by the user)
set -euo pipefail
. "$(dirname "$0")/../env.sh"
[ "$OPZ_OS" = linux ] || { echo "package: only Linux is supported (this is $OPZ_OS)" >&2; exit 1; }
cd "$OPZ_ENGINE"
objdir="$OPZ_OBJDIR"
ini="$objdir/dist/bin/browser/application.ini"
[ -f "$ini" ] || { echo "package: $ini missing; run scripts/build.sh" >&2; exit 1; }
grep -qx "UAName=Firefox" "$ini" || { echo "package: $ini lacks UAName; run scripts/build.sh" >&2; exit 1; }

stage="$TMPDIR/opz-package"
case "$stage" in "$FFB_ROOT"/tmp/*) ;; *) echo "package: bad stage dir $stage" >&2; exit 1 ;; esac

opz_guard_start
start=$(date +%s)
rm -f "$objdir"/dist/*.tar.xz
./mach package
shopt -s nullglob
src=("$objdir"/dist/*.tar.xz)
[ "${#src[@]}" -eq 1 ] || { echo "package: expected one tarball in $objdir/dist, found ${#src[@]}" >&2; exit 1; }

rm -rf "$stage"
mkdir -p "$stage"
tar -xJf "${src[0]}" -C "$stage"
[ -x "$stage/firefox/firefox-bin" ] || { echo "package: firefox/firefox-bin not found in ${src[0]}" >&2; exit 1; }
mv "$stage/firefox" "$stage/opz"
app="$stage/opz"
rm -f "$app/firefox"
mv "$app/firefox-bin" "$app/opz-bin"
install -m 755 "$OPZ_ROOT/packaging/opz" "$app/opz"
install -m 755 "$OPZ_ROOT/packaging/install-desktop.sh" "$app/install-desktop.sh"
install -m 644 "$OPZ_ROOT/packaging/opz.desktop.in" "$app/opz.desktop.in"
install -m 644 "$ini" "$app/browser/application.ini"
install -D -m 644 "$OPZ_ROOT/prefs/opz.js" "$app/browser/defaults/preferences/00-opz.js"
# OPZ_POLICIES: release.sh passes the release policies (updates on).
install -D -m 644 "${OPZ_POLICIES:-$OPZ_ROOT/prefs/policies.json}" "$app/distribution/policies.json"
# The top-level application.ini says "This file is not used"; drop it so the
# only app data in the package is Opz's.
rm -f "$app/application.ini"
# precomplete (files an update removes) must list the renamed/added files.
(cd "$app" && python3 "$OPZ_ENGINE/config/createprecomplete.py")

# Smoke test: the launcher must report Opz, not Firefox.
ver_line="$("$app/opz" --version 2>/dev/null || true)"
case "$ver_line" in *"Opz "*) ;; *) echo "package: launcher check failed: '$ver_line'" >&2; exit 1 ;; esac
version="$(sed -n 's/^Version=//p' "$app/browser/application.ini")"

mkdir -p "$OPZ_ROOT/dist"
out="$OPZ_ROOT/dist/opz-$version.linux-x86_64.tar.xz"
tar -C "$stage" -cf - opz | xz -T0 -6 > "$out.part"
mv "$out.part" "$out"
rm -rf "$stage"
(cd "$OPZ_ROOT/dist" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256")

echo "package: $ver_line"
echo "package: finished in $(( $(date +%s) - start ))s"
ls -lh "$OPZ_ROOT/dist/"
opz_guard_check
