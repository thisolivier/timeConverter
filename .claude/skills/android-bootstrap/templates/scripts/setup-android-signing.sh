#!/usr/bin/env bash
# setup-android-signing.sh: create the Android release key, once.
#
#   scripts/setup-android-signing.sh
#
# Writes, outside the repo (directory of $ANDROID_SIGNING_PROPERTIES, default
# ~/.config/__APPLICATION_ID__/):
#   android-release.jks         PKCS12, RSA 4096, 10000 days
#   android-release.properties  storeFile/storePassword/keyAlias/keyPassword (mode 600)
#
# Idempotent: if both files exist it prints the certificate fingerprint and
# exits 0. It never overwrites a keystore. android/app/build.gradle.kts reads
# the properties file; without it release builds are left unsigned.
#
# Why this key matters: Android only installs an update over an installed app
# when both are signed with the same key. Every release any phone ever
# installs must come from THIS keystore.
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"

PROPERTIES_FILE="$ANDROID_SIGNING_PROPERTIES"
SIGNING_CONFIG_DIR="$(dirname "$PROPERTIES_FILE")"
KEYSTORE_FILE="$SIGNING_CONFIG_DIR/android-release.jks"
KEY_ALIAS="release"

print_backup_reminder() {
  cat <<REMINDER

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !!  BACK UP THE ANDROID RELEASE KEY OFF THIS MAC, BOTH FILES:           !!
  !!    $KEYSTORE_FILE
  !!    $PROPERTIES_FILE
  !!  (e.g. into the password manager as attachments).                     !!
  !!  Lose them and installed copies can NEVER be updated: Android         !!
  !!  refuses updates signed by a different key; the only way out is       !!
  !!  uninstalling on every phone and losing the app's data.               !!
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
REMINDER
}

read_property() { grep -m1 "^$1=" "$PROPERTIES_FILE" | cut -d= -f2-; }

print_fingerprint() {
  keytool -list -v -keystore "$(read_property storeFile)" -alias "$(read_property keyAlias)" \
    -storepass "$(read_property storePassword)" | grep -E 'SHA256:|Valid from|Owner:'
}

if [[ -f "$KEYSTORE_FILE" && -f "$PROPERTIES_FILE" ]]; then
  echo "Release key already exists: $KEYSTORE_FILE"
  print_fingerprint
  print_backup_reminder
  exit 0
fi

if [[ -f "$KEYSTORE_FILE" || -f "$PROPERTIES_FILE" ]]; then
  echo "Error: only one of the two signing files exists. Refusing to guess:"
  echo "  $KEYSTORE_FILE"
  echo "  $PROPERTIES_FILE"
  echo "Restore the missing one from the backup. Never regenerate a key that"
  echo "has already signed a published release."
  exit 1
fi

mkdir -p "$SIGNING_CONFIG_DIR"
chmod 700 "$SIGNING_CONFIG_DIR"

# PKCS12 keystores use one password for store and key; keytool enforces that.
GENERATED_PASSWORD="$(openssl rand -base64 33 | tr -d '/+=\n')"

keytool -genkeypair \
  -keystore "$KEYSTORE_FILE" -storetype PKCS12 \
  -alias "$KEY_ALIAS" -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$GENERATED_PASSWORD" -keypass "$GENERATED_PASSWORD" \
  -dname "CN=$ANDROID_APP_NAME, O=$ANDROID_APP_ID" >/dev/null
chmod 600 "$KEYSTORE_FILE"

( umask 077
  cat > "$PROPERTIES_FILE" <<PROPERTIES
storeFile=$KEYSTORE_FILE
storePassword=$GENERATED_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$GENERATED_PASSWORD
PROPERTIES
)
chmod 600 "$PROPERTIES_FILE"

echo "Created release key: $KEYSTORE_FILE"
print_fingerprint
print_backup_reminder
