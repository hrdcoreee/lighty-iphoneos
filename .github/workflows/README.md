# iOS CI

Two workflows, both on `macos-15`:

- `ios.yml` - the build. Runs on push to `main`, on pull requests and on demand.
  This is the workflow that gates a change.
- `tests.yml` - the unit tests on an iOS Simulator. **Manual only**
  (`workflow_dispatch`), because the simulator is not on the critical path for
  the proof of concept.

## Build (`ios.yml`)

1. `xcodegen generate` from `project.yml` (no `.xcodeproj` in version control).
2. A physical-device `Release` build against the `iphoneos` SDK with code
   signing disabled, which validates the arm64 compile and bakes in the
   `bluetooth-central` background mode. No Simulator, no destination.
3. Ad-hoc signing plus code-signature entitlement extraction. `codesign -d`
   emits a leading `Executable=...` line, so the XML is extracted with `sed`
   before `plutil` sees it.
4. IPA packaging (`Payload/` + `ditto`) for sideload/jailbreak testing.

Artifacts are uploaded with `if: always()`: `xcodebuild.log`, the extracted
entitlements and the IPA. Read the first `error:` line in the log, not the
trailing `exit code 65`.

## Tests (`tests.yml`)

Resolves a Simulator UDID through `Scripts/pick_simulator.py` (a hardcoded
`name=iPhone 16` breaks as soon as a runner image drops that device) and runs
`xcodebuild test`. `Scripts/test_pick_simulator.py` unit tests the resolver
itself with no macOS required.

## What CI cannot prove

Signing and entitlements for a stock device need a real provisioning profile.
Whether a jailbreak installer preserves or re-signs an entitlement is an
on-device experiment. The BLE behaviour itself (CoreBluetooth scan, GATT writes,
whether the strip actually reacts) also requires a physical device running the
newly built IPA - a Simulator has no Bluetooth radio.
