import SwiftUI

/// Root flow, mirroring the Android navigation: the pairing screen is the only
/// entry point until a strip is bound, and a bound strip is remembered forever
/// so every later launch lands straight on the control screen. There is no tab
/// bar; settings is an overlay available from both screens.
struct RootView: View {
    @EnvironmentObject private var controller: LightyController

    @State private var showSettings = false

    private let strings = Locale.lightyStrings

    var body: some View {
        screens
            .sheet(isPresented: $showSettings) {
                // Passed explicitly rather than relying on environment inheritance.
                SettingsSheet(strings: strings)
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
