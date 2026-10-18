import XCTest
@testable import Coffeebrew

// MARK: - BrewMethod Tests

final class BrewMethodTests: XCTestCase {

    private func decode(_ json: String) throws -> BrewMethod {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(BrewMethod.self, from: data)
    }

    func testDifficultyLabels() throws {
        let baseJson = { (difficulty: Int) -> String in
            """
            {"method_id":"test","name":"T","description":"D","difficulty":\(difficulty),"icon_name":"cup.and.saucer.fill","image_name":null,"category":"Pour Over"}
            """
        }

        XCTAssertEqual(try decode(baseJson(1)).difficultyLabel, "Beginner")
        XCTAssertEqual(try decode(baseJson(2)).difficultyLabel, "Easy")
        XCTAssertEqual(try decode(baseJson(3)).difficultyLabel, "Intermediate")
        XCTAssertEqual(try decode(baseJson(4)).difficultyLabel, "Advanced")
        XCTAssertEqual(try decode(baseJson(5)).difficultyLabel, "Expert")
        XCTAssertEqual(try decode(baseJson(0)).difficultyLabel, "Unknown")
        XCTAssertEqual(try decode(baseJson(99)).difficultyLabel, "Unknown")
    }

    func testIdentifiable() throws {
        let method = try decode("""
        {"method_id":"french-press","name":"FP","description":"D","difficulty":1,"icon_name":"cup.and.saucer.fill","image_name":null,"category":"Pour Over"}
        """)
        XCTAssertEqual(method.id, "french-press")
    }

    func testHashable() throws {
        let method1 = try decode("""
        {"method_id":"a","name":"A","description":"D","difficulty":1,"icon_name":"cup.and.saucer.fill","image_name":null,"category":"Pour Over"}
        """)
        let method2 = try decode("""
        {"method_id":"b","name":"B","description":"D","difficulty":2,"icon_name":"drop.fill","image_name":null,"category":"Pour Over"}
        """)
        var set = Set<BrewMethod>()
        set.insert(method1)
        set.insert(method2)
        set.insert(method1) // duplicate
        XCTAssertEqual(set.count, 2)
    }

    func testOptionalImageName() throws {
        let withImage = try decode("""
        {"method_id":"t","name":"T","description":"D","difficulty":1,"icon_name":"cup.and.saucer.fill","image_name":"photo.png","category":"Pour Over"}
        """)
        XCTAssertEqual(withImage.imageName, "photo.png")

        let withoutImage = try decode("""
        {"method_id":"t","name":"T","description":"D","difficulty":1,"icon_name":"cup.and.saucer.fill","image_name":null,"category":"Pour Over"}
        """)
        XCTAssertNil(withoutImage.imageName)
    }
}

// MARK: - Technique Tests

final class TechniqueTests: XCTestCase {

    func testDecodingAllFields() throws {
        let json = """
        {
            "technique_id": "v60-classic",
            "method_id": "v60",
            "name": "V60 Classic",
            "description": "Standard V60 pour over",
            "total_time_seconds": 210,
            "water_temp_c": 93,
            "ratio_water_coffee": 15.5,
            "grind_size_label": "Medium-Fine (table salt)",
            "grind_size_ref": "commandante-25",
            "step_count": 8,
            "sort_order": 2
        }
        """.data(using: .utf8)!

        let technique = try JSONDecoder().decode(Technique.self, from: json)
        XCTAssertEqual(technique.techniqueId, "v60-classic")
        XCTAssertEqual(technique.methodId, "v60")
        XCTAssertEqual(technique.totalTimeSeconds, 210)
        XCTAssertEqual(technique.waterTempC, 93)
        XCTAssertEqual(technique.ratioWaterCoffee, 15.5, accuracy: 0.01)
        XCTAssertEqual(technique.grindSizeRef, "commandante-25")
        XCTAssertEqual(technique.stepCount, 8)
        XCTAssertEqual(technique.sortOrder, 2)
        XCTAssertEqual(technique.id, "v60-classic")
    }

    func testOptionalGrindSizeRef() throws {
        let json = """
        {
            "technique_id": "t",
            "method_id": "m",
            "name": "N",
            "description": "D",
            "total_time_seconds": 60,
            "water_temp_c": 90,
            "ratio_water_coffee": 16.0,
            "grind_size_label": "Fine",
            "grind_size_ref": null,
            "step_count": 1,
            "sort_order": 1
        }
        """.data(using: .utf8)!
        let technique = try JSONDecoder().decode(Technique.self, from: json)
        XCTAssertNil(technique.grindSizeRef)
    }
}

// MARK: - BrewStep Tests

final class BrewStepTests: XCTestCase {

