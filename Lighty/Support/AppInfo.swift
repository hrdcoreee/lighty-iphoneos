import Foundation

/// Bundle metadata used by the settings screen.
enum AppInfo {
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?) where !build.isEmpty && build != short:
            return "\(short) (\(build))"
        case let (short?, _):
            return short
        default:
            return "-"
        }
    }
}
