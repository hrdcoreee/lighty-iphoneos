import XCTest
@testable import Lighty

/// A swipe-to-home must never reach a control, so the geometry that defines
/// "this touch belongs to the system" is pinned down by tests.
final class HomeStripGeometryTests: XCTestCase {

    func testExclusionHeightIsTheReportedInset() {
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: 34), 34)
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: 21), 21)
    }

    /// A device with a physical home button reports zero: there is no home
    /// indicator, so nothing at the bottom may be blocked.
    func testZeroInsetExcludesNothing() {
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: 0), 0)
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 666, screenHeight: 667, bottomInset: 0))
    }

    func testTouchInsideTheStripIsRejected() {
        // 844 pt screen, 34 pt inset -> the strip starts at 810.
        XCTAssertTrue(HomeStripGeometry.contains(globalY: 810, screenHeight: 844, bottomInset: 34))
        XCTAssertTrue(HomeStripGeometry.contains(globalY: 843, screenHeight: 844, bottomInset: 34))
    }

    func testTouchAboveTheStripIsAccepted() {
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 809, screenHeight: 844, bottomInset: 34))
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 0, screenHeight: 844, bottomInset: 34))
    }

    /// Without a measured screen (early in launch) nothing may be excluded,
    /// otherwise the picker could stop responding entirely.
    func testUnknownScreenHeightExcludesNothing() {
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 800, screenHeight: 0, bottomInset: 34))
    }

    func testNonFiniteInputsAreIgnored() {
        XCTAssertFalse(
            HomeStripGeometry.contains(globalY: .nan, screenHeight: 844, bottomInset: 34)
        )
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: .nan), 0)
    }
}
