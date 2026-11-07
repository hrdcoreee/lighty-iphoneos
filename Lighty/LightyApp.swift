import SwiftUI

@main
struct LightyApp: App {
    @StateObject private var controller = LightyController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
            // The window does not exist during the first `onAppear`, so the
            // strip shield is installed from the key-window notification and
            // refreshed whenever the scene becomes active again.
            .background(WindowShieldInstaller())
                .onAppear { controller.setForeground(true) }
        }
        .onChange(of: scenePhase) { phase in
            controller.setForeground(phase == .active)
            if phase == .active { HomeStripWindowShield.refreshFrame() }
        }
    }
}

/// Zero-size view whose only job is to install the strip shield once a window
/// is attached, and to re-install it if the window is recreated.
private struct WindowShieldInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { HomeStripWindowShield.install() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { HomeStripWindowShield.install() }
    }
}
