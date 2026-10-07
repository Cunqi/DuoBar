#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$task_root"
task_configuration="${1:-Debug}"
if [[ "$task_configuration" != Debug && "$task_configuration" != Release ]]; then
    print -u2 'Usage: scripts/build.sh [Debug|Release]'
    exit 2
fi
xcodebuild -project DuoBar.xcodeproj -scheme DuoBar -configuration "$task_configuration" -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
