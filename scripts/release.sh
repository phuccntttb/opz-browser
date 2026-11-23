#!/usr/bin/env bash
# Make an Opz release from the full build (OPZ_BUILD=full) that installed
# copies update to by themselves.
#
#   scripts/release.sh             package, make + sign the update (MAR),
#                                  write update.xml   -> dist/release/
#   scripts/release.sh --publish   the same, then copy dist/release/site/ to
#                                  $OPZ_UPDATE_PUBLISH (scripts/publish.sh)
#
# Before: OPZ_BUILD=full scripts/build.sh, and updates/update.env filled in.
# Keys: scripts/mar-keys.sh (once).
#
# dist/release/
#   opz-<ver>-<buildid>.mac.dmg | .linux-x86_64.tar.xz | .win64.zip
#                                       installer for new machines
#   site/                               the update server's files
#     <BUILD_TARGET>/update.xml         what installed copies ask for
#     files/opz-<ver>-<buildid>.<BUILD_TARGET>.complete.mar
#     files/<installer>
#     latest/opz-mac.dmg | opz-linux-x86_64.tar.xz | opz-win64.zip  -> files/<installer>
# Each release replaces <BUILD_TARGET>/update.xml; old MARs stay (an update
# that is downloading keeps working).
# Windows (MozillaBuild, or cross-built on Linux with OPZ_TARGET=win): a zip,
# unsigned; Windows asks for %BUILD_TARGET% plus the CPU it runs on
# (WINNT_x86_64-msvc-x64, and -aarch64 for ARM machines running the x64
# build), so update.xml is written to both. A cross build cannot run the
# build's own Windows NSS tools, so its MAR is signed with openssl and
# Mozilla's Python "mar" package instead of signmar.
set -euo pipefail
export OPZ_BUILD=full
. "$(dirname "$0")/../env.sh"
. "$OPZ_ROOT/updates/update.env"

publish=0
for a in "$@"; do
    case "$a" in
        --publish) publish=1 ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "release: unknown argument $a (see --help)" >&2; exit 1 ;;
    esac
done

die() { echo "release: $*" >&2; exit 1; }
[ -n "$OPZ_UPDATE_BASE_URL" ] || die "OPZ_UPDATE_BASE_URL is empty; fill in updates/update.env"
case "$OPZ_UPDATE_BASE_URL" in http://*|https://*) ;; *) die "OPZ_UPDATE_BASE_URL must start with http:// or https://" ;; esac
base_url="${OPZ_UPDATE_BASE_URL%/}"
[ "$publish" -eq 0 ] || [ -n "$OPZ_UPDATE_PUBLISH" ] || die "--publish needs OPZ_UPDATE_PUBLISH (updates/update.env)"

keydir="$FFB_ROOT/keys/mar"
[ -f "$keydir/primary.key.pem" ] && [ -f "$keydir/primary.cert.pem" ] \
    || die "no signing key in $keydir; run scripts/mar-keys.sh"
# The key must be the one the updater was built with.
cmp -s <(openssl x509 -in "$keydir/primary.cert.pem" -outform DER) "$OPZ_ROOT/updates/certs/primary.der" \
    || die "$keydir/primary.cert.pem does not match updates/certs/primary.der"

objdir="$OPZ_OBJDIR"
bin="$objdir/dist/bin"
ini="$bin/application.ini"
[ -f "$ini" ] || die "$ini missing; run: OPZ_BUILD=full scripts/build.sh"
cross=0
[ "$OPZ_TARGET" = "$OPZ_OS" ] || cross=1
if [ "$cross" -eq 0 ]; then
    for t in signmar certutil pk12util; do [ -x "$bin/$t" ] || die "$bin/$t missing (full build?)"; done
fi
mar_tool="$objdir/dist/host/bin/mar"
[ -x "$mar_tool" ] || die "$mar_tool missing"
command -v xz >/dev/null || die "xz not found (macOS: brew install xz; Linux: apt install xz-utils)"

# NSS tools from the build itself (they load NSS from dist/bin).
nss() { local t="$1"; shift; DYLD_LIBRARY_PATH="$bin" LD_LIBRARY_PATH="$bin" "$bin/$t" "$@"; }

