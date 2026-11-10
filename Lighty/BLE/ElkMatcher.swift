import Foundation

/// Name/service heuristics deciding whether a discovered peripheral is worth
/// showing. Ported from the Android `BleController` scanning filters.
enum ElkMatcher {

    /// Genuine ELK-BLEDOM controllers and close clones advertise these names.
    private static let elkNamePattern = "^ELK[-_\\s]?BLEDOM|^BLEDOM|^ELK[-_\\s]?BLE|^MELK[-_\\s]?BLEDOM|^MELK|^ELK[-_\\s]?(BULB|LAMP)"

    /// Incompatible controllers (Magic Home / Zengge LEDnet) we always hide.
    private static let ignoredNamePattern = "^LEDnet|LED_net|MagicHome|ZJ-BLE"

    static func isIgnored(name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return name.range(of: ignoredNamePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// True when the name or the advertised service list suggests an ELK controller.
    static func isElkLike(name: String?, advertisedServiceUUIDs: [String]) -> Bool {
        if isIgnored(name: name) { return false }

        let serviceMatch = advertisedServiceUUIDs.contains {
            $0.caseInsensitiveCompare(ElkProtocol.serviceUUID) == .orderedSame
                || $0.caseInsensitiveCompare("FFF0") == .orderedSame
                || $0.uppercased().hasPrefix("0000FFF0")
                || $0.uppercased().hasPrefix("FFF0")
        }

        let nameMatch: Bool
        if let name, !name.isEmpty {
            nameMatch = name.range(of: elkNamePattern, options: [.regularExpression, .caseInsensitive]) != nil
        } else {
            nameMatch = false
        }

        return serviceMatch || nameMatch
    }
}
