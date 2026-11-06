import XCTest
@testable import Lighty

final class VersionCompareTests: XCTestCase {

    func testEqualVersions() {
        XCTAssertEqual(compareVersions("1.2", "1.2.0"), 0)
        XCTAssertEqual(compareVersions("v2.0", "2.0"), 0)
        XCTAssertEqual(compareVersions("1.0.0", "v1.0.0"), 0)
    }

    func testNewerVersions() {
        XCTAssertGreaterThan(compareVersions("2.0", "1.9.9"), 0)
        XCTAssertGreaterThan(compareVersions("1.10", "1.9"), 0)
        XCTAssertGreaterThan(compareVersions("1.0.1", "1.0"), 0)
    }

    func testOlderVersions() {
        XCTAssertLessThan(compareVersions("1.0", "1.0.1"), 0)
        XCTAssertLessThan(compareVersions("v0.9", "1.0"), 0)
    }

    func testNonNumericVersionPartsAreIgnored() {
        XCTAssertEqual(compareVersions("v1.2.3-beta", "1.2.3"), 0)
        XCTAssertGreaterThan(compareVersions("1.2.4+build7", "1.2.3"), 0)
    }
}
