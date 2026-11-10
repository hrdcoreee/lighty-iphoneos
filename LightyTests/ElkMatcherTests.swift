import XCTest
@testable import Lighty

/// Ported expectations for the scan filtering rules in the Android `BleController`.
final class ElkMatcherTests: XCTestCase {

    func testGeniuneElkNamesMatch() {
        XCTAssertTrue(ElkMatcher.isElkLike(name: "ELK-BLEDOM", advertisedServiceUUIDs: []))
        XCTAssertTrue(ElkMatcher.isElkLike(name: "elk_bledom", advertisedServiceUUIDs: []))
        XCTAssertTrue(ElkMatcher.isElkLike(name: "BLEDOM", advertisedServiceUUIDs: []))
        XCTAssertTrue(ElkMatcher.isElkLike(name: "MELK-BLEDOM", advertisedServiceUUIDs: []))
        XCTAssertTrue(ElkMatcher.isElkLike(name: "ELK-BULB", advertisedServiceUUIDs: []))
    }

    func testUnrelatedNamesDoNotMatch() {
        XCTAssertFalse(ElkMatcher.isElkLike(name: "AirPods Pro", advertisedServiceUUIDs: []))
        XCTAssertFalse(ElkMatcher.isElkLike(name: nil, advertisedServiceUUIDs: []))
        XCTAssertFalse(ElkMatcher.isElkLike(name: "", advertisedServiceUUIDs: []))
    }

    func testBlacklistedNamesAreIgnored() {
        XCTAssertFalse(ElkMatcher.isElkLike(name: "LEDnet1234", advertisedServiceUUIDs: []))
        XCTAssertFalse(ElkMatcher.isElkLike(name: "MagicHome-ABCD", advertisedServiceUUIDs: []))
        XCTAssertFalse(ElkMatcher.isElkLike(name: "ZJ-BLE", advertisedServiceUUIDs: []))
        XCTAssertTrue(ElkMatcher.isIgnored(name: "LEDnet1234"))
        XCTAssertTrue(ElkMatcher.isIgnored(name: "magichome"))
    }

    func testBlacklistWinsOverNameMatch() {
        // A name that would otherwise look like ELK must still be filtered out.
        XCTAssertFalse(ElkMatcher.isElkLike(name: "LEDnet-BLEDOM", advertisedServiceUUIDs: []))
    }

    func testAdvertisedServiceMatchesRegardlessOfName() {
        XCTAssertTrue(
            ElkMatcher.isElkLike(name: nil, advertisedServiceUUIDs: [ElkProtocol.serviceUUID])
        )
        XCTAssertTrue(
            ElkMatcher.isElkLike(name: nil, advertisedServiceUUIDs: ["FFF0"])
        )
        XCTAssertTrue(
            ElkMatcher.isElkLike(name: "Weird Name", advertisedServiceUUIDs: ["0000FFF0-0000-1000-8000-00805F9B34FB"])
        )
        XCTAssertTrue(
            ElkMatcher.isElkLike(name: "Weird Name", advertisedServiceUUIDs: ["fff0"])
        )
    }
}
