import SwiftUI

/// Root flow, mirroring the Android navigation: the pairing screen is the only
/// entry point until a strip is bound, and a bound strip is remembered forever
/// so every later launch lands straight on the control screen.
///
/// The whole flow is drawn on one ambient background, so the crossfade between
/// screens does not flash a different color and the glass cards keep something
/// stable to refract.
struct RootView: View {
    @EnvironmentObject private var controller: LightyController

    @State private var showSettings = false

    private let strings = Locale.lightyStrings

    var body: some View {
        ZStack {
            SolariumBackground()

            screens
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsSheet(strings: strings)
            }
            // Sheets get their own window and do not inherit the environment.
            .environmentObject(controller)
        }
    }

    @ViewBuilder
    private var screens: some View {
        Group {
            if controller.boundDevice == nil {
                NavigationStack {
                    ScanScreen(strings: strings, onOpenSettings: { showSettings = true })
                }
                .transition(.opacity)
            } else {
                NavigationStack {
                    ControlScreen(strings: strings, onOpenSettings: { showSettings = true })
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: controller.boundDevice)
    }
}
