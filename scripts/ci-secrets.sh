#!/usr/bin/env bash
# Set the GitHub Actions secrets that .github/workflows/release.yml needs,
# from the keys on this Mac. Run once (and again after changing a key).
#   scripts/ci-secrets.sh [owner/repo]      default: the "origin" remote
# Needs: gh (logged in with access to the repo), the Developer ID identity in
# the login keychain, $FFB_ROOT/keys/mar/primary.key.pem.
# Nothing secret is printed; the .p12 only exists in $TMPDIR while it is sent.
#
# Secrets:
#   MAR_PRIMARY_KEY                 MAR signing key
#   MAC_DEVELOPER_ID_P12(+_PASSWORD)  Developer ID cert + key + Apple intermediates
#   APPLE_ID, APPLE_APP_PASSWORD    notarytool (asked for here)
#   DEPLOY_SSH_KEY                  new key, $FFB_ROOT/keys/ci/opz_deploy; the
#                                   server must accept it (printed at the end)
set -euo pipefail
. "$(dirname "$0")/../env.sh"
. "$OPZ_ROOT/updates/update.env"
[ "$OPZ_OS" = mac ] || { echo "ci-secrets: run this on the Mac that holds the keys" >&2; exit 1; }
command -v gh > /dev/null || { echo "ci-secrets: gh not found (brew install gh)" >&2; exit 1; }

repo="${1:-$(git -C "$OPZ_ROOT" remote get-url origin | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')}"
gh repo view "$repo" --json name > /dev/null \
    || { echo "ci-secrets: gh cannot see $repo (gh auth login / gh auth switch)" >&2; exit 1; }
echo "ci-secrets: setting secrets on $repo"
set_secret() { gh secret set "$1" -R "$repo" > /dev/null && echo "  $1"; }   # value on stdin

# MAR key
mar="$FFB_ROOT/keys/mar/primary.key.pem"
[ -f "$mar" ] || { echo "ci-secrets: $mar missing" >&2; exit 1; }
set_secret MAR_PRIMARY_KEY < "$mar"

# Developer ID: certificate from the keychain, key from keys/developer-id,
# plus Apple's "Developer ID Certification Authority" so the runner trusts it.
key="$FFB_ROOT/keys/developer-id/developer-id.key.pem"
[ -f "$key" ] || { echo "ci-secrets: $key missing" >&2; exit 1; }
work="$TMPDIR/ci-secrets"
rm -rf "$work"; (umask 077; mkdir -p "$work")
trap 'rm -rf "$work"' EXIT
sign_id="$(opz_mac_sign_identity)" || exit 1
security find-certificate -c "$sign_id" -p > "$work/cert.pem" \
    || { echo "ci-secrets: '$sign_id' not in the keychain" >&2; exit 1; }
security find-certificate -a -c "Developer ID Certification Authority" -p > "$work/ca.pem"
p12_pw="$(openssl rand -hex 24)"
openssl pkcs12 -export -inkey "$key" -in "$work/cert.pem" -certfile "$work/ca.pem" \
    -name "$sign_id" -passout "pass:$p12_pw" -out "$work/id.p12"
base64 < "$work/id.p12" | tr -d '\n' | set_secret MAC_DEVELOPER_ID_P12
printf '%s' "$p12_pw" | set_secret MAC_DEVELOPER_ID_P12_PASSWORD

# Notarization
read -r -p "Apple ID (email) for notarization: " apple_id
printf '%s' "$apple_id" | set_secret APPLE_ID
read -r -s -p "App-specific password (account.apple.com, xxxx-xxxx-xxxx-xxxx): " app_pw; echo
[ -n "$app_pw" ] || { echo "ci-secrets: empty password" >&2; exit 1; }
printf '%s' "$app_pw" | set_secret APPLE_APP_PASSWORD
unset app_pw

# Deploy key, only good for rsync into /srv/opz/updates (rrsync on the server)
ci="$FFB_ROOT/keys/ci"
(umask 077; mkdir -p "$ci")
[ -f "$ci/opz_deploy" ] || ssh-keygen -q -t ed25519 -N '' -C opz-github-actions -f "$ci/opz_deploy"
set_secret DEPLOY_SSH_KEY < "$ci/opz_deploy"

line="restrict,command=\"rrsync /srv/opz/updates\" $(cat "$ci/opz_deploy.pub")"
echo
echo "ci-secrets: done. The server must accept the deploy key: add this line to"
echo "~ubuntu/.ssh/authorized_keys on the update server (once):"
echo
echo "$line"
echo
read -r -p "Add it now over 'ssh sg-1'? [y/N] " ok
if [ "$ok" = y ] || [ "$ok" = Y ]; then
    printf '%s\n' "$line" | ssh sg-1 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && k=~/.ssh/authorized_keys && touch $k && chmod 600 $k && line="$(cat)" && { grep -qxF "$line" $k || { [ -z "$(tail -c1 $k)" ] || echo >> $k; printf "%s\n" "$line" >> $k; }; } && echo "ci-secrets: key added on $(hostname)"'
fi
