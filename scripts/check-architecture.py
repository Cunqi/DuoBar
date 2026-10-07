#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
failures = []

for directory in ('DuoBar', 'DuoBarTests', 'DuoBarCore/Sources', 'DuoBarCore/Tests', 'DuoBarKit/Sources'):
    for path in (root / directory).rglob('*.swift'):
        source = path.read_text()
        if source.endswith('\n\n'):
            failures.append(f'{path.relative_to(root)}: extra blank line at end of file')
        for index, line in enumerate(source.splitlines(), 1):
            if line.rstrip() != line:
                failures.append(f'{path.relative_to(root)}:{index}: trailing whitespace')

for path in (root / 'DuoBarCore/Sources/DuoBarCore').rglob('*.swift'):
    source = path.read_text()
    imports = re.findall(r'^\s*(?:@\w+\s+)?import\s+(\w+)', source, re.MULTILINE)
    if set(imports) - {'Foundation'}:
        failures.append(f'{path.relative_to(root)}: Core imports a non-Foundation framework')
    if re.search(r'\b(UserDefaults|FileManager|ProcessInfo|Timer|NSLocalizedString|ObservableObject|Task|PreferenceKeys)\b|@AppStorage|@Published', source):
        failures.append(f'{path.relative_to(root)}: Core contains an application or runtime responsibility')

for path in (root / 'DuoBarKit/Sources/DuoBarKit').rglob('*.swift'):
    source = path.read_text()
    imports = re.findall(r'^\s*(?:@\w+\s+)?import\s+(\w+)', source, re.MULTILINE)
    if set(imports) - {'Foundation', 'SwiftUI', 'AppKit', 'CoreGraphics'}:
        failures.append(f'{path.relative_to(root)}: Kit imports a domain or system-service framework')
    if re.search(r'\b(DuoBarCore|UserDefaults|FileManager|PreferenceKeys|NSLocalizedString)\b|@AppStorage', source):
        failures.append(f'{path.relative_to(root)}: Kit depends on application state or domain models')

for package in ('DuoBarCore', 'DuoBarKit'):
    manifest = root / package / 'Package.swift'
    if not manifest.exists():
        failures.append(f'{package}: package manifest is missing')
        continue
    result = subprocess.run(['swift', 'package', '--package-path', str(manifest.parent), 'dump-package'], capture_output=True, text=True)
    if result.returncode:
        failures.append(f'{package}: {result.stderr.strip()}')
    if package == 'DuoBarKit' and 'DuoBarCore' in manifest.read_text():
        failures.append('DuoBarKit must not depend on DuoBarCore')

for directory in ('Models', 'Services', 'UI', 'MenuBar', 'Utilities'):
    if any((root / 'DuoBar' / directory).rglob('*.swift')):
        failures.append(f'DuoBar/{directory}: source still uses a cross-feature directory')

for failure in failures:
    print(failure, file=sys.stderr)
if failures:
    raise SystemExit(1)
print('Architecture boundaries and package manifests passed.')
