# Handoff — Liquid Glass ("solarium") port

State of the work at the point this branch was handed to another agent.
Branch: `solarium` (based on `main` at `672587c`).

## Goal

Port the Android Lighty app (Kotlin/Compose, ELK-BLEDOM BLE strip) to a SwiftUI
rewrite, and explore how close iOS 16 can get to the iOS 26 Liquid Glass look.
The target device is an iPhone on iOS 16, so the real `glassEffect` API is
unavailable and the work is about imitating it.

## Where the build happens

No local Xcode. Everything compiles on GitHub Actions `macos-15` with a
physical-device Release build (`xcodebuild ... -sdk iphoneos`, signing off), then
ad-hoc signs and packages an IPA artifact.

`glassEffect` is declared in the iOS 26 SDK, so both workflows now select an
Xcode with an iOS 26 SDK explicitly and fail with a clear message otherwise.
The deployment target is still 16.0.

## Layout of the added code

| Path | Purpose |
| --- | --- |
| `Lighty/Theme/` | Design tokens, background wash, glass cards, header, scaffold |
| `Lighty/Theme/Glass/` | Private-API glass: shim, Swift wrapper, mesh geometry |
| `Lighty/Screens/SolariumLabScreen.swift` | On-device lab with sliders for the mesh |
| `LightyTests/GlassMeshGeometryTests.swift` | Pure-geometry tests, no device needed |
| `Scripts/export_codex_session.py` | Turns a Codex rollout into a Markdown transcript |

## What works

- The solarium theme itself: glass cards, ambient wash, headers, all four
  screens rewritten from `List` to a plain scroll of cards.
- iOS 26 path uses the real `glassEffect(_:in:)`.
- iOS 16-25 path falls back to `.ultraThinMaterial` plus a highlight.
- The private-API path builds a `CABackdropLayer`, applies `gaussianBlur` and a
  saturation `colorMatrix`, and attaches a `CAMeshTransform` for rim refraction.

## Known unknowns (the actual reason for the lab screen)

None of this can be verified from CI: the simulator does not render backdrops
the way a device does, and the CI machine cannot run the app at all.

1. Whether `CABackdropLayer` samples its backdrop on iOS 16 at all. Telegram's
   implementation suggests yes, but their code is GPL-3 and was not copied.
2. Whether `meshTransform` is honoured by `CABackdropLayer` on iOS 16, or only
   on 17+ where Telegram gates it.
3. Whether the mesh direction is visually correct (inward bend, not outward).

`SolariumLabScreen` answers all three on the device: it reports which private
classes resolved, and the sliders change the live mesh.

## Private API caveat

`CABackdropLayer`, `CAMeshTransform`, `CAFilter` and the `filters` layer key are
all private. That is acceptable only because this build is sideloaded, not
submitted to the App Store. Availability is resolved at runtime, so a missing
symbol degrades to the material fallback instead of crashing on launch.

## Next steps

1. Build the branch and install the IPA on the iOS 16 device.
2. Open Settings → Solarium Lab and record which capability rows are green.
3. Tune corner radius, edge band and displacement until the rim looks right.
4. Screenshot the lab with a fixed set of values and commit those as the
   defaults in `BackdropGlassView`.
5. Only then replace `GlassSurface`'s fallback branch with `BackdropGlassView`.

If the capability rows are red, the private path is unavailable on that device
and the fallback material stays; that is a supported outcome, not a failure.

## Working agreements

- Reply in Russian.
- Device build only; do not add simulator runs to the push workflow.
- Never reintroduce a global-coordinate guard into the color picker: it broke
  direct dragging once already.
- Do not commit to `main` from `solarium`.