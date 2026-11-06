import Foundation

/// Persistence for the single bound strip.
///
/// Extracted from `LightyController` so the "pair once, remember forever"
/// behaviour can be unit tested without CoreBluetooth. Mirrors the Android
/// `SharedPreferences` keys `bound_address` / `bound_name`.
struct BoundDeviceStore {

    private enum Keys {
        static let id = "lighty.bound.id"
        static let name = "lighty.bound.name"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: BoundDevice? {
        guard let raw = defaults.string(forKey: Keys.id), let id = UUID(uuidString: raw) else {
            return nil
        }
        return BoundDevice(id: id, name: defaults.string(forKey: Keys.name))
    }

    func save(_ device: BoundDevice) {
        defaults.set(device.id.uuidString, forKey: Keys.id)
        defaults.set(device.name, forKey: Keys.name)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.id)
        defaults.removeObject(forKey: Keys.name)
    }
}
