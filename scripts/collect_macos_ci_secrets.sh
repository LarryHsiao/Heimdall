#!/usr/bin/env bash
#
# Heimdall — one-time-use collector for the secrets that
# scripts/build_macos_dmg.sh needs on the CI runner.
#
# Run this on the Mac that holds your Developer ID Application
# certificate in its login keychain. The script gathers six values and
# writes them to macos_ci_secrets.env (mode 600) in the current
# directory. Transcribe each value into your CI provider's secret
# store, then delete the file.
#
# This script is bash-3.2 compatible (the default /bin/bash on macOS).
#
# DO NOT commit macos_ci_secrets.env. The .gitignore already excludes
# it; if you move or rename, exclude the new path too.
#
set -euo pipefail

OUT_FILE="${OUT_FILE:-macos_ci_secrets.env}"

if [ -e "$OUT_FILE" ]; then
  echo "error: $OUT_FILE already exists. Move it aside before re-running." >&2
  exit 1
fi

echo "==> Heimdall CI secrets collector"
echo
echo "  Output file: $OUT_FILE (will be written with mode 600)"
echo

# --- 1. Developer ID Application certificate ---
echo "Step 1/4 — Developer ID Application certificate (.p12)"
echo
echo "  Export the cert from Keychain Access (GUI):"
echo "    1. Open Keychain Access.app"
echo "    2. Select the 'login' keychain"
echo "    3. Right-click your Developer ID Application certificate → Export…"
echo "    4. Format: Personal Information Exchange (.p12)"
echo "    5. Set a password — the CI runner will use it as"
echo "       DEVELOPER_ID_CERT_PASSWORD"
echo "    6. Save the .p12 somewhere temporary"
echo

P12_PATH=""
while [ -z "$P12_PATH" ] || [ ! -f "$P12_PATH" ]; do
  read -e -r -p "  Path to the exported .p12: " P12_PATH
  P12_PATH="${P12_PATH/#\~/$HOME}"
  if [ ! -f "$P12_PATH" ]; then
    echo "  error: file not found — try again." >&2
    P12_PATH=""
  fi
done

CERT_PASSWORD=""
while [ -z "$CERT_PASSWORD" ]; do
  read -r -s -p "  Password you set on the .p12: " CERT_PASSWORD
  echo
  if [ -z "$CERT_PASSWORD" ]; then
    echo "  error: password must not be empty — try again." >&2
  fi
done

echo "  Verifying the .p12 password…"
if ! openssl pkcs12 -in "$P12_PATH" -passin pass:"$CERT_PASSWORD" -noout \
    -legacy 2>/dev/null \
    && ! openssl pkcs12 -in "$P12_PATH" -passin pass:"$CERT_PASSWORD" -noout 2>/dev/null; then
  echo "error: the .p12 cannot be opened with that password" >&2
  exit 1
fi

CERT_BASE64=$(base64 -i "$P12_PATH")
echo "  .p12 base64-encoded."
echo

# --- 2. App Store Connect API key (.p8) ---
echo "Step 2/4 — App Store Connect API key (.p8)"
echo
echo "  Download one from https://appstoreconnect.apple.com/access/api"
echo "  Note: Apple lets you download a .p8 only once — keep the file"
echo "  somewhere safe."
echo

P8_PATH=""
while [ -z "$P8_PATH" ] || [ ! -f "$P8_PATH" ]; do
  read -e -r -p "  Path to the .p8 file: " P8_PATH
  P8_PATH="${P8_PATH/#\~/$HOME}"
  if [ ! -f "$P8_PATH" ]; then
    echo "  error: file not found — try again." >&2
    P8_PATH=""
  fi
done

echo "  Verifying the .p8 looks like a private key…"
if ! openssl pkey -in "$P8_PATH" -noout 2>/dev/null; then
  echo "error: $P8_PATH does not parse as a private key" >&2
  exit 1
fi

KEY_BASE64=$(base64 -i "$P8_PATH")
echo "  .p8 base64-encoded."
echo

# --- 3. Key ID and Issuer ID ---
echo "Step 3/4 — Key ID and Issuer ID"
echo "  Both are on the same App Store Connect page where you downloaded"
echo "  the key."
echo

KEY_ID=""
while [ -z "$KEY_ID" ]; do
  read -r -p "  NOTARY_API_KEY_ID: " KEY_ID
  if [ -z "$KEY_ID" ]; then
    echo "  error: must not be empty — try again." >&2
  fi
done

ISSUER_ID=""
while [ -z "$ISSUER_ID" ]; do
  read -r -p "  NOTARY_API_ISSUER_ID: " ISSUER_ID
  if [ -z "$ISSUER_ID" ]; then
    echo "  error: must not be empty — try again." >&2
  fi
done
echo

# --- 4. Random KEYCHAIN_PASSWORD ---
echo "Step 4/4 — Random KEYCHAIN_PASSWORD"
KEYCHAIN_PASSWORD=$(openssl rand -hex 16)
echo "  Generated (32 hex chars)."
echo

# --- Write the output file ---
umask 077
cat > "$OUT_FILE" <<EOF
# Heimdall CI secrets — written $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Paste each value into your CI provider's secret store.
# Delete this file once the values are copied.

DEVELOPER_ID_CERT_BASE64="$CERT_BASE64"
DEVELOPER_ID_CERT_PASSWORD="$CERT_PASSWORD"
NOTARY_API_KEY_BASE64="$KEY_BASE64"
NOTARY_API_KEY_ID="$KEY_ID"
NOTARY_API_ISSUER_ID="$ISSUER_ID"
KEYCHAIN_PASSWORD="$KEYCHAIN_PASSWORD"

# FLUTTER_BIN is optional. Set it only if your runner needs a non-default
# binary — e.g. "fvm flutter" when running through FVM.
# FLUTTER_BIN="fvm flutter"
EOF
chmod 600 "$OUT_FILE"

echo "==> Wrote $OUT_FILE (mode 600)."
echo
echo "  Next steps:"
echo "    1. Paste each value into your CI provider's secret store"
echo "       (GitHub Actions → Settings → Secrets and variables → Actions,"
echo "        GitLab → Settings → CI/CD → Variables, etc.)."
echo "    2. Delete $OUT_FILE — it carries your private key and certificate."
echo "         rm -P $OUT_FILE      # macOS overwrite-and-delete"
