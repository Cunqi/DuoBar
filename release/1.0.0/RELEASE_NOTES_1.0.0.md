# DuoBar 1.0.0

DuoBar 1.0.0 is the first stable release.

## Highlights

- Redesigned three-part menu-bar glyph
- Live battery level in the outer arc, with charging and low-battery feedback
- Automatic Wi-Fi, Ethernet, and offline network state in the center
- Four-dot live output-volume indicator
- Interactive volume and mute controls where the active output supports them
- Temporary AirPods and Bluetooth-headphones connection presentation
- Improved glyph size and readability
- Event-driven system monitoring and lifecycle improvements
- Graceful Wi-Fi behavior when Location permission is unavailable

## Requirements and limitations

- Requires macOS 15 or later on Apple Silicon.
- This independently distributed release is ad-hoc signed and is not notarized. macOS may require explicit approval through Finder's **Open** command or **System Settings → Privacy & Security → Open Anyway**.
- Wi-Fi SSID access may require Location permission; basic network status continues to work without it.
- Some HDMI, AirPlay, USB, and other external audio outputs control volume on the device and cannot be adjusted by DuoBar.
- Bluetooth audio and AirPods family detection is best-effort using public macOS metadata. DuoBar does not identify exact AirPods generations.

DuoBar processes system status locally and includes no analytics, tracking, telemetry, or backend service.
