#!/usr/bin/env bash
# update-version.sh
# Usage: ./scripts/update-version.sh 1.2.3[+123]
# Updates:
# - pubspec.yaml (version)
# - android/app/build.gradle.kts (versionName, versionCode)
# - ios/bidscube_sdk_flutter.podspec (s.version)
# - lib/src/core/constants.dart (sdkVersion and webViewUserAgent)

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>  (example: 1.2.3 or 1.2.3+45)"
  exit 2
fi

VERSION_FULL="$1"
# Split into base and build
if [[ "$VERSION_FULL" == *+* ]]; then
  VERSION_BASE="${VERSION_FULL%%+*}"
  VERSION_BUILD="${VERSION_FULL#*+}"
else
  VERSION_BASE="$VERSION_FULL"
  VERSION_BUILD=""
fi

# Compute Android versionCode: if build present and numeric, use it; else compute from semver
if [[ -n "$VERSION_BUILD" && "$VERSION_BUILD" =~ ^[0-9]+$ ]]; then
  VERSION_CODE="$VERSION_BUILD"
else
  # Split VERSION_BASE into MAJOR, MINOR, PATCH safely
  # e.g. 1.2.3 -> MAJOR=1 MINOR=2 PATCH=3
  MAJOR="${VERSION_BASE%%.*}"
  REST="${VERSION_BASE#*.}"
  if [[ "$REST" == "$VERSION_BASE" ]]; then
    # No dot in VERSION_BASE
    MINOR=0
    PATCH=0
  else
    MINOR="${REST%%.*}"
    if [[ "$REST" == "$MINOR" ]]; then
      PATCH=0
    else
      PATCH="${REST#*.}"
    fi
  fi

  # Ensure numeric values (fallback to 0)
  if ! [[ "$MAJOR" =~ ^[0-9]+$ ]]; then MAJOR=0; fi
  if ! [[ "$MINOR" =~ ^[0-9]+$ ]]; then MINOR=0; fi
  if ! [[ "$PATCH" =~ ^[0-9]+$ ]]; then PATCH=0; fi

  # Compute versionCode = M*10000 + m*100 + p
  VERSION_CODE=$((MAJOR*10000 + MINOR*100 + PATCH))
fi

echo "Updating versions to: full='$VERSION_FULL' base='$VERSION_BASE' code=$VERSION_CODE"

# Safe inplace replace helper using awk and tempfile
# Arguments: filepath, awk-script
_replace_with_awk() {
  local file="$1" awkprog="$2"
  if [ ! -f "$file" ]; then
    echo "Warning: file not found: $file" >&2
    return 0
  fi
  local tmp
  tmp=$(mktemp)
  awk -v full="$VERSION_FULL" -v base="$VERSION_BASE" -v code="$VERSION_CODE" "$awkprog" "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "Updated $file"
}

# 1) pubspec.yaml: replace first occurrence of version: <...>
_replace_with_awk "pubspec.yaml" '
BEGIN{done=0}
/^version:[[:space:]]*/ && !done { print "version: " full; done=1; next }
{ print }
END{ if(!done){ print "version: " full } }
'

# 2) android/app/build.gradle.kts: replace versionCode and versionName if present; otherwise insert under defaultConfig
_replace_with_awk "android/app/build.gradle.kts" '
BEGIN{vc_seen=0;vn_seen=0; in_default=0}
/^[[:space:]]*defaultConfig[[:space:]]*\{/ { print; in_default=1; next }
/^[[:space:]]*\}/ && in_default==1 { if(vn_seen==0){ printf("    versionName = \"%s\"\n", base) } if(vc_seen==0){ printf("    versionCode = %s\n", code) } in_default=0; print; next }
/^[[:space:]]*versionCode[[:space:]]*=/ { print gensub(/^[[:space:]]*versionCode[[:space:]]*=.*/, "    versionCode = " code, "g"); vc_seen=1; next }
/^[[:space:]]*versionName[[:space:]]*=/ { print gensub(/^[[:space:]]*versionName[[:space:]]*=.*/, "    versionName = \"" base "\"", "g"); vn_seen=1; next }
{ print }
END{ }
'

# 3) ios podspec: replace s.version = '...'
_replace_with_awk "ios/bidscube_sdk_flutter.podspec" '
{ if($0 ~ /^[[:space:]]*s\.version[[:space:]]*=/){ sub(/^[[:space:]]*s\.version[[:space:]]*=.*/, "  s.version          = \"" full "\"") ; print } else print }
'

# 4) lib/src/core/constants.dart: update sdkVersion and webViewUserAgent
_replace_with_awk "lib/src/core/constants.dart" '
{ if($0 ~ /^[[:space:]]*static[[:space:]]+const[[:space:]]+String[[:space:]]+sdkVersion[[:space:]]*=.*/){ sub(/\=.*/, "= \"" base "\";"); print } else if($0 ~ /^[[:space:]]*static[[:space:]]+const[[:space:]]+String[[:space:]]+webViewUserAgent[[:space:]]*=.*/){ sub(/\=.*/, "= \"BidscubeSDK-Flutter/" base "\";"); print } else print }
'

# 5) Prepend changelog entry: put new version heading + single bullet 'Bug fixed for input version' at the top of CHANGELOG.md
CHANGELOG_FILE="CHANGELOG.md"
ENTRY_DATE="$(date +%F)"
ENTRY_TITLE="## ${VERSION_FULL} - ${ENTRY_DATE}"
ENTRY_BODY="- Bug fixed: input version handling"

# Build the entry block
ENTRY_BLOCK="${ENTRY_TITLE}\n\n${ENTRY_BODY}\n\n"

if [ -f "$CHANGELOG_FILE" ]; then
  # Prepend safely: write entry to tmp then append existing content
  tmpfile=$(mktemp)
  printf "%b" "$ENTRY_BLOCK" > "$tmpfile"
  cat "$CHANGELOG_FILE" >> "$tmpfile"
  mv "$tmpfile" "$CHANGELOG_FILE"
  echo "Prepended changelog entry to $CHANGELOG_FILE"
else
  # Create a new changelog with the entry
  cat > "$CHANGELOG_FILE" <<CLF
# Changelog

$ENTRY_BLOCK
CLF
  echo "Created $CHANGELOG_FILE with initial entry"
fi

# done
cat <<EOF
Summary:
 - pubspec.yaml -> version: $VERSION_FULL
 - android/app/build.gradle.kts -> versionName: $VERSION_BASE, versionCode: $VERSION_CODE
 - ios/bidscube_sdk_flutter.podspec -> s.version: $VERSION_FULL
 - lib/src/core/constants.dart -> sdkVersion/webViewUserAgent: $VERSION_BASE
Please review the changed files and commit when ready.
EOF

exit 0
