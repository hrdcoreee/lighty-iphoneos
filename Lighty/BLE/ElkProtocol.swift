import Foundation

/// ELK-BLEDOM control protocol (verified in practice on the Android port).
///
/// Service:        0000fff0-0000-1000-8000-00805f9b34fb
/// Write char:     0000fff3-0000-1000-8000-00805f9b34fb
///
/// Every command is a fixed 9-byte frame: `0x7E ... 0xEF`.
/// Byte 1 is always `0x07`, byte 2 selects the command type.
///
/// Pure logic with no CoreBluetooth dependency, so the frame encoding can be
/// unit tested on a CI simulator without a physical strip.
enum ElkProtocol {

    static let serviceUUID = "0000FFF0-0000-1000-8000-00805F9B34FB"
    static let writeCharacteristicUUID = "0000FFF3-0000-1000-8000-00805F9B34FB"

    /// Turn the strip on. Also forces the controller into static-color mode.
    static let powerOn: [UInt8] = [0x7E, 0x07, 0x04, 0xFF, 0x00, 0x01, 0x02, 0x01, 0xEF]

    /// Turn the strip off.
    static let powerOff: [UInt8] = [0x7E, 0x07, 0x04, 0x00, 0x00, 0x00, 0x02, 0x01, 0xEF]

    /// Static color command: `7E 07 05 03 RR GG BB 00 EF`.
    ///
    /// Sending a color also switches the strip into manual mode and lights it up.
    static func color(red: Int, green: Int, blue: Int) -> [UInt8] {
        [
            0x7E, 0x07, 0x05, 0x03,
            UInt8(truncatingIfNeeded: red),
            UInt8(truncatingIfNeeded: green),
            UInt8(truncatingIfNeeded: blue),
            0x00, 0xEF,
        ]
    }

    /// Every frame must be exactly nine bytes and bracketed by `0x7E`/`0xEF`.
    static func isValidFrame(_ frame: [UInt8]) -> Bool {
        frame.count == 9 && frame.first == 0x7E && frame.last == 0xEF
    }

    /// Hex rendering used by the diagnostics log.
    static func hexString(_ frame: [UInt8]) -> String {
        frame.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Color conversion

/// Minimal HSB/HSV helper mirroring `android.graphics.Color.HSVToColor`.
struct HSVColor: Equatable {
    /// Hue in degrees, normalised to `0..<360`.
    var hue: Double
    /// Saturation, `0...1`.
    var saturation: Double
    /// Brightness/value, `0...1`.
    var brightness: Double

    static let white = HSVColor(hue: 0, saturation: 0, brightness: 1)

    /// 8-bit RGB components, rounded the same way the Android app rounds.
    var rgb: (r: Int, g: Int, b: Int) {
        guard hue.isFinite, saturation.isFinite, brightness.isFinite else {
            return (0, 0, 0)
        }
        let normalisedHue = (hue.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let h = normalisedHue / 60
        let s = min(max(saturation, 0), 1)
        let v = min(max(brightness, 0), 1)

        let sector = Int(floor(h)) % 6
        let f = h - floor(h)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))

        let (rf, gf, bf): (Double, Double, Double)
        switch sector {
        case 0: (rf, gf, bf) = (v, t, p)
        case 1: (rf, gf, bf) = (q, v, p)
        case 2: (rf, gf, bf) = (p, v, t)
        case 3: (rf, gf, bf) = (p, q, v)
        case 4: (rf, gf, bf) = (t, p, v)
        default: (rf, gf, bf) = (v, p, q)
        }

        return (
            r: Int((rf * 255).rounded()),
            g: Int((gf * 255).rounded()),
            b: Int((bf * 255).rounded())
        )
    }

    /// The 9-byte ELK frame for the current color.
    var elkFrame: [UInt8] {
        let components = rgb
        return ElkProtocol.color(red: components.r, green: components.g, blue: components.b)
    }
}
