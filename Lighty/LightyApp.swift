import SwiftUI

@main
struct LightyApp: App {
    @StateObject private var controller = LightyController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .onAppear { controller.setForeground(true) }
        }
        .onChange(of: scenePhase) { phase in
            controller.setForeground(phase == .active)
        }
    }
}
