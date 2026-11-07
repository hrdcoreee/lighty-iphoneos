# lighty-iphoneos

Reconstruction of the Lighty Android app to iOS: control an ELK-BLEDOM LED strip
controller over Bluetooth LE.

This repository currently contains the **native proof of concept** required
before any UI porting work: a SwiftUI application that scans for controllers,
connects over CoreBluetooth, and writes the same 9-byte ELK-BLEDOM frames the
Android app uses.

## Layout

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec; the `.xcodeproj` is generated in CI |
| `Config/Info.plist` | Bundle metadata, `bluetooth-central` background mode, usage strings |
| `Config/Lighty.entitlements` | Entitlements passed to ad-hoc signing |
| `Lighty/BLE/ElkProtocol.swift` | Frame encoding + HSV -> RGB, pure logic |
| `Lighty/BLE/BleCentral.swift` | CoreBluetooth scan/GATT/write queue |
| `Lighty/BLE/LightyController.swift` | Bound device, reconnect, persisted state |
| `Lighty/Screens/` | Scan, control and diagnostics screens |
| `Lighty/Support/HomeStripWindowShield.swift` | Window-level shield over the home-indicator strip |
| `Lighty/Theme/` | Solarium look: Liquid Glass surfaces, wash, cards |
| `LightyTests/` | Hardware-independent unit tests |
| `Scripts/pick_simulator.py` | Resolves the simulator destination at CI time |
| `.github/workflows/ios.yml` | macOS CI: build for device, sign, package the IPA |
| `.github/workflows/tests.yml` | Manual-only macOS CI: unit tests on a simulator |

## CI

`.github/workflows/ios.yml` runs on push to `main` and on pull requests. It
generates the project with XcodeGen, builds `Release` for `iphoneos` with code
signing disabled, ad-hoc signs the `.app`, and uploads `Lighty.ipa` plus
`xcodebuild.log` as artifacts. Read the first `error:` line in the log, not the
trailing `exit code 65`.

`.github/workflows/tests.yml` holds the unit tests. It is `workflow_dispatch`
only: the Simulator is not on the critical path for the proof of concept.

macOS runners are subject to capacity constraints, so a run may sit in the
queue for a while before it starts; a `cancelled` job with the annotation "was
not acquired by Runner of type hosted" means exactly that, not a code failure.

## UI notes

The app icon reproduces the Android adaptive icon as a flat 1024x1024 PNG:
white background, the bulb tinted `#454545`, the same 0.58 scale inside the
72/108 safe zone as `ic_launcher_foreground.xml`. iOS needs the glyph as a
bitmap, so the vector is rasterised when the asset is produced rather than
bundled as a vector asset.

The home-indicator strip is covered by `HomeStripWindowShield`, a transparent
`UIView` added to the key window. A swipe home starts with a touch in that
strip, and iOS hands that touch to the app before claiming the gesture, so a
control that reacts on touch-down fires first. That is exactly what the color
picker did: the strip changed color on the way home.

A SwiftUI overlay is not enough here, because a `List` installs its own hit
testing and an overlay inside the safe area never covers the strip. The window
shield is sized from the real window bounds, claims only touches inside the
strip and returns `nil` everywhere else, and carries no recognisers - so the
system gesture keeps working. It also steps aside while a sheet is presented,
and does nothing on a device without a home indicator.

The picker itself stays simple on purpose: a guard based on global coordinates
turned out to be unreliable inside a `List` and broke ordinary dragging. It now
reports nothing on touch-down, follows a finger after 6 pt of travel and applies
a stationary press on release, so a home swipe cannot recolor the strip even
without the shield.

## Solarium theme

The `solarium` branch reworks the UI around Liquid Glass.

- `GlassSurface` draws cards with the real `glassEffect(_:in:)` on iOS 26+ and
  falls back to `.ultraThinMaterial` plus a highlight on iOS 16-25. This is a
  simulation, not the system material; the two will not look pixel-identical.
- `SolariumBackground` paints a slow color wash behind everything, which is what
  the glass has to refract. It honors Reduce Motion.
- Cards, not a `List`: row backgrounds and separators fight the material, and
  `List` installs its own hit testing. `SolariumScaffold` is a plain scroll view.
- The LazyVGrid of presets and the picker keep their exact behavior; only the
  container changed.

Because `glassEffect` only exists in the iOS 26 SDK, both workflows select
Xcode 26 explicitly and fail with a clear message if it is missing. The
deployment target is still 16.0.

## Reconstruction notes

The Android app used a hardware MAC address as the device key. iOS never
exposes one, so a bound strip is persisted by the CoreBluetooth
`CBPeripheral.identifier`, which is stable per app installation but not
portable between devices.

## Build locally (macOS)

```bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild -project Lighty.xcodeproj -scheme Lighty \
  -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO build
```

The tests need a Simulator destination:

```bash
xcodebuild test -project Lighty.xcodeproj -scheme Lighty \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
