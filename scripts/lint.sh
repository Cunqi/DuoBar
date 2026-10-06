#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$task_root"
python3 scripts/check-architecture.py
plutil -lint DuoBar.xcodeproj/project.pbxproj
git diff --check
