# DuoBar Architecture

The host App composes two repository-owned Swift packages. Core and Kit have no dependency on each other.

| Layer | Owns | Does not own |
| --- | --- | --- |
| DuoBarCore | System value models, classification, thresholds, sorting, layout rules and state transitions | UI, hardware calls, preferences, timers, async work and resource lookup |
| DuoBarKit | Reused glyph rendering, animation geometry, cards, rows and device-list presentation | Core models, feature services, App preferences and App localization |
| App | Native windows, system collection/control, feature screens, localization, preferences and adapters | Copies of the package rules or reusable renderers |

Core-to-Kit conversion lives in the App. Kit's display inputs describe what to draw; Core's values describe the captured system and rule outcomes. Feature views remain App-owned even when they compose several Kit components.

## Feature map

| App module | Responsibilities |
| --- | --- |
| MenuBar | Status item, popover host, hover summary and glyph composition |
| Battery | Battery collection and battery detail presentation |
| OuterRing | Adaptive monitor, performance sampling, brightness reading and laptop mode runtime |
| Network | Connection state, SSID authorization, Wi-Fi power and network selection |
| Audio | Default input/output control, output and input volume, Bluetooth state and feedback sound |
| Popover | Feature module composition and module presentation adapters |
| SystemTools | Keep-awake control and startup-volume capacity |
| Settings | Settings pages, login registration and persisted preferences |
| System | Aggregated status store, temporary-event scheduling and device context |
| Debug | Existing simulations, diagnostics, visual lab and marketing capture support |

Within a module, `Services` identifies system access and runtime ownership; `Presentation` identifies App-to-view mapping; feature views stay beside their module. Core and Kit use responsibility folders rather than one global collection of unrelated models or views.

## Migration constraints

The migration preserves existing UI geometry, transitions, metric selection, module order, localization keys, preference raw values and system-control behavior. No feature, SDK, minimum OS or Swift language-mode upgrade is part of this change.

Existing pure regression tests move with their rules into Core. Render tests that combine system fixtures and Kit views remain App integration tests. Service and hardware tests remain App-owned. Routine tests never enable the explicit hardware-changing opt-in.

Run the verification commands in root `ProjectContext.md`. The architecture checker guards these package and ownership boundaries; package compilation and App integration tests verify cross-module APIs.
