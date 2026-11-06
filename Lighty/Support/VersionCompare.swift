import Foundation

/// Version comparison ported from the Android `UpdateManager`.
///
/// Numeric and component-wise, so `"v1.2"` and `"1.2.0"` compare equal.
/// Returns `> 0` when `lhs` is newer than `rhs`.
func compareVersions(_ lhs: String, _ rhs: String) -> Int {
    func parts(_ value: String) -> [Int] {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "v" || $0 == "V" })
            .split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "+" || $0 == "_" })
            .compactMap { Int($0) }
    }

    let a = parts(lhs)
    let b = parts(rhs)
    for index in 0..<max(a.count, b.count) {
        let diff = (index < a.count ? a[index] : 0) - (index < b.count ? b[index] : 0)
        if diff != 0 { return diff }
    }
    return 0
}
