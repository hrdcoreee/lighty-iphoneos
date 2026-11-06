import XCTest
@testable import Lighty

/// Verifies the ELK-BLEDOM frame encoding against the byte sequences that were
/// validated in practice by the Android app.
final class ElkProtocolTests: XCTestCase {

    func testPowerOnFrame() {
        XCTAssertEqual(
            ElkProtocol.powerOn,
            [0x7E, 0x07, 0x04, 0xFF, 0x00, 0x01, 0x02, 0x01, 0xEF]
        )
    }

    func testPowerOffFrame() {
        XCTAssertEqual(
            ElkProtocol.powerOff,
            [0x7E, 0x07, 0x04, 0x00, 0x00, 0x00, 0x02, 0x01, 0xEF]
        )
    }

    func testColorFrame() {
        XCTAssertEqual(
            ElkProtocol.color(red: 0x12, green: 0x34, blue: 0x56),
            [0x7E, 0x07, 0x05, 0x03, 0x12, 0x34, 0x56, 0x00, 0xEF]
        )
    }

    /// Components outside `0...255` must wrap rather than trap.
    func testColorClampsOutOfRangeComponents() {
        XCTAssertEqual(
            ElkProtocol.color(red: 300, green: -1, blue: 256),
            [0x7E, 0x07, 0x05, 0x03, 0x2C, 0xFF, 0x00, 0x00, 0xEF]
        )
    }

    func testValidityOfEveryGeneratedFrame() {
        XCTAssertTrue(ElkProtocol.isValidFrame(ElkProtocol.powerOn))
        XCTAssertTrue(ElkProtocol.isValidFrame(ElkProtocol.powerOff))
        XCTAssertTrue(ElkProtocol.isValidFrame(ElkProtocol.color(red: 1, green: 2, blue: 3)))
        XCTAssertFalse(ElkProtocol.isValidFrame([0x7E, 0x07, 0xEF]))
        XCTAssertFalse(ElkProtocol.isValidFrame([0x00, 0x07, 0x04, 0xFF, 0x00, 0x01, 0x02, 0x01, 0xEF]))
    }

    func testHexStringFormatting() {
        XCTAssertEqual(ElkProtocol.hexString([0x7E, 0x0A, 0xFF]), "7E 0A FF")
    }
}
