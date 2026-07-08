#!/usr/bin/env bash
set -euo pipefail

flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter pub publish --dry-run
