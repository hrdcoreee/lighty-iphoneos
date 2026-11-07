import XCTest
@testable import Lighty

/// A swipe-to-home must never reach a control, so the geometry that defines
/// "this touch belongs to the system" is pinned down by tests.
final class HomeStripGeometryTests: XCTestCase {

    func testExclusionHeightPrefersTheReportedInset() {
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: 34), 34)
        XCTAssertEqual(HomeStripGeometry.exclusionHeight(bottomInset: 21), 21)
    }

    /// A device with a physical home button reports zero; the bottommost points
    /// still belong to the system's edge-swipe area.
    func testZeroInsetStillReservesTheMinimumStrip() {
        XCTAssertEqual(
            HomeStripGeometry.exclusionHeight(bottomInset: 0),
            HomeStripGeometry.minimumInset
        )
        XCTAssertGreaterThan(HomeStripGeometry.minimumInset, 0)
    }

    func testTouchInsideTheStripIsRejected() {
        // 844 pt screen, 34 pt inset -> strip starts at 810.
        XCTAssertTrue(HomeStripGeometry.contains(globalY: 810, screenHeight: 844, bottomInset: 34))
        XCTAssertTrue(HomeStripGeometry.contains(globalY: 843, screenHeight: 844, bottomInset: 34))
    }

    func testTouchAboveTheStripIsAccepted() {
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 809, screenHeight: 844, bottomInset: 34))
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 0, screenHeight: 844, bottomInset: 34))
    }

    func testZeroInsetUsesTheMinimumStrip() {
        XCTAssertTrue(HomeStripGeometry.contains(globalY: 670, screenHeight: 667, bottomInset: 0))
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 600, screenHeight: 667, bottomInset: 0))
    }

    /// Without a measured screen (early in launch) nothing may be excluded,
    /// otherwise the whole picker could stop responding.
    func testUnknownScreenHeightExcludesNothing() {
        XCTAssertFalse(HomeStripGeometry.contains(globalY: 800, screenHeight: 0, bottomInset: 34))
    }

    func testNonFiniteCoordinatesAreIgnored() {
        XCTAssertFalse(
            HomeStripGeometry.contains(
                globalY: .nan,
                screenHeight: 844,
                bottomInset: 34
            )
        )
    }
}
