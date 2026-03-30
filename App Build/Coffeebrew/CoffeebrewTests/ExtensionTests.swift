import XCTest
import SwiftUI
@testable import Coffeebrew

final class ExtensionTests: XCTestCase {

    // MARK: - Int Time Formatting

    func testFormattedTimeSecondsOnly() {
        XCTAssertEqual(30.formattedTime, "30s")
        XCTAssertEqual(0.formattedTime, "0s")
        XCTAssertEqual(59.formattedTime, "59s")
    }

    func testFormattedTimeMinutesOnly() {
        XCTAssertEqual(60.formattedTime, "1 min")
        XCTAssertEqual(120.formattedTime, "2 min")
        XCTAssertEqual(300.formattedTime, "5 min")
    }

    func testFormattedTimeMinutesAndSeconds() {
        XCTAssertEqual(90.formattedTime, "1 min 30s")
        XCTAssertEqual(65.formattedTime, "1 min 5s")
        XCTAssertEqual(210.formattedTime, "3 min 30s")
    }

    // MARK: - Short Formatted Time

    func testShortFormattedTimeSecondsOnly() {
        XCTAssertEqual(5.shortFormattedTime, "0:05")
        XCTAssertEqual(30.shortFormattedTime, "0:30")
        XCTAssertEqual(0.shortFormattedTime, "0:00")
    }

    func testShortFormattedTimeWithMinutes() {
        XCTAssertEqual(60.shortFormattedTime, "1:00")
        XCTAssertEqual(90.shortFormattedTime, "1:30")
        XCTAssertEqual(125.shortFormattedTime, "2:05")
    }

    // MARK: - Color Hex Init

    func testColorHexInitBlack() {
        let color = Color(hex: 0x000000)
        XCTAssertNotNil(color) // Just verify it doesn't crash
    }

    func testColorHexInitWhite() {
        let color = Color(hex: 0xFFFFFF)
        XCTAssertNotNil(color)
    }

    func testColorHexInitWithOpacity() {
        let color = Color(hex: 0xFF0000, opacity: 0.5)
        XCTAssertNotNil(color)
    }

    func testColorHexInitKnownColor() {
        // Espresso brown #4A2C2A
        let color = Color(hex: 0x4A2C2A)
        XCTAssertNotNil(color)
    }
}
