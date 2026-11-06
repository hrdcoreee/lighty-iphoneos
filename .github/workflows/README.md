# iOS CI

`ios.yml` is the only workflow. It runs on `macos-15` and performs:

1. `xcodegen generate` from `project.yml` (no `.xcodeproj` in version control).
2. Unit tests on an iOS Simulator. These cover the hardware-independent logic:
   ELK frame bytes, HSV -> RGB conversion, scan-name filtering and version
   comparison.
3. A physical-device `Release` build against the `iphoneos` SDK with code
   signing disabled, which is what validates the `bluetooth-central` background
   mode and the arm64 compile.
4. Ad-hoc signing plus code-signature entitlement extraction. `codesign -d`
   emits a leading `Executable=...` line, so the XML is extracted with `sed`
   before `plutil` sees it.
5. IPA packaging (`Payload/` + `ditto`) for sideload/jailbreak testing.

Artifacts are uploaded with `if: always()`: `xcodebuild.log`,
`xcodebuild-test.log`, the extracted entitlements and the IPA. Read the first
`error:` line in the log, not the trailing `exit code 65`.

## What CI cannot prove

Signing and entitlements for a stock device need a real provisioning profile.
Whether a jailbreak installer preserves or re-signs an entitlement is an
on-device experiment. The BLE behaviour itself (CoreBluetooth scan, GATT writes,
whether the strip actually reacts) also requires a physical device running the
newly built IPA.
