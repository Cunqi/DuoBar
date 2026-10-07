# DuoBar Project Context

This is the stable project entry point. Technical facts live here; delivery progress belongs in the task or pull request.

## Purpose and platform

DuoBar is a native macOS menu-bar utility that combines battery or an alternate ring metric, network and output volume in one glyph. Its configurable popover provides system status and controls.

- Minimum platform: macOS 13.
- Languages and presentation: Swift in Swift 5 language mode, SwiftUI and AppKit.
- Project source of truth: the authored `DuoBar.xcodeproj/project.pbxproj`; there is no project generator.
- Package manager: Swift Package Manager for two repository-owned packages. Their manifests own package configuration; the Xcode project links their products.
- No backend, database, service port or third-party package dependency.

## Architecture and source ownership

- `DuoBar/App`: application entry and process lifecycle.
- `DuoBar/Features`: product modules, App-owned system services, feature UI, preferences and adapters. See `docs/ARCHITECTURE.md` for the module map.
- `DuoBarCore/Sources/DuoBarCore`: Foundation-only data models, pure calculations and state transitions, grouped by responsibility. It does not read preferences, access hardware, schedule tasks or render UI.
- `DuoBarKit/Sources/DuoBarKit`: reusable glyphs, layout components, display inputs, animation and geometry. It does not depend on Core or read App preferences. App adapters compose the two packages.
- `DuoBarCore/Tests`: isolated domain tests migrated from the App test target.
- `DuoBarTests`: App adapters, system-service integration, localization, rendering and lifecycle tests.
- `DuoBar/Assets.xcassets` and language folders: application-owned resources. Localization remains in the App bundle.
- `tools`, `marketing` and `release`: diagnostic tooling, authored media and historical release material; they are not App source targets.

The Core/Kit split follows the iOS workspace ownership model. The packages are macOS-specific where appropriate and do not adopt an iOS UI dependency. Retain the existing native appearance and system-owned interactions.

## Install, run and verify

Open `DuoBar.xcodeproj`, select the shared `DuoBar` scheme and run in Xcode. It resolves both packages from the same checkout. Signing and distribution settings remain authored in the project; local verification overrides signing without editing them.

- `./scripts/lint.sh`: checks architecture boundaries, parses package manifests and the Xcode project, and checks whitespace errors.
- `./scripts/acceptance-tests.sh`: runs Core package tests, builds Kit, and runs the App-hosted macOS integration test target in English/US because existing rendering assertions use English text. This affects only the test process. Hardware opt-in is disabled.
- `./scripts/build.sh`: unsigned Debug build.
- `./scripts/build.sh Release`: unsigned Release build, including production conditional compilation.
- `./scripts/build-diagnostic.sh`: compiles the existing standalone performance diagnostic against Core and its App-owned collectors; it does not run the diagnostic's synthetic workloads.

Build output is local under `build/`; Swift Package Manager uses each package's `.build/`. Tests may write temporary render artifacts. Test success establishes covered behavior, not human UI acceptance or device compatibility.

Debug builds retain existing simulation, performance diagnostics, glyph tuning and marketing capture tools. Release excludes those tools. No real-device or hardware-changing validation is authorized by routine build and test commands.

## Data and system boundaries

System services remain in the App and use public Apple frameworks: IOKit, Network, CoreWLAN, CoreLocation, CoreAudio, IOBluetooth and ServiceManagement. Core receives values captured by those services.

UI preferences remain in local UserDefaults with their existing keys. SSID availability depends on system authorization. The application does not upload system readings or manage a remote store. Production signing identities are not inferred from a developer's local signing edits.

## Authoritative sources and maintenance

- Current implemented product behavior: feature code and existing tests.
- Product documentation: the DuoBar Semina project, ID `4b6df6da-7aaa-4dc4-8153-d65146b6d1b4`, retrieved through Semina MCP.
- Architecture: `docs/ARCHITECTURE.md` and package manifests.
- README and `release/1.2.0` describe the earlier public distribution; the current fork includes additional functionality.

Update this file with any later package, runtime, build or architecture foundation change. Keep delivery history and unfinished work out of this file. Shared workspace instructions own GitHub delivery and approval requirements.
