#!/usr/bin/env bash
# android-release.sh: the release-lane helpers behind scripts/ship-android.sh.
# Sourcing contract: android-env.sh is already sourced and `fail <step>` is
# defined (print and exit non-zero).

# version_property <KEY> -> echoes KEY's value from version.properties
version_property() {
  grep -m1 "^$1=" "$ANDROID_VERSION_FILE" | cut -d= -f2- | tr -d '[:space:]'
}

# write_build_number <N>: patch version.properties in place, then read it back
# to prove the edit landed.
write_build_number() {
  local new_build_number="$1"
  sed -i '' -E "s/^BUILD_NUMBER=.*/BUILD_NUMBER=$new_build_number/" "$ANDROID_VERSION_FILE"
  [[ "$(version_property BUILD_NUMBER)" == "$new_build_number" ]] || fail "build number (version.properties not updated)"
  echo "version.properties: BUILD_NUMBER=$new_build_number"
}

# signing_property <key> -> value from the release-key properties file
signing_property() { grep -m1 "^$1=" "$ANDROID_SIGNING_PROPERTIES" | cut -d= -f2-; }

# verify_release_apk <apk> <versionCode> <versionName>
# Asserts the version numbers and that the APK is signed by OUR release key
# (not unsigned, not the debug key). Sets KEYSTORE_CERT_SHA256 for the notes.
verify_release_apk() {
  local apk="$1" expected_code="$2" expected_name="$3"
  local badging signer_output apk_cert_sha256
  badging="$("$ANDROID_BUILD_TOOLS/aapt2" dump badging "$apk" | head -1)"
  echo "$badging"
  [[ "$badging" == *"versionCode='$expected_code'"* && "$badging" == *"versionName='$expected_name'"* ]] \
    || fail "release build (expected versionCode $expected_code / versionName $expected_name)"

  signer_output="$("$ANDROID_BUILD_TOOLS/apksigner" verify --print-certs "$apk")" \
    || fail "apksigner verify (unsigned or invalid APK)"
  echo "$signer_output" | grep -E 'DN:|SHA-256'
  apk_cert_sha256="$(echo "$signer_output" | grep -m1 'SHA-256 digest' | awk '{print $NF}')"
  KEYSTORE_CERT_SHA256="$(keytool -list -v -keystore "$(signing_property storeFile)" \
    -alias "$(signing_property keyAlias)" -storepass "$(signing_property storePassword)" \
    | grep -m1 'SHA256:' | awk '{print $2}' | tr -d ':' | tr 'A-F' 'a-f')"
  [[ -n "$apk_cert_sha256" && "$apk_cert_sha256" == "$KEYSTORE_CERT_SHA256" ]] \
    || fail "signature (APK cert $apk_cert_sha256 is not the release key $KEYSTORE_CERT_SHA256)"
  echo "Signed by the release key ($KEYSTORE_CERT_SHA256)"
}

# release_smoke <screenshot.png> <input-or-empty> <expected text>...
# Installs the RELEASE build on the emulator and asserts each expected text is
# on screen via uiautomator. A screenshot alone is not enough: R8 breakage
# (stripped reflection, missing classpath resources) often renders a screen
# that looks fine but is missing content.
release_smoke() {
  local screenshot="$1" smoke_input="$2"; shift 2
  local run_arguments=(--release --screenshot "$screenshot") screen_text expected_text
  [[ -n "$smoke_input" ]] && run_arguments+=(--input "$smoke_input")
  "$ANDROID_SCRIPTS_DIR/run-android.sh" "${run_arguments[@]}" || fail "smoke install"
  adb shell uiautomator dump /sdcard/release-smoke.xml >/dev/null
  screen_text="$(adb shell cat /sdcard/release-smoke.xml)"
  for expected_text in "$@"; do
    [[ "$screen_text" == *"text=\"$expected_text\""* ]] \
      || fail "smoke ('$expected_text' not on screen; see $screenshot)"
    echo "on screen: $expected_text"
  done
}

# release_notes <apk> <version name> <build number> -> markdown on stdout
release_notes() {
  local apk="$1" version_name="$2" build_number="$3"
  local install_page="https://github.com/$GITHUB_REPOSITORY/blob/main/docs/android-install.md"
  cat <<NOTES
$ANDROID_APP_NAME for Android, version $version_name (build $build_number).

- APK: \`$(basename "$apk")\` ($(du -h "$apk" | awk '{print $1}'))
- SHA-256: \`$(shasum -a 256 "$apk" | awk '{print $1}')\`
- Signing certificate SHA-256: \`$KEYSTORE_CERT_SHA256\`
- Built from: \`$(git -C "$ANDROID_REPO_DIR" rev-parse --short HEAD)\`

How to install it, and get updates automatically with Obtainium: [$install_page]($install_page)
NOTES
}
