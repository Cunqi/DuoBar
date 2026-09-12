<div align="center">

# DuoBar
I recreated the iPhone Duo status bar on my MacBook. Here’s the beta version 

### I recreated the iPhone Duo status bar on my MacBook.

**Battery · Wi-Fi · Bluetooth — unified into one menu bar indicator.**

[**Download DuoBar 0.1 Beta**](https://github.com/Mikeli7666/DuoBar/releases/tag/v0.1.0-beta)

macOS 15+ · Apple Silicon · Open Source

</div>

## One glyph, three live states

DuoBar recreates the iPhone Duo three-in-one status concept on macOS, mapping real Mac system state into one compact menu-bar glyph:

- **Outer arc** → live battery level
- **Center Wi-Fi glyph** → live Wi-Fi connection and signal
- **Four lower dots** → Bluetooth state
- **Lightning indicator** → charging

## DuoBar on macOS

> A real DuoBar menu-bar screenshot is being prepared. The capture specification is available in [`assets/README.md`](assets/README.md).

## Features

- Live battery level
- Charging state
- Live Wi-Fi status
- Bluetooth status
- Single compact menu-bar glyph
- Light and Dark Mode
- Launch at Login
- Native SwiftUI + AppKit
- No Dock icon

## Requirements

<strong>macOS 15.0+</strong><br>
<strong>Apple Silicon</strong>

## Installation

1. Download `DuoBar-0.1.0-beta.dmg` from the [latest Beta release](https://github.com/Mikeli7666/DuoBar/releases/tag/v0.1.0-beta).
2. Open the DMG.
3. Drag DuoBar into Applications.
4. Open DuoBar from Applications.

DuoBar 0.1 Beta is not currently Developer ID signed or notarized. macOS may therefore ask you to explicitly approve the app on first launch. If it is blocked, use Finder's contextual **Open** option where available, or go to **System Settings → Privacy & Security → Open Anyway**.

Do not disable Gatekeeper, System Integrity Protection, or other macOS security protections to install DuoBar.

## Permissions

- **Location:** macOS may require authorization before CoreWLAN can expose the current Wi-Fi network name. If access is denied, Wi-Fi connection and signal information remain available where public APIs permit, while the network name may be unavailable.
- **Bluetooth:** used to read whether the Mac's Bluetooth controller is available and powered on. If the state cannot be read, DuoBar reports Bluetooth as unavailable and continues running.

DuoBar requests Wi-Fi network-name access only when its popover is opened and does not repeatedly request permission after the user has made a choice.

## Privacy

- System-status processing occurs locally.
- No analytics or tracking SDKs.
- No backend.
- No system-status uploads.
- No unrelated network requests.

## Known limitations

- DuoBar 0.1 is Beta software and is not Developer ID signed or notarized.
- The current Beta supports Apple Silicon Macs only.
- The Wi-Fi network name may be unavailable without Location permission or when macOS withholds it.
- Bluetooth support is limited to controller availability and power state; device management and accessory battery levels are not included.

## How to quit

Click the DuoBar glyph, then choose **Quit DuoBar** from the popover. Settings are available from the same popover.

## Build from source

Open `DuoBar.xcodeproj` in Xcode, select the **DuoBar** scheme, and run. Debug builds include status simulation and glyph-tuning tools; those tools are excluded from Release builds.

## Disclaimer

DuoBar is an independent project and is not affiliated with or endorsed by Apple Inc.

## License

DuoBar is available under the [MIT License](LICENSE).
