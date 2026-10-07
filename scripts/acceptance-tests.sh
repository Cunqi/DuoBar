#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$task_root"
unset DUOBAR_HARDWARE_VALIDATION
swift test --package-path DuoBarCore
swift build --package-path DuoBarKit
xcodebuild -project DuoBar.xcodeproj -scheme DuoBar -configuration Debug -destination 'platform=macOS' -testLanguage en -testRegion US -derivedDataPath build/DerivedData -resultBundlePath "build/Acceptance-$(date +%Y%m%d-%H%M%S).xcresult" CODE_SIGNING_ALLOWED=NO test
