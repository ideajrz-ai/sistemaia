#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$(dirname "$app_dir")"
flutter_bin="${FLUTTER_BIN:-flutter}"

if [[ -x "$project_dir/.tools/java17/Contents/Home/bin/java" ]]; then
  export JAVA_HOME="$project_dir/.tools/java17/Contents/Home"
fi

cd "$app_dir"
config_args=()
if [[ -f config/local.json ]]; then
  config_args+=(--dart-define-from-file=config/local.json)
fi
"$flutter_bin" build apk --release "${config_args[@]}" "$@"
