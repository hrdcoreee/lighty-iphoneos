import XCTest
@testable import Lighty

final class ScannedDeviceTests: XCTestCase {

    private func device(rssi: Int) -> ScannedDevice {
        ScannedDevice(id: UUID(), name: "ELK-BLEDOM", rssi: rssi, isElk: true)
    }

    func testSignalLevelBuckets() {
        XCTAssertEqual(device(rssi: -40).signalLevel, 4)
        XCTAssertEqual(device(rssi: -55).signalLevel, 4)
        XCTAssertEqual(device(rssi: -60).signalLevel, 3)
        XCTAssertEqual(device(rssi: -70).signalLevel, 2)
        XCTAssertEqual(device(rssi: -85).signalLevel, 1)
        XCTAssertEqual(device(rssi: -95).signalLevel, 0)
    }

    func testBoundDeviceRoundTrip() {
        let id = UUID()
        let bound = BoundDevice(id: id, name: "ELK-BLEDOM")
        let restored = bound.toScannedDevice()
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.name, "ELK-BLEDOM")
        XCTAssertTrue(restored.isElk)
    }

    func testBoundDeviceCodableRoundTrip() throws {
        let bound = BoundDevice(id: UUID(), name: nil)
        let data = try JSONEncoder().encode(bound)
        let decoded = try JSONDecoder().decode(BoundDevice.self, from: data)
        XCTAssertEqual(bound, decoded)
    }
}