conf() { sed -n "s/^$1 = //p" "$objdir/config/autoconf.mk" | head -1; }
build_target="$(conf OS_TARGET)_$(conf TARGET_XPCOM_ABI)"      # = %BUILD_TARGET%
# Directories installed copies ask for update.xml in (see the top).
if [ "$OPZ_TARGET" = win ]; then update_dirs=("$build_target-x64" "$build_target-aarch64")
else update_dirs=("$build_target"); fi
mar_channel="$(conf MAR_CHANNEL_ID)"
[ -n "$mar_channel" ] || die "MAR_CHANNEL_ID not set in the build (mozconfig.full)"
[ -f "$objdir/.opz-build-date" ] || die "$objdir/.opz-build-date missing; run: OPZ_BUILD=full scripts/build.sh"
# Package with the build ID the binaries were built with (see build.sh).
MOZ_BUILD_DATE="$(cat "$objdir/.opz-build-date")"
export MOZ_BUILD_DATE
version="$(sed -n 's/^Version=//p' "$ini")"
buildid="$MOZ_BUILD_DATE"
grep -qx "BuildID=$buildid" "$ini" || die "$ini has a different build ID than $buildid; run: OPZ_BUILD=full scripts/build.sh"
name="opz-$version-$buildid"
echo "release: $name for $build_target (channel $mar_channel)"
echo "release: update URL $base_url/%BUILD_TARGET%/update.xml"

