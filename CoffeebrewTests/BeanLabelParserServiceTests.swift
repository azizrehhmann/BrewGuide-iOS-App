import XCTest
@testable import Coffeebrew

final class BeanLabelParserServiceTests: XCTestCase {
    private func roast(_ text: String) -> String? {
        BeanLabelParserService.parse(ocrText: text).roastLevel
    }

    func testMediumLightIsNotReadAsLight() {
        XCTAssertEqual(roast("Ethiopia Guji\nMedium-Light Roast"), "Medium-Light")
    }

    func testTastingNoteDoesNotChangeRoast() {
        XCTAssertEqual(roast("House Blend\nDark Roast\nNotes: cinnamon, cocoa"), "Dark")
    }

    func testRoasterNameDoesNotChangeRoast() {
        XCTAssertEqual(roast("Daylight Roasters\nMedium Roast"), "Medium")
    }

    func testWeightInOuncesAndGrams() {
        XCTAssertEqual(BeanLabelParserService.parse(ocrText: "Net wt 340g").weightGrams ?? 0, 340, accuracy: 0.1)
        XCTAssertEqual(BeanLabelParserService.parse(ocrText: "12 oz").weightGrams ?? 0, 340.2, accuracy: 0.1)
    }
}
