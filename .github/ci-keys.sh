#!/usr/bin/env bash
# Put the release keys from GitHub secrets in place on a CI runner
# (.github/workflows/release.yml). Not for local use.
#   ci-keys.sh mar      MAR_PRIMARY_KEY -> $FFB_ROOT/keys/mar/
#   ci-keys.sh deploy   DEPLOY_SSH_KEY  -> ~/.ssh, RSYNC_RSH for release.sh --publish
#   ci-keys.sh apple    Developer ID .p12 + notarytool profile in a temporary keychain
set -euo pipefail
[ -n "${GITHUB_ENV:-}" ] || { echo "ci-keys: only for GitHub Actions" >&2; exit 1; }
here="$(dirname "$0")"
# The build environment (not needed by "deploy", which also runs in the job
# that only publishes the Windows build).
buildenv() { . "$here/../env.sh"; }
die() { echo "::error::ci-keys: $*" >&2; exit 1; }
need() { for v in "$@"; do [ -n "${!v:-}" ] || die "secret $v is not set (scripts/ci-secrets.sh)"; done; }
pubhash() { openssl pkey -pubout -outform der "$@" | openssl dgst -sha256 -r | cut -d' ' -f1; }

case "${1:-}" in
mar)
    buildenv
    need MAR_PRIMARY_KEY
    d="$FFB_ROOT/keys/mar"
    (umask 077; mkdir -p "$d"; printf '%s\n' "$MAR_PRIMARY_KEY" > "$d/primary.key.pem")
    # The certificate is public: take the one compiled into the updater.
    openssl x509 -inform der -in "$OPZ_ROOT/updates/certs/primary.der" -out "$d/primary.cert.pem"
    [ "$(pubhash -in "$d/primary.key.pem")" = "$(openssl x509 -in "$d/primary.cert.pem" -pubkey -noout | pubhash -pubin)" ] \
        || die "MAR_PRIMARY_KEY does not belong to updates/certs/primary.der"
    echo "ci-keys: MAR key in place"
    ;;
deploy)
    need DEPLOY_SSH_KEY DEPLOY_KNOWN_HOSTS
    (umask 077; mkdir -p "$HOME/.ssh"
     printf '%s\n' "$DEPLOY_SSH_KEY" > "$HOME/.ssh/opz_deploy"
     printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$HOME/.ssh/opz_known_hosts")
    ssh-keygen -y -f "$HOME/.ssh/opz_deploy" > /dev/null || die "DEPLOY_SSH_KEY is not a valid private key"
    # rsync runs this without a shell, so no ~ and no quotes.
    echo "RSYNC_RSH=ssh -i $HOME/.ssh/opz_deploy -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/opz_known_hosts" >> "$GITHUB_ENV"
    echo "ci-keys: deploy key in place"
    ;;
apple)
    buildenv
    [ "$OPZ_OS" = mac ] || die "apple: macOS only"
    need MAC_DEVELOPER_ID_P12 MAC_DEVELOPER_ID_P12_PASSWORD APPLE_ID APPLE_APP_PASSWORD
    . "$OPZ_ROOT/updates/update.env"
    kc="$RUNNER_TEMP/opz-signing.keychain-db"
    kc_pw="$(openssl rand -hex 24)"
    security create-keychain -p "$kc_pw" "$kc"
    security set-keychain-settings -lut 21600 "$kc"
    security unlock-keychain -p "$kc_pw" "$kc"
    p12="$RUNNER_TEMP/developer-id.p12"
    (umask 077; printf '%s' "$MAC_DEVELOPER_ID_P12" | base64 --decode > "$p12")
    security import "$p12" -k "$kc" -P "$MAC_DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security > /dev/null
    rm -f "$p12"
    # Let codesign use the key without a dialog.
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kc_pw" "$kc" > /dev/null
    # shellcheck disable=SC2046
    security list-keychains -d user -s "$kc" $(security list-keychains -d user | tr -d '"')
    # The identity and its Team ID come from the .p12 ("auto"), so neither is
    # written in the repo; keep them out of the public logs too.
    sign_id="$(opz_mac_sign_identity "$kc")" || die "no Developer ID Application identity in the imported .p12"
    security find-identity -v -p codesigning "$kc" | grep -qF "$sign_id" \
        || die "the identity in the imported .p12 is not valid for code signing"
    team="$(printf '%s' "$sign_id" | sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p')"
    [ -n "$team" ] || die "no Team ID in the identity name"
    echo "::add-mask::$sign_id"
    echo "::add-mask::${sign_id#Developer ID Application: }"
    echo "::add-mask::$team"
    xcrun notarytool store-credentials "$OPZ_MAC_NOTARY_PROFILE" --apple-id "$APPLE_ID" \
        --team-id "$team" --password "$APPLE_APP_PASSWORD" --keychain "$kc" > /dev/null \
        || die "notarytool rejected APPLE_ID / APPLE_APP_PASSWORD"
    echo "OPZ_MAC_NOTARY_KEYCHAIN=$kc" >> "$GITHUB_ENV"
    echo "OPZ_MAC_SIGN_IDENTITY=$sign_id" >> "$GITHUB_ENV"
    echo "ci-keys: signing identity and notary profile in $kc"
    ;;
*)
    echo "usage: ci-keys.sh mar|deploy|apple" >&2; exit 1 ;;
esac
