# DuoBar Agent Instructions

Read root `ProjectContext.md` before planning, setup, implementation, review or investigation. Follow the relevant architecture and verification pointers.

Preserve the accepted product behavior, existing visual geometry, animation timing, localization keys and preference identifiers during structural work. Do not add explanatory source comments.

All direct dependency, package manifest, dependency resolution and project toolchain changes belong to `alex-coding:setup`. Feature implementation uses `alex-coding:implement` and must not hide new foundation dependencies.

Use `./scripts/lint.sh`, `./scripts/acceptance-tests.sh` and `./scripts/build.sh` as the project entry points. Package and App evidence have separate scopes. Hardware-changing validation requires an explicit user request; routine acceptance disables the hardware opt-in.

`DuoBarCore` owns Foundation-only values and pure rules. `DuoBarKit` owns reusable presentation components and their own display inputs, and must not depend on Core. App features own system services, localization, preferences, composition and Core-to-Kit adapters.

Follow the shared workspace Git identity, task-worktree, pull-request and independent review policies. Repository-owned Core and Kit packages may use committed relative paths. External developer-checkout dependencies must not reach the default branch.
