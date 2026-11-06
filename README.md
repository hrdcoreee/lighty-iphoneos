# lighty-iphoneos

Port of the Lighty Android app to iOS: control an ELK-BLEDOM LED strip
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
| `LightyTests/` | Hardware-independent unit tests |
| `Scripts/pick_simulator.py` | Resolves the simulator destination at CI time |
| `.github/workflows/ios.yml` | macOS CI: generate, test, build, sign, package |

## Porting notes

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
