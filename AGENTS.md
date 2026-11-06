# iOS porting and build guide for coding agents

This guide is for an AI coding agent that must port an existing application to
iOS from Windows/Linux, with builds performed on GitHub Actions macOS runners.
It is based on a working Packet Tunnel proof of concept built in this
repository, but the general build guidance applies to ordinary iOS apps too.

## 1. Decide the deployment and installation model first

Do not begin with UI work. Establish how the resulting app will be installed,
because code signing, capabilities, and test devices determine the project
shape.

| Model | What it is suitable for | Important restriction |
| --- | --- | --- |
| App Store / normal paid Apple Developer account | Normal iOS distribution and restricted capabilities | Requires Apple-issued provisioning profiles and signing. |
| Free Apple ID / seven-day development certificate | Simple personal test apps | Do not assume restricted capabilities, especially VPN Network Extension, will work. |
| Jailbreak-only installation | Device-specific experiments and non-stock workflows | Results apply only to the tested jailbreak, iOS version, installer, and device. |


## 2. Always create a narrow native proof of concept

Before porting Flutter/React Native UI, third-party code, a VPN engine, or a
desktop service, make the smallest native iOS application that tests the
platform feature at risk.




### Network Extension API details that often break builds

`NETunnelProviderManager.connection` has the static type `NEVPNConnection`.
`sendProviderMessage` exists on `NETunnelProviderSession`, not on the base
class, and it throws on modern SDKs:

```swift
guard let session = manager.connection as? NETunnelProviderSession else {
    return
}

do {
    try session.sendProviderMessage(Data("status".utf8)) { reply in
        // Read reply from PacketTunnelProvider.handleAppMessage.
    }
} catch {
    // Record the complete NSError domain, code, and userInfo.
}
```

Log every `NEVPNStatusDidChange` transition. `startVPNTunnel()` returning
without an exception only means the launch request was accepted; it does not by
itself prove `PacketTunnelProvider.startTunnel` executed.

## 3. Project generation without a local Mac

When the project is small and there is no Xcode locally, use **XcodeGen** and
commit `project.yml`, source files, plist files, entitlements, and workflows.
The macOS CI runner generates the `.xcodeproj`:

```bash
brew install xcodegen
xcodegen generate --spec project.yml
```

Keep the generated `*.xcodeproj` out of version control unless the repository
already maintains Xcode project files manually.

For a host target embedding an extension, declare a target dependency and
embed it. With XcodeGen that is conceptually:

```yaml
dependencies:
  - target: PacketTunnel
    embed: true
    codeSign: false
```

Verify after build that:

```text
Host.app/PlugIns/PacketTunnel.appex
```

exists and that the extension Info.plist has the expected extension point.

## 4. GitHub Actions build baseline

Use a macOS runner and force a physical-device build:

```yaml
runs-on: macos-15
```

```bash
xcodebuild \
  -project Example.xcodeproj \
  -scheme Example \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee xcodebuild.log
```

Always upload `xcodebuild.log` with `if: always()`. The final `exit code 65`
line is not actionable; the first preceding `error:` is.

### Ad-hoc signing for jailbreak-only tests

Without an Apple provisioning profile, build with signing disabled, then
ad-hoc sign the nested extension **before** signing the host app:

```bash
APP='build/DerivedData/Build/Products/Release-iphoneos/Example.app'
EXTENSION="$APP/PlugIns/PacketTunnel.appex"

codesign --force --sign - --entitlements PacketTunnel/PacketTunnel.entitlements "$EXTENSION"
codesign --force --sign - --entitlements Host/Example.entitlements "$APP"
```

Then package a standard IPA:

```bash
mkdir -p build/Payload
cp -R "$APP" build/Payload/
ditto -c -k --sequesterRsrc --keepParent build/Payload Example.ipa
```

An entitlement XML file does not grant a protected Apple capability on stock
iOS. Whether a jailbreak installer preserves/re-signs it is an on-device
experiment, not something CI can prove.

### Inspect code-signature entitlements robustly

