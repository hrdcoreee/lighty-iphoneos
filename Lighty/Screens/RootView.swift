import SwiftUI

/// Root tab bar. The control tab is shown only once a device has been bound,
/// mirroring the Android navigation flow (scan first, then control).
struct RootView: View {
    @EnvironmentObject private var controller: LightyController

    private let strings = Locale.lightyStrings

    var body: some View {
        TabView {
            NavigationStack {
                ScanScreen(strings: strings)
            }
            .tabItem {
                Label(strings.scan, systemImage: "dot.radiowaves.left.and.right")
            }

            if controller.boundDevice != nil {
                NavigationStack {
                    ControlScreen(strings: strings)
                }
                .tabItem {
                    Label(strings.controlTitle, systemImage: "slider.horizontal.3")
                }
            }

            NavigationStack {
                DiagnosticsScreen(strings: strings)
            }
            .tabItem {
                Label(strings.diagnosticsTitle, systemImage: "waveform.path.ecg")
            }
        }
    }
}