    func testDecodingAllFields() throws {
        let json = """
        {
            "step_id": "step-1",
            "technique_id": "t-1",
            "step_number": 3,
            "title": "Main Pour",
            "instruction": "Pour slowly in circles.",
            "duration_seconds": 45,
            "water_volume_ml_base": 150.5,
            "image_name": "pour.png"
        }
        """.data(using: .utf8)!

        let step = try JSONDecoder().decode(BrewStep.self, from: json)
        XCTAssertEqual(step.stepId, "step-1")
        XCTAssertEqual(step.techniqueId, "t-1")
        XCTAssertEqual(step.stepNumber, 3)
        XCTAssertEqual(step.title, "Main Pour")
        XCTAssertEqual(step.instruction, "Pour slowly in circles.")
        XCTAssertEqual(step.durationSeconds, 45)
        XCTAssertEqual(step.waterVolumeMlBase, 150.5, accuracy: 0.01)
        XCTAssertEqual(step.imageName, "pour.png")
        XCTAssertEqual(step.id, "step-1")
    }

    func testZeroDurationStep() throws {
        let json = """
        {
            "step_id": "s",
            "technique_id": "t",
            "step_number": 1,
            "title": "Prep",
            "instruction": "Add coffee.",
            "duration_seconds": 0,
            "water_volume_ml_base": 0.0,
            "image_name": null
        }
        """.data(using: .utf8)!

        let step = try JSONDecoder().decode(BrewStep.self, from: json)
        XCTAssertEqual(step.durationSeconds, 0)
        XCTAssertEqual(step.waterVolumeMlBase, 0.0, accuracy: 0.001)
        XCTAssertNil(step.imageName)
    }
}

// MARK: - Bean Tests

final class BeanTests: XCTestCase {

    func testDecodingAllFields() throws {
        let json = """
        {
            "bean_id": "bean-1",
            "technique_id": "t-1",
            "name": "Ethiopia Yirgacheffe",
            "origin": "Ethiopia",
            "process": "Washed",
            "roast_level": "Light",
            "flavour_notes": ["Floral", "Citrus", "Bergamot"],
            "match_score": 92,
            "notes": "Great for pour over"
        }
        """.data(using: .utf8)!

        let bean = try JSONDecoder().decode(Bean.self, from: json)
        XCTAssertEqual(bean.beanId, "bean-1")
        XCTAssertEqual(bean.techniqueId, "t-1")
        XCTAssertEqual(bean.name, "Ethiopia Yirgacheffe")
        XCTAssertEqual(bean.origin, "Ethiopia")
        XCTAssertEqual(bean.process, "Washed")
        XCTAssertEqual(bean.roastLevel, "Light")
        XCTAssertEqual(bean.flavourNotes, ["Floral", "Citrus", "Bergamot"])
        XCTAssertEqual(bean.matchScore, 92)
        XCTAssertEqual(bean.notes, "Great for pour over")
        XCTAssertEqual(bean.id, "bean-1")
    }

    func testEmptyFlavourNotes() throws {
        let json = """
        {
            "bean_id": "b",
            "technique_id": "t",
            "name": "N",
            "origin": "O",
            "process": "P",
            "roast_level": "Dark",
            "flavour_notes": [],
            "match_score": 50,
            "notes": null
        }
        """.data(using: .utf8)!

        let bean = try JSONDecoder().decode(Bean.self, from: json)
        XCTAssertTrue(bean.flavourNotes.isEmpty)
        XCTAssertNil(bean.notes)
    }

    func testHashable() throws {
        let json1 = """
        {"bean_id":"a","technique_id":"t","name":"A","origin":"O","process":"W","roast_level":"L","flavour_notes":[],"match_score":80,"notes":null}
        """.data(using: .utf8)!
        let json2 = """
        {"bean_id":"b","technique_id":"t","name":"B","origin":"O","process":"N","roast_level":"D","flavour_notes":["Choc"],"match_score":70,"notes":null}
        """.data(using: .utf8)!

        let bean1 = try JSONDecoder().decode(Bean.self, from: json1)
        let bean2 = try JSONDecoder().decode(Bean.self, from: json2)
        var set = Set<Bean>()
        set.insert(bean1)
        set.insert(bean2)
        set.insert(bean1)
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - BrewStep.displayTitle

final class BrewStepDisplayTitleTests: XCTestCase {
    private func step(title: String, instruction: String) throws -> BrewStep {
        let json = """
        {"step_id":"s","technique_id":"t","step_number":1,"title":"\(title)","instruction":"\(instruction)",
         "duration_seconds":0,"water_volume_ml_base":0,"image_name":null}
        """.data(using: .utf8)!
        return try JSONDecoder().decode(BrewStep.self, from: json)
    }

    func testRealTitleIsKept() throws {
        XCTAssertEqual(try step(title: "Prep", instruction: "Rinse filter.").displayTitle, "Prep")
    }

    func testClockTitleUsesFirstClause() throws {
        XCTAssertEqual(try step(title: "0:45", instruction: "Begin main pour: spiral pour").displayTitle, "Begin main pour")
    }

    func testPlaceholdersAndParentheticalsAreDropped() throws {
        let s = try step(title: "0:00", instruction: "Add {coffee}g coffee (medium grind \\u2014 coarser)")
        XCTAssertEqual(s.displayTitle, "Add coffee")
    }
}