`codesign -d --entitlements :-` prints a leading `Executable=...` diagnostic
line along with the XML. Do not pipe its entire mixed output directly into
`plutil`; extract the XML first:

```bash
extract_entitlements() {
  codesign -d --entitlements :- "$1" 2>&1 | sed -n '/<?xml/,/<\/plist>/p'
}

extract_entitlements "$APP" > host-entitlements.plist
extract_entitlements "$EXTENSION" > extension-entitlements.plist
```

Upload those files as an artifact. Treat an entitlement inspection mismatch as
diagnostic for a jailbreak POC unless the task explicitly requires CI to fail.
Never let a nonessential `grep` prevent downloading an otherwise usable test
IPA.

## 5. Porting an existing cross-platform app

Inventory every platform-specific dependency before editing shared UI:

1. List native code, MethodChannels, FFI, subprocess launching, background
   services, widgets, notifications, filesystem locations, and system-proxy
   code.
2. List required capabilities and whether each is public on iOS.
3. Separate portable UI/business logic from the privileged transport layer.
4. Build a POC for each privileged layer before merging it into the main app.


## 6. Go / gomobile integration for iOS

Treat these as two separate proofs:

1. compile the Go package to an Apple framework;
2. link the framework into the `.appex` and call one harmless exported method.

Do not begin packet forwarding until both work.

### Installing gomobile in CI

`go tool` only runs tools declared by the module's `tool` directives. A module
may list `gobind` but not `gomobile`; in that case this fails:

```bash
go tool golang.org/x/mobile/cmd/gomobile  # Do not assume this works.
```

Install it explicitly and add Go's binary directory to `PATH`:

```bash
go install golang.org/x/mobile/cmd/gomobile
export PATH="$(go env GOPATH)/bin:$PATH"
gomobile init
```

The informational `gomobile version unknown ... not a git repository` output
can occur for a module-cache installation. It is not the build failure by
itself.

### Current gomobile output convention

Current `gomobile bind -target=ios` expects an output name ending in
`.xcframework` for a static framework. This is invalid:

```bash
gomobile bind -target=ios -o build/ArmanCore.framework ./mobile
```

Use:

```bash
gomobile bind -target=ios -o build/ArmanCore.xcframework ./mobile
```

The error is explicit:

```text
static framework name ".../ArmanCore.framework" missing .xcframework suffix
```

Upload the entire `.xcframework` directory as a CI artifact. After the compile
POC is green, add it to the Packet Tunnel target's framework search paths and
embedded/binary dependencies. Verify the resulting `.appex` references it and
test an exported trivial Go call before starting the real daemon.

### Go portability checks

Before attempting iOS runtime integration, scan the Go package and all
transitive dependencies for:

- `//go:build android`, Linux, Windows, or Darwin-specific files;
- CGO and unsupported system headers;
- Android filesystem paths / certificate-store assumptions;
- process creation, signals, raw TUN file descriptors, and netlink;
- writes to a path unavailable to the extension sandbox.

Use build tags to isolate platform-specific helpers. Do not casually change a
working Android path to make iOS compile; preserve behavior and add explicit
iOS implementations/no-ops where correct.

## 7. Debugging discipline

For every CI failure:

1. Find the first concrete compiler/linker/tool error, not the final summary.
2. Fix only the indicated failure.
3. Keep full logs as artifacts.
4. Commit and push one focused change.
5. Only then move to the next layer.

For an on-device Packet Tunnel failure, collect both in-app diagnostics and
system logs where SSH is available:


Record the device model, exact iOS version, jailbreak state, installer, and
the IPA signing method alongside the result. These details are part of the
test environment, not incidental metadata.

## 8. Recommended order of implementation

1. Confirm installation/signing model.
2. Build a native capability POC.
3. Prove the POC on the target physical device.
4. Compile native dependencies for iOS.
5. Link one native dependency into the extension and execute a harmless call.
6. Prove persistent data and IPC boundaries..
8. Integrate shared UI and hide/rework unsupported platform features.

Do not skip steps 2–5. They isolate entitlement, signing, framework, and
runtime problems before they are obscured by the full application.