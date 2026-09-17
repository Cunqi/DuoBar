<div align="center">

# DuoBar

### I recreated the iPhone Duo status bar on my MacBook.

**Battery · Network · Volume — unified into one menu-bar indicator.**

[**Download the latest release**](https://github.com/Mikeli7666/DuoBar/releases/latest)

macOS 13+ · Apple Silicon or Intel · Universal 2 · Free and Open Source

</div>

## One glyph, three live states

DuoBar adapts the iPhone Duo-style three-in-one status concept for the Mac menu bar. One compact glyph presents the system information normally spread across several indicators:

- **Outer arc** → a live Battery Ring on MacBooks, or an Adaptive Ring on desktop Macs
- **Center** → the active network: Wi-Fi, Ethernet, or an offline/fallback state
- **Four lower dots** → live output volume

Persistent status stays monochrome and native-looking. When AirPods or another supported Bluetooth audio output becomes active, the center briefly transitions from Network → AirPods/headphones → Network. Disconnecting does not trigger an animation.

## Adaptive Ring and Battery Ring

On MacBooks, the outer Battery Ring shows live battery level, a dynamic charging bolt, and optional battery color coding for charging, Low Power Mode, and low-battery states. On desktop Macs, Adaptive Ring shows display brightness when publicly available and automatically surfaces sustained CPU, memory, or thermal pressure when it needs attention. It remains automatic: there is no manual metric selector.

## DuoBar on macOS

The repository retains the original 0.1 screenshots and videos as project history. Updated 1.0 visuals will be captured from the final validated build; the older annotated artwork is intentionally not shown here because its lower dots represented Bluetooth rather than Volume.

## Features

- Battery Ring with live level, dynamic charging bolt, low-battery state, and optional Battery Color Coding
- Adaptive Ring for desktop Macs: brightness baseline with automatic CPU, memory, and thermal pressure awareness
- Automatic Wi-Fi, Ethernet, and offline network states
- Four-dot live volume indicator
- Compact volume slider and public Core Audio mute control where supported
- Temporary AirPods/headphones connection presentation
- Adjustable menu-bar Icon Size
- Compact custom popover: Network, Volume, Battery, Audio Output, Settings, and Quit
- Light and Dark Mode
- Launch at Login
- Universal 2: Apple Silicon and Intel support on macOS 13+
- English, Simplified Chinese, and Traditional Chinese
- Native Swift, SwiftUI, and AppKit
- No Dock icon

## Requirements

**macOS 13.0+**<br>
**Apple Silicon or Intel**

## Installation

1. Download `DuoBar-1.1.0.dmg` from [GitHub Releases](https://github.com/Mikeli7666/DuoBar/releases).
2. Open the DMG and move DuoBar to Applications.
3. Try opening DuoBar from Applications.
4. If macOS blocks the first launch, right-click DuoBar and choose **Open**, or use **System Settings → Privacy & Security → Open Anyway**.

DuoBar 1.1.0 uses Hardened Runtime and ad-hoc signing. It is not yet Developer ID signed or notarized while Apple Developer Program enrollment is pending; notarized distribution is planned once it becomes available. Never disable Gatekeeper or System Integrity Protection to install DuoBar.

## Permissions

- **Location:** macOS may require authorization before CoreWLAN can expose the current Wi-Fi network name. Denying access does not break basic connection, interface, or signal state; the SSID may simply remain unavailable. DuoBar requests SSID access only when it is useful to the interface.
- **Bluetooth:** DuoBar retains public Bluetooth controller observation while Core Audio provides the primary source for Bluetooth audio endpoints. The app does not manage or pair devices.

## Audio output behavior

Volume control is available only when the active Core Audio output exposes software-settable public volume properties. HDMI, AirPlay, USB, and other external outputs may instead display **Controlled by device**.

AirPods and Bluetooth audio classification is best-effort using public system metadata. DuoBar does not claim exact AirPods generation detection.

## Privacy

- System-status processing occurs locally.
- No analytics or tracking.
- No backend or telemetry.
- No system-status uploads.
- No unrelated network requests.

## Known limitations

- The Wi-Fi network name may be unavailable without Location permission or when macOS withholds it.
- Wi-Fi strength uses documented RSSI data and broad signal ranges; it does not reproduce Apple's private icon algorithm.
- Some audio devices expose fixed or externally controlled volume.
- Bluetooth audio and AirPods family detection is best-effort through public APIs.

## Build from source

Open `DuoBar.xcodeproj` in Xcode, select the **DuoBar** scheme, and run. Debug builds include status simulation and marketing-capture tools; those tools are excluded from Release behavior.

## Disclaimer

DuoBar is an independent project and is not affiliated with or endorsed by Apple Inc.

## License

DuoBar is available under the [MIT License](LICENSE).
