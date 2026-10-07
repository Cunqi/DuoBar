#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$task_root"
swift build --package-path DuoBarCore
task_bin="$(swift build --package-path DuoBarCore --show-bin-path)"
mkdir -p build
if [[ -f "$task_bin/libDuoBarCore.a" ]]; then
    task_modules="$task_bin"
    task_objects=("$task_bin/libDuoBarCore.a")
else
    task_modules="$task_bin/Modules"
    task_objects=("$task_bin"/DuoBarCore.build/*.swift.o)
fi
swiftc -parse-as-library -swift-version 5 -I "$task_modules" \
    "${task_objects[@]}" \
    DuoBar/Features/System/Services/DeviceContextService.swift \
    DuoBar/Features/OuterRing/Services/PerformanceTelemetryService.swift \
    tools/performance-ring/PerformanceRingDiagnostic.swift \
    -o build/PerformanceRingDiagnostic
