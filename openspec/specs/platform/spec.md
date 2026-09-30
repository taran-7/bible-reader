# platform Specification

## Purpose
Platform, privacy, size, launch speed and accessibility: macOS 14+ on Apple Silicon only, no network, `.app` < 100 MB, launch < 1 s, VoiceOver and keyboard.

Requirements in [docs/requirements.md](../../../docs/requirements.md): NFR-1, NFR-2, NFR-3, NFR-4, NFR-5.

## Requirements

### Requirement: Platform
The app SHALL build for macOS 14 and newer and SHALL contain code for Apple Silicon (`arm64`); an Intel build is not supported (NFR-1).

#### Scenario: Release build
- **WHEN** `node scripts/check-platform.mjs` runs
- **THEN** the built app's `LSMinimumSystemVersion` is `14.0`, and the binary's `lipo -archs` contains `arm64`

### Requirement: No network
The app code SHALL NOT use network APIs (`URLSession`, `URLRequest`, `NSURLConnection`, `Network`, `WKWebView`) or contain `http(s)://` addresses, except the illustrations module files explicitly allowed in the test (NFR-2).

#### Scenario: A network call in code
- **WHEN** `URLSession` appears in a file under `Sources/`
- **THEN** the `NetworkIsolationTests` test fails with the file name and line number

### Requirement: App size
The built Release `.app` SHALL be smaller than 100 MB; from 80 MB the check SHALL print a warning (NFR-5).

#### Scenario: Approaching the limit
- **WHEN** the `.app` weighs 85 MB
- **THEN** `check-platform` prints WARN, but the result is PASS

### Requirement: Fast launch
The app SHALL show the first chapter in less than 1 second from process start on a repeated launch (NFR-3).

#### Scenario: Repeated launch
- **WHEN** the app is launched a second time
- **THEN** < 1000 ms pass from process start to the first frame with verses

### Requirement: Accessibility
VoiceOver SHALL read the number and text of every verse, and toolbar buttons SHALL have text names. Reading, search, copying, bookmarks, moving between chapters and translations SHALL be available from the keyboard alone (NFR-4).

#### Scenario: Verse label
- **WHEN** VoiceOver focuses the first verse of Genesis 1
- **THEN** the label starts with "1 In the beginning God created"

#### Scenario: No mouse
- **WHEN** the user presses ⌘F, types `John 3:16`, Return, ↓, ⌘C, ⌘D, ⌘], ⌘[, ⌘⌥3
- **THEN** John 3 opens, the John 3:17 quote is copied, a chapter bookmark appears, John 4 and then John 3 open again, and then «Від Івана 3» in Ohienko
