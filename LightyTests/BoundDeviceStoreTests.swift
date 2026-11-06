import XCTest
@testable import Lighty

/// The pairing must survive a relaunch: this is the "pair once, remember
/// forever" contract, mirroring the Android `SharedPreferences` behaviour.
final class BoundDeviceStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: BoundDeviceStore!
    private let suiteName = "BoundDeviceStoreTests"

    override func setUp() {
        super.setUp()
        // A throwaway suite so the real app domain is never touched.
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = BoundDeviceStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testStartsUnbound() {
        XCTAssertNil(store.current)
    }

    func testSavedDeviceIsReadBackByAFreshStore() {
        let id = UUID()
        store.save(BoundDevice(id: id, name: "ELK-BLEDOM"))

        // A new instance stands in for the next app launch.
        let next = BoundDeviceStore(defaults: defaults)
        XCTAssertEqual(next.current?.id, id)
        XCTAssertEqual(next.current?.name, "ELK-BLEDOM")
    }

    func testSavingAnotherDeviceReplacesThePreviousOne() {
        store.save(BoundDevice(id: UUID(), name: "First"))
        let second = UUID()
        store.save(BoundDevice(id: second, name: "Second"))

        XCTAssertEqual(store.current?.id, second)
        XCTAssertEqual(store.current?.name, "Second")
    }

    func testClearForgetsTheDevice() {
        store.save(BoundDevice(id: UUID(), name: "ELK-BLEDOM"))
        store.clear()

        XCTAssertNil(store.current)
        XCTAssertNil(BoundDeviceStore(defaults: defaults).current)
    }

    func testCorruptStoredValueReadsAsUnbound() {
        defaults.set("not-a-uuid", forKey: "lighty.bound.id")
        XCTAssertNil(store.current)
    }

    func testNameIsOptional() {
        store.save(BoundDevice(id: UUID(), name: nil))
        XCTAssertNotNil(store.current)
        XCTAssertNil(store.current?.name)
    }
}
