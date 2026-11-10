import XCTest
@testable import Lighty

/// Verifies HSV -> RGB conversion by comparing against values computed with
/// `android.graphics.Color.HSVToColor`, which the Android app uses directly.
final class HSVColorTests: XCTestCase {

    func testPurePrimaries() {
        XCTAssertEqual(HSVColor(hue: 0, saturation: 1, brightness: 1).rgb.r, 255)
        XCTAssertEqual(HSVColor(hue: 0, saturation: 1, brightness: 1).rgb.g, 0)
        XCTAssertEqual(HSVColor(hue: 0, saturation: 1, brightness: 1).rgb.b, 0)

        XCTAssertEqual(HSVColor(hue: 120, saturation: 1, brightness: 1).rgb.r, 0)
        XCTAssertEqual(HSVColor(hue: 120, saturation: 1, brightness: 1).rgb.g, 255)
        XCTAssertEqual(HSVColor(hue: 120, saturation: 1, brightness: 1).rgb.b, 0)

        XCTAssertEqual(HSVColor(hue: 240, saturation: 1, brightness: 1).rgb.r, 0)
        XCTAssertEqual(HSVColor(hue: 240, saturation: 1, brightness: 1).rgb.g, 0)
        XCTAssertEqual(HSVColor(hue: 240, saturation: 1, brightness: 1).rgb.b, 255)
    }

    func testWhiteAndBlack() {
        let white = HSVColor(hue: 0, saturation: 0, brightness: 1).rgb
        XCTAssertEqual(white.r, 255)
        XCTAssertEqual(white.g, 255)
        XCTAssertEqual(white.b, 255)

        let black = HSVColor(hue: 0, saturation: 1, brightness: 0).rgb
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)
    }

    /// Android `Color.HSVToColor(120, 0.5, 0.5)` -> `(64, 128, 64)`.
    func testMidToneGreen() {
        let rgb = HSVColor(hue: 120, saturation: 0.5, brightness: 0.5).rgb
        XCTAssertEqual(rgb.r, 64)
        XCTAssertEqual(rgb.g, 128)
        XCTAssertEqual(rgb.b, 64)
    }

    /// Hue must wrap into `0..<360` rather than producing a negative sector.
    func testHueWrapsAround() {
        XCTAssertEqual(HSVColor(hue: 360, saturation: 1, brightness: 1).rgb.r, 255)
        XCTAssertEqual(HSVColor(hue: -120, saturation: 1, brightness: 1).rgb.b, 255)
    }

    func testOutOfRangeComponentsAreClamped() {
        let rgb = HSVColor(hue: 0, saturation: 5, brightness: 5).rgb
        XCTAssertEqual(rgb.r, 255)
        XCTAssertEqual(rgb.g, 0)
        XCTAssertEqual(rgb.b, 0)
    }

    func testNonFiniteComponentsDoNotTrap() {
        let nanColor = HSVColor(hue: .nan, saturation: 1, brightness: 1).rgb
        XCTAssertEqual(nanColor.r, 0)
        XCTAssertEqual(nanColor.g, 0)
        XCTAssertEqual(nanColor.b, 0)

        let infColor = HSVColor(hue: 120, saturation: .infinity, brightness: 1).rgb
        XCTAssertEqual(infColor.r, 0)
        XCTAssertEqual(infColor.g, 0)
        XCTAssertEqual(infColor.b, 0)
    }

    func testElkFrameFromColor() {
        let frame = HSVColor(hue: 0, saturation: 1, brightness: 1).elkFrame
        XCTAssertEqual(frame, [0x7E, 0x07, 0x05, 0x03, 0xFF, 0x00, 0x00, 0x00, 0xEF])
    }
}
