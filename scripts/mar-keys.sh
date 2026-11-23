#!/usr/bin/env bash
# Create Opz's MAR signing keys (once). The updater of a full build
# (OPZ_BUILD=full) installs only update packages signed with one of them.
#
#   primary    signs every release (scripts/release.sh)
#   secondary  spare: if the primary key is lost or leaks, sign with this one
#              and ship new keys in the next release. Keep a copy offline.
#
# Private keys (never in git):  $FFB_ROOT/keys/mar/{primary,secondary}.key.pem
# Public certificates (in git): updates/certs/{primary,secondary}.der
#                               (compiled into the updater)
#
# WARNING: lose both private keys and installed copies of Opz can never be
# updated again (users would have to reinstall by hand). Back up
# $FFB_ROOT/keys/mar somewhere safe and private.
set -euo pipefail
. "$(dirname "$0")/../env.sh"

keys="$FFB_ROOT/keys/mar"
certs="$OPZ_ROOT/updates/certs"
mkdir -p "$keys" "$certs"
chmod 700 "$FFB_ROOT/keys" "$keys"

for k in primary secondary; do
    if [ -e "$keys/$k.key.pem" ] || [ -e "$certs/$k.der" ]; then
        echo "mar-keys: $k key or certificate already exists; refusing to overwrite" >&2
        echo "          ($keys/$k.key.pem, $certs/$k.der)" >&2
        exit 1
    fi
done

for k in primary secondary; do
    (umask 077; openssl genrsa -out "$keys/$k.key.pem" 4096 2>/dev/null)
    # Self-signed; NSS (signmar) needs a certificate next to the key. Its
    # dates do not matter to the updater, which only checks the signature.
    openssl req -new -x509 -key "$keys/$k.key.pem" -out "$keys/$k.cert.pem" \
        -subj "/CN=Opz Browser MAR signing ($k)" -days 36500
    openssl x509 -in "$keys/$k.cert.pem" -outform DER -out "$certs/$k.der"
    echo "mar-keys: $k  key $keys/$k.key.pem  cert $certs/$k.der"
    openssl x509 -in "$certs/$k.der" -inform DER -noout -fingerprint -sha256
done
echo "mar-keys: done. Back up $keys now (both keys), then commit updates/certs/."
