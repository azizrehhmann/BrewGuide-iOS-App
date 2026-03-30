import XCTest
@testable import Coffeebrew

final class DatabaseServiceTests: XCTestCase {

    // MARK: - BrewMethod Decoding

    func testBrewMethodDecoding() throws {
        let json = """
        [{
            "method_id": "french-press",
            "name": "French Press",
            "description": "Full immersion brewing method.",
            "difficulty": 1,
            "icon_name": "cup.and.saucer.fill",
            "image_name": null,
            "category": "Immersion"
        }]
        """.data(using: .utf8)!

        let methods = try JSONDecoder().decode([BrewMethod].self, from: json)
        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods[0].methodId, "french-press")
        XCTAssertEqual(methods[0].name, "French Press")
        XCTAssertEqual(methods[0].difficulty, 1)
        XCTAssertEqual(methods[0].iconName, "cup.and.saucer.fill")
        XCTAssertNil(methods[0].imageName)
        XCTAssertEqual(methods[0].difficultyLabel, "Beginner")
    }

    // MARK: - Technique Decoding

    func testTechniqueDecoding() throws {
        let json = """
        [{
            "technique_id": "v60-james-hoffmann",
            "method_id": "v60-pour-over",
            "name": "V60 – James Hoffmann",
            "description": "Hario V60 Dripper. Grind: Medium-Fine.",
            "total_time_seconds": 210,
            "water_temp_c": 95,
            "ratio_water_coffee": 16.7,
            "grind_size_label": "Medium-Fine",
            "grind_size_ref": null,
            "step_count": 9,
            "sort_order": 1
        }]
        """.data(using: .utf8)!

        let techniques = try JSONDecoder().decode([Technique].self, from: json)
        XCTAssertEqual(techniques.count, 1)
        XCTAssertEqual(techniques[0].techniqueId, "v60-james-hoffmann")
        XCTAssertEqual(techniques[0].methodId, "v60-pour-over")
        XCTAssertEqual(techniques[0].totalTimeSeconds, 210)
        XCTAssertEqual(techniques[0].waterTempC, 95)
        XCTAssertEqual(techniques[0].ratioWaterCoffee, 16.7, accuracy: 0.01)
    }

    // MARK: - BrewStep Decoding

    func testBrewStepDecoding() throws {
        let json = """
        [{
            "step_id": "v60-hoffmann-step-1",
            "technique_id": "v60-james-hoffmann",
            "step_number": 1,
            "title": "0:00",
            "instruction": "Add ground coffee to V60.",
            "duration_seconds": 0,
            "water_volume_ml_base": 60.0,
            "image_name": null
        }]
        """.data(using: .utf8)!

        let steps = try JSONDecoder().decode([BrewStep].self, from: json)
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].stepId, "v60-hoffmann-step-1")
        XCTAssertEqual(steps[0].stepNumber, 1)
        XCTAssertEqual(steps[0].waterVolumeMlBase, 60.0, accuracy: 0.01)
    }

    // MARK: - Bean Decoding

    func testBeanDecoding() throws {
        let json = """
        [{
            "bean_id": "v60-bean-1",
            "technique_id": "v60-james-hoffmann",
            "name": "Ethiopia Yirgacheffe (Light)",
            "origin": "Ethiopia Yirgacheffe",
            "process": "Washed",
            "roast_level": "Light",
            "flavour_notes": ["Floral", "Bergamot", "Stone Fruit"],
            "match_score": 90,
            "notes": null
        }]
        """.data(using: .utf8)!

        let beans = try JSONDecoder().decode([Bean].self, from: json)
        XCTAssertEqual(beans.count, 1)
        XCTAssertEqual(beans[0].beanId, "v60-bean-1")
        XCTAssertEqual(beans[0].flavourNotes, ["Floral", "Bergamot", "Stone Fruit"])
        XCTAssertEqual(beans[0].matchScore, 90)
        XCTAssertEqual(beans[0].roastLevel, "Light")
        XCTAssertNil(beans[0].notes)
    }

    // MARK: - Multiple Items

    func testMultipleMethodsDecoding() throws {
        let json = """
        [
            {"method_id": "french-press", "name": "French Press", "description": "Immersion.", "difficulty": 1, "icon_name": "cup.and.saucer.fill", "image_name": null, "category": "Immersion"},
            {"method_id": "v60-pour-over", "name": "V60 Pour Over", "description": "Pour over.", "difficulty": 3, "icon_name": "drop.fill", "image_name": null, "category": "Pour Over"},
            {"method_id": "aeropress", "name": "AeroPress", "description": "Pressure.", "difficulty": 2, "icon_name": "gauge.with.dots.needle.bottom.50percent", "image_name": null, "category": "Pressure"}
        ]
        """.data(using: .utf8)!

        let methods = try JSONDecoder().decode([BrewMethod].self, from: json)
        XCTAssertEqual(methods.count, 3)
        XCTAssertEqual(methods[0].id, "french-press")
        XCTAssertEqual(methods[1].id, "v60-pour-over")
        XCTAssertEqual(methods[2].id, "aeropress")
    }

    // MARK: - Identifiable & Hashable

    func testBrewMethodIdentifiable() throws {
        let json = """
        [{"method_id": "test", "name": "Test", "description": "Desc", "difficulty": 1, "icon_name": "cup.and.saucer.fill", "image_name": null, "category": "Immersion"}]
        """.data(using: .utf8)!

        let methods = try JSONDecoder().decode([BrewMethod].self, from: json)
        XCTAssertEqual(methods[0].id, "test")

        // Test Hashable
        var set = Set<BrewMethod>()
        set.insert(methods[0])
        XCTAssertEqual(set.count, 1)
    }
}
