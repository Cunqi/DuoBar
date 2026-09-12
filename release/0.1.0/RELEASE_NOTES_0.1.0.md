# DuoBar 0.1.0 Beta

DuoBar combines battery, Wi-Fi, and Bluetooth status into one compact native macOS menu-bar glyph.

## What's included

- Live battery level and charging state
- Live Wi-Fi connection, signal, and network name when available
- Bluetooth controller availability and power state
- Compact popover with Settings and Quit access
- Launch at Login, battery-percentage, and animation preferences
- Native Light and Dark Mode support

## Known limitations

- This beta is not Developer ID signed or notarized.
- The current release supports Apple Silicon Macs running macOS 15.0 or later.
- Wi-Fi network name can be unavailable without Location permission.
- Bluetooth support is limited to controller availability and power state.

## Installation

Open `DuoBar-0.1.0-beta.dmg`, then drag DuoBar to Applications. On first launch, macOS may block this independently distributed beta. Use Finder's contextual **Open** command, or go to **System Settings → Privacy & Security** and use the macOS-provided **Open Anyway** option. Do not disable Gatekeeper or System Integrity Protection.

## Permissions

- Location is requested only when needed to obtain the current Wi-Fi network name.
- Bluetooth access is used only to read the controller's availability and power state.
- DuoBar remains operational if either permission or status is unavailable.

## Download verification

SHA-256 (`DuoBar-0.1.0-beta.dmg`): `7d7dd8b54ff41127eb2445611777097d1dec1a66b2655f3634c458cc709c94f3`
