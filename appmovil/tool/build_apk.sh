#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$(dirname "$app_dir")"
flutter_bin="${FLUTTER_BIN:-flutter}"

if [[ -x "$project_dir/.tools/java21/Contents/Home/bin/java" ]]; then
  export JAVA_HOME="$project_dir/.tools/java21/Contents/Home"
fi

cd "$app_dir"
if [[ -f config/local.json ]]; then
  exec "$flutter_bin" build apk --release --dart-define-from-file=config/local.json "$@"
else
  exec "$flutter_bin" build apk --release "$@"
fi
