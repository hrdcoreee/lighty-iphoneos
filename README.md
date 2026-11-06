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
| `Lighty/Components/TouchShield.swift` | Touch-dead strip over the home-indicator area |
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

The home-indicator strip is covered by a transparent `TouchShield`, so a swipe
home is never read as a tap on the content underneath. On the control screen
the picker sits at the bottom of the scroll view, and that stray touch used to
recolor the strip mid-swipe. The shield claims hit testing only and carries no
gesture recognisers, so the system gesture is unaffected.

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
