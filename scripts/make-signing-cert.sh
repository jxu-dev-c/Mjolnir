#!/usr/bin/env bash
# One-time: creates the self-signed "Mjolnir Release" code-signing identity in
# your login keychain and stores it as the release workflow's secrets
# (SIGNING_CERT_P12, SIGNING_CERT_PASSWORD) on jxu-dev-c/Mjolnir.
#
# Keep the identity: macOS ties permission grants (microphone, camera,
# automation) to the signing certificate, so a new one makes every user
# grant them again. macOS asks for your password to trust the certificate.
#
#   scripts/make-signing-cert.sh            create (or reuse) and upload
#   REPO=owner/name scripts/make-signing-cert.sh
set -euo pipefail

NAME="Mjolnir Release"
REPO="${REPO:-jxu-dev-c/Mjolnir}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

command -v gh >/dev/null || { echo "needs the GitHub CLI (gh)" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
umask 077
PASSWORD="$(openssl rand -hex 16)"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  # Don't replace it (that would reset everyone's permission grants).
  echo "\"$NAME\" already exists. To re-upload it, export it from Keychain Access" >&2
  echo "(My Certificates > $NAME > Export, .p12 with a password) and run:" >&2
  echo "  base64 -i id.p12 | gh secret set SIGNING_CERT_P12 -R $REPO" >&2
  echo "  gh secret set SIGNING_CERT_PASSWORD -R $REPO" >&2
  exit 1
fi

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Use the system LibreSSL so the .p12 format is one `security import` understands.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" -out "$WORK/id.p12" -passout "pass:$PASSWORD"

security import "$WORK/id.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

base64 -i "$WORK/id.p12" | gh secret set SIGNING_CERT_P12 -R "$REPO"
printf '%s' "$PASSWORD" | gh secret set SIGNING_CERT_PASSWORD -R "$REPO"

echo "Created \"$NAME\" and set SIGNING_CERT_P12 / SIGNING_CERT_PASSWORD on $REPO."
