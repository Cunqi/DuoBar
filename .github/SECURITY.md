# Security Policy

## Supported Versions

DuoBar is supported on its latest stable public release only. Earlier releases do not receive security fixes.

| Version | Supported |
| --- | --- |
| Latest public release | Yes |
| Earlier releases | No |

## Reporting a Vulnerability

Please do not disclose unresolved security vulnerabilities in public GitHub Issues. Use the repository's **Security → Report a vulnerability** option (GitHub Private Vulnerability Reporting). If that option is unavailable, open an issue containing no vulnerability details and ask the maintainers to arrange a private reporting channel.

Reports will be acknowledged and investigated responsibly as soon as reasonably possible. Include the macOS version, DuoBar version, reproduction steps, potential impact, and relevant logs or screenshots with sensitive information removed.

## Privacy and Data Handling

DuoBar processes battery, network, volume, Bluetooth audio-device, and charging state locally. It has no analytics, tracking, backend service, or telemetry, and no system-status data is uploaded.

Location permission, when requested, is used only to access Wi-Fi SSID information through macOS APIs.

## Scope

Security issues in DuoBar itself are in scope. General macOS, Apple framework, or third-party operating-system vulnerabilities are outside the project's scope unless DuoBar directly contributes to the issue.