out="$OPZ_ROOT/dist/release"
site="$out/site"
stage="$TMPDIR/opz-release"
case "$stage" in "$FFB_ROOT"/tmp/*) ;; *) die "bad stage dir $stage" ;; esac
rm -rf "$stage"
mkdir -p "$stage" "$site/files"
trap 'rm -rf "$stage"' EXIT

opz_guard_start
start=$(date +%s)

# Release policies: the everyday ones (prefs/policies.json) with updates on
# and pointed at our server instead of Mozilla's.
policies="$stage/policies.json"
python3 - "$OPZ_ROOT/prefs/policies.json" "$policies" "$base_url/%BUILD_TARGET%/update.xml" <<'EOF'
import json, sys
src, dst, url = sys.argv[1:]
with open(src) as f:
    data = json.load(f)
p = data["policies"]
p.pop("DisableAppUpdate", None)
p["AppUpdateURL"] = url
with open(dst, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF

if [ "$OPZ_TARGET" = mac ]; then
    sign_id=
    if [ -n "${OPZ_MAC_SIGN_IDENTITY:-}" ]; then
        sign_id="$(opz_mac_sign_identity)" || die "no signing identity"
    fi
    notary="${OPZ_MAC_NOTARY_PROFILE:-}"
    if [ -n "$sign_id" ]; then
        security find-identity -v -p codesigning | grep -qF "$sign_id" \
            || die "signing identity '$sign_id' not in the keychain (security find-identity -v -p codesigning)"
    fi
    [ -z "$notary" ] || [ -n "$sign_id" ] || die "OPZ_MAC_NOTARY_PROFILE needs OPZ_MAC_SIGN_IDENTITY"
    # notarytool reads the profile from the login keychain, or from
    # OPZ_MAC_NOTARY_KEYCHAIN (the temporary keychain of a CI run).
    notary_auth=(--keychain-profile "$notary")
    [ -z "${OPZ_MAC_NOTARY_KEYCHAIN:-}" ] || notary_auth+=(--keychain "$OPZ_MAC_NOTARY_KEYCHAIN")
    # Submit to Apple's notary service and wait; fails unless Accepted.
    notarize() {
        local f="$1" log="$stage/notary.log"
        echo "release: notarizing $(basename "$f") (usually a few minutes)"
        xcrun notarytool submit "$f" "${notary_auth[@]}" --wait > "$log" 2>&1 || true
        if ! grep -q "status: Accepted" "$log"; then
            cat "$log" >&2
            local id; id="$(sed -n 's/^ *id: //p' "$log" | head -1)"
            [ -z "$id" ] || xcrun notarytool log "$id" "${notary_auth[@]}" >&2 || true
            die "notarization of $(basename "$f") failed"
        fi
    }
    (cd "$OPZ_ENGINE" && ./mach package)
    shopt -s nullglob
    apps=("$objdir"/dist/firefox/*.app)
    [ "${#apps[@]}" -eq 1 ] || die "expected one .app in $objdir/dist/firefox, found ${#apps[@]}"
    app="$stage/Opz.app"
    ditto "${apps[0]}" "$app"
    res="$app/Contents/Resources"
    mkdir -p "$res/distribution" "$res/browser/defaults/preferences"
    install -m 644 "$policies" "$res/distribution/policies.json"
    install -m 644 "$OPZ_ROOT/prefs/opz.js" "$res/browser/defaults/preferences/00-opz.js"
    # Same identity as the Opz.app installed so far (scripts/install-local-mac.sh).
    plist="$app/Contents/Info.plist"
    plutil -replace CFBundleIdentifier -string org.opz.browser "$plist"
    plutil -replace CFBundleName -string Opz "$plist"
    plutil -replace CFBundleDisplayName -string Opz "$plist"
    # precomplete = what an update removes before adding the new files.
    (cd "$res" && python3 "$OPZ_ENGINE/config/createprecomplete.py")
    if [ -n "$sign_id" ]; then
        # Developer ID + hardened runtime, with Firefox's own per-binary
        # entitlements. "without-restricted": no provisioning profile, so the
        # entitlements Apple grants only to Mozilla (passkeys through macOS,
        # its application identifier) are left out.
        (cd "$OPZ_ENGINE" && ./mach macos-sign -a "$app" -s "$sign_id" \
            -e production-without-restricted -c release) > "$stage/macos-sign.log" 2>&1 \
            || { tail -20 "$stage/macos-sign.log" >&2; die "mach macos-sign failed"; }
        codesign --verify --deep --strict "$app" || die "signature check of Opz.app failed"
        if [ -n "$notary" ]; then
            # Notarize and staple the app itself, so it also opens offline and
            # the ticket ships inside every update (the MAR is made from $app).
            ditto -c -k --keepParent "$app" "$stage/Opz.zip"
            notarize "$stage/Opz.zip"
            rm -f "$stage/Opz.zip"
            xcrun stapler staple -q "$app" || die "stapling Opz.app failed"
        fi
    else
        echo "release: WARNING: ad-hoc signature (OPZ_MAC_SIGN_IDENTITY empty); macOS will block the app when downloaded with a browser" >&2
        xattr -cr "$app"
        codesign --force --deep --sign - "$app" >/dev/null 2>&1 \
            || { codesign --force --deep --sign - "$app"; die "codesign failed"; }
    fi
    ver_line="$("$app/Contents/MacOS/firefox" --version 2>/dev/null || true)"
    installer="$name.mac.dmg"
    dmgdir="$stage/dmg"
    mkdir -p "$dmgdir"
    ditto "$app" "$dmgdir/Opz.app"
    ln -s /Applications "$dmgdir/Applications"
    hdiutil create -quiet -volname Opz -srcfolder "$dmgdir" -ov -format UDZO "$out/$installer"
    rm -rf "$dmgdir"
    if [ -n "$sign_id" ]; then
        codesign --sign "$sign_id" --timestamp "$out/$installer" || die "signing the .dmg failed"
        if [ -n "$notary" ]; then
            notarize "$out/$installer"
            xcrun stapler staple -q "$out/$installer" || die "stapling the .dmg failed"
        fi
        spctl -a -t open --context context:primary-signature "$out/$installer" 2>/dev/null \
            && echo "release: Gatekeeper accepts $installer" \
            || echo "release: WARNING: Gatekeeper does not accept $installer (not notarized?)" >&2
    fi
elif [ "$OPZ_TARGET" = win ]; then
    # mach package: dist/opz-<ver>.en-US.win64.zip holding firefox/; repack it
    # as Opz/ with Opz's policies and prefs. (zip/unzip are not always in
    # MozillaBuild, Python is.)
    rm -f "$objdir"/dist/*.win64.zip
    (cd "$OPZ_ENGINE" && ./mach package)
    shopt -s nullglob
    zips=("$objdir"/dist/*.win64.zip)
    [ "${#zips[@]}" -eq 1 ] || die "expected one .win64.zip in $objdir/dist, found ${#zips[@]}"
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${zips[0]}" "$stage/unzip"
    [ -f "$stage/unzip/firefox/firefox.exe" ] || die "firefox/firefox.exe not found in ${zips[0]}"
    mv "$stage/unzip/firefox" "$stage/Opz"
    app="$stage/Opz"
    mkdir -p "$app/distribution" "$app/browser/defaults/preferences"
    cp "$policies" "$app/distribution/policies.json"
    cp "$OPZ_ROOT/prefs/opz.js" "$app/browser/defaults/preferences/00-opz.js"
    (cd "$app" && python3 "$OPZ_ENGINE/config/createprecomplete.py")
    if [ "$cross" -eq 0 ]; then
        # A GUI program: --version only prints into a pipe.
        ver_line="$("$app/firefox.exe" --version 2>/dev/null | cat || true)"
    else
        # Cannot run it here: what --version prints, from application.ini.
        ver_line="$(sed -n 's/^Vendor=//p' "$app/application.ini") $(sed -n 's/^Name=//p' "$app/application.ini") $(sed -n 's/^Version=//p' "$app/application.ini")"
    fi
    installer="$name.win64.zip"
    rm -f "$out/$installer"
    python3 - "$stage" Opz "$out/$installer" <<'EOF'
import os, sys, zipfile
base, top, dest = sys.argv[1:]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, dirs, files in os.walk(os.path.join(base, top)):
        dirs.sort()
        for f in sorted(files):
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, base).replace(os.sep, "/"))
EOF
else
    [ "$OPZ_OS" = linux ] || die "only macOS, Linux and Windows are supported (this is $OPZ_OS)"
    OPZ_POLICIES="$policies" "$OPZ_ROOT/scripts/package.sh"
    shopt -s nullglob
    tars=("$OPZ_ROOT"/dist/opz-"$version".linux-*.tar.xz)
    [ "${#tars[@]}" -eq 1 ] || die "expected one dist/opz-$version.linux-*.tar.xz, found ${#tars[@]}"
    tar -xJf "${tars[0]}" -C "$stage"
    app="$stage/opz"
    ver_line="$("$app/opz" --version 2>/dev/null || true)"
    arch="$(basename "${tars[0]}" .tar.xz)"; arch="${arch##*.}"
    installer="$name.$arch.tar.xz"
    cp "${tars[0]}" "$out/$installer"
fi
case "$ver_line" in *"Opz $version"*) ;; *) die "version check failed: '$ver_line'" ;; esac
# The updater compares update.xml with the build ID compiled into libxul;
# every build ID in the package must be that one.
case "$OPZ_TARGET" in
    mac) libxul="$app/Contents/MacOS/XUL"; appbin="$app/Contents/MacOS/firefox"
         inis=("$app/Contents/Resources/application.ini" "$app/Contents/Resources/platform.ini") ;;
    win) libxul="$app/xul.dll"; appbin="$app/firefox.exe"
         inis=("$app/application.ini" "$app/platform.ini") ;;
    *)   libxul="$app/libxul.so"; appbin="$app/opz-bin"
         inis=("$app/browser/application.ini" "$app/platform.ini") ;;
esac
# has_buildid <file>: the build ID is in the binary as a string of its own.
has_buildid() {
    python3 -c 'import re, sys; d = open(sys.argv[1], "rb").read(); sys.exit(0 if re.search(rb"(?<![0-9])" + sys.argv[2].encode() + rb"(?![0-9])", d) else 1)' "$1" "$buildid"
}
has_buildid "$libxul" \
    || die "$(basename "$libxul") was not built with build ID $buildid; run: OPZ_BUILD=full scripts/build.sh"
has_buildid "$appbin" \
    || die "$(basename "$appbin") was not built with build ID $buildid; run: OPZ_BUILD=full scripts/build.sh"
for f in "${inis[@]}"; do
    grep -qx "BuildID=$buildid" "$f" || die "$f: build ID is not $buildid"
done
[ -f "$app/precomplete" ] || [ -f "$app/Contents/Resources/precomplete" ] || die "precomplete missing"

# Complete update package (MAR), then sign it.
mar="$name.$build_target.complete.mar"
MAR="$mar_tool" MOZ_PRODUCT_VERSION="$version" MAR_CHANNEL_ID="$mar_channel" \
    bash "$OPZ_ENGINE/tools/update-packaging/make_full_update.sh" "$stage/unsigned.mar" "$app" \
    > "$stage/make_full_update.log" 2>&1 \
    || { tail -20 "$stage/make_full_update.log" >&2; die "make_full_update.sh failed"; }

if [ "$cross" -eq 0 ]; then
    db="$stage/nssdb"
    mkdir -p "$db"
    nss certutil -N -d "$db" --empty-password
    openssl pkcs12 -export -inkey "$keydir/primary.key.pem" -in "$keydir/primary.cert.pem" \
        -name opz-primary -passout pass: -out "$stage/primary.p12"
    nss pk12util -i "$stage/primary.p12" -d "$db" -W "" -K "" >/dev/null
    rm -f "$stage/primary.p12"
    nss signmar -d "$db" -n opz-primary -s "$stage/unsigned.mar" "$site/files/$mar"
    # Check it the way the updater will: against the certificate compiled in.
    # signmar takes a DER file (-D) only on macOS and Windows; on Linux it
    # checks against the NSS db, whose certificate was compared with
    # updates/certs/primary.der above.
    if [ "$OPZ_OS" = linux ]; then
        nss signmar -d "$db" -n opz-primary -v "$site/files/$mar"
    else
        nss signmar -D "$OPZ_ROOT/updates/certs/primary.der" -v "$site/files/$mar"
    fi || die "signature check of $mar failed"
    rm -rf "$db"
else
    # The same RSA-SHA384 signature signmar makes: hash the MAR with a signature
    # block in place, sign the hash with openssl, put the signature in.
    marpy="$FFB_ROOT/toolchain/mar-venv"
    [ -x "$marpy/bin/mar" ] || { python3 -m venv "$marpy" && "$marpy/bin/pip" -q install "mar==3.2.1"; } \
        || die "could not install Mozilla's mar package"
    "$marpy/bin/mar" --hash sha384 "$stage/unsigned.mar" | openssl base64 -d -A > "$stage/mar.hash"
    openssl pkeyutl -sign -inkey "$keydir/primary.key.pem" -pkeyopt digest:sha384 \
        -in "$stage/mar.hash" -out "$stage/mar.sig"
    "$marpy/bin/mar" --add-signature "$stage/unsigned.mar" "$site/files/$mar" "$stage/mar.sig"
    openssl x509 -inform der -in "$OPZ_ROOT/updates/certs/primary.der" -pubkey -noout > "$stage/mar.pub.pem"
    "$marpy/bin/mar" -k "$stage/mar.pub.pem" -v "$site/files/$mar" \
        || die "signature check of $mar failed"
fi
cp "$out/$installer" "$site/files/$installer"
# Stable download link for the website (latest/opz-mac.dmg,
# latest/opz-linux-x86_64.tar.xz, latest/opz-win64.zip): a symlink to this
# release's installer. (On Windows, ln makes a copy; scripts/publish.sh turns
# it back into a link.)
mkdir -p "$site/latest"
case "$OPZ_TARGET" in
    mac) latest=opz-mac.dmg ;;
    win) latest=opz-win64.zip ;;
    *)   latest="opz-$arch.tar.xz" ;;
esac
ln -sfn "../files/$installer" "$site/latest/$latest"

size="$(wc -c < "$site/files/$mar" | tr -d ' ')"
sha512="$(openssl dgst -sha512 -r "$site/files/$mar" | cut -d' ' -f1)"
for d in "${update_dirs[@]}"; do
    mkdir -p "$site/$d"
    cat > "$site/$d/update.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<updates>
  <update type="minor" displayVersion="$version" appVersion="$version" platformVersion="$version" buildID="$buildid">
    <patch type="complete" URL="$base_url/files/$mar" size="$size" hashFunction="sha512" hashValue="$sha512"/>
  </update>
</updates>
EOF
done

echo "release: $ver_line, build $buildid"
echo "release: finished in $(( $(date +%s) - start ))s"
ls -lh "$out" "$site/files"
for d in "${update_dirs[@]}"; do ls -lh "$site/$d"; done

if [ "$publish" -eq 1 ]; then
    "$OPZ_ROOT/scripts/publish.sh" "$site"
fi
opz_guard_check
