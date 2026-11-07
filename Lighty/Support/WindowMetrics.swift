import UIKit

/// Access to the key window, used where SwiftUI cannot reach it (a shield
/// installed directly into the window hierarchy).
@MainActor
enum WindowMetrics {

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
