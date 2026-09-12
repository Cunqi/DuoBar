# DuoBar
I recreated the iPhone Duo on my MacBook. Here’s the beta version 

A compact three-in-one system status indicator for macOS.

DuoBar is an independent macOS utility and is not affiliated with Apple Inc.

DuoBar combines battery, Wi-Fi, and Bluetooth into one native menu-bar glyph:

- The outer arc shows battery level.
- The center shows live Wi-Fi status.
- The four lower dots show Bluetooth state.
- A charging indicator is integrated into the battery layer.

## Features

- Live battery level and charging state
- Live Wi-Fi connection and signal status
- Basic Bluetooth availability and power state
- Unified compact menu-bar interface
- Native SwiftUI and AppKit implementation
- Light and Dark Mode support
- Launch at Login
- No Dock icon

## Requirements

- macOS 15.0 or later
- Apple Silicon (`arm64`) for the current beta artifact

## Installation

1. Download `DuoBar-0.1.0-beta.dmg`.
2. Open the disk image.
3. Drag DuoBar into the Applications folder.
4. Launch DuoBar from Applications.

DuoBar 0.1 Beta is an early independently distributed build and is not notarized with a Developer ID. macOS may therefore ask you to explicitly approve the app the first time it is opened. If it is blocked, try Finder's **Open** command from the contextual menu. You can also open **System Settings → Privacy & Security** and use the macOS-provided **Open Anyway** option for DuoBar.

Do not disable Gatekeeper or System Integrity Protection to install DuoBar.

## Permissions

- **Location:** macOS may require location authorization before CoreWLAN can expose the current Wi-Fi network name. If access is denied, DuoBar continues to show Wi-Fi connection and signal information when the public APIs make it available, but the network name may show as unavailable.
- **Bluetooth:** used to read whether the Mac's Bluetooth controller is available and powered on. If the state cannot be read, DuoBar reports Bluetooth as unavailable and continues running.

DuoBar requests Wi-Fi network-name access only when its popover is opened and does not repeatedly request a permission after the user has made a choice.

## Privacy

System-status processing happens locally on the Mac. This version contains no analytics or tracking SDK, has no backend, does not upload system information, and makes no unrelated network requests.

## Known limitations

- This is beta software and is not Developer ID signed or notarized for public distribution.
- The current beta artifact supports Apple Silicon Macs only.
- The Wi-Fi network name may be unavailable without Location permission or when macOS withholds it.
- Bluetooth support is intentionally limited to controller availability and power state; device management and accessory battery levels are not included.

## Settings and Quit

Click the DuoBar glyph to open its popover. Choose **Settings** to configure Launch at Login, battery percentage, and animations. Choose **Quit DuoBar** to exit the app.

## Build from source

Open `DuoBar.xcodeproj` in Xcode, select the **DuoBar** scheme, and run. Debug builds include status simulation and glyph-tuning tools; those tools are excluded from Release builds.

## License

DuoBar is available under the [MIT License](LICENSE).
