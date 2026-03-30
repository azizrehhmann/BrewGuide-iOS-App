import Foundation

/// Parses OCR text from a coffee bag label into structured bean fields.
struct BeanLabelParserService {

    struct ParsedBean {
        var name: String?
        var roasterName: String?
        var origin: String?
        var roastLevel: String?
        var weightGrams: Double?
        var roastDate: Date?
        var tastingNotes: [String]?
    }

    // MARK: - Known Origins

    private static let knownOrigins: [String] = [
        "Ethiopia", "Colombia", "Brazil", "Kenya", "Guatemala", "Costa Rica",
        "Honduras", "Peru", "Mexico", "Indonesia", "Sumatra", "Java",
        "Rwanda", "Burundi", "Tanzania", "Uganda", "Yemen", "India",
        "Panama", "El Salvador", "Nicaragua", "Bolivia", "Ecuador",
        "Papua New Guinea", "Hawaii", "Jamaica", "Dominican Republic",
        "Yirgacheffe", "Sidamo", "Guji", "Huila", "Nari\u{00F1}o", "Cauca",
        "Antigua", "Tarraz\u{00FA}", "Kona", "Blue Mountain", "Geisha", "Gesha",
        "Cerrado", "Mogiana", "Sul de Minas"
    ]

    // MARK: - Roast Level Keywords

    private static let roastKeywords: [(pattern: String, level: String)] = [
        ("extra light", "Light"),
        ("light roast", "Light"),
        ("light", "Light"),
        ("blonde", "Light"),
        ("cinnamon", "Light"),
        ("medium-light", "Medium-Light"),
        ("medium light", "Medium-Light"),
        ("medium-dark", "Medium-Dark"),
        ("medium dark", "Medium-Dark"),
        ("full city", "Medium-Dark"),
        ("city+", "Medium-Dark"),
        ("city roast", "Medium"),
        ("medium roast", "Medium"),
        ("medium", "Medium"),
        ("dark roast", "Dark"),
        ("french roast", "Dark"),
        ("italian roast", "Dark"),
        ("espresso roast", "Dark"),
        ("dark", "Dark"),
        ("vienna", "Medium-Dark"),
    ]

    // MARK: - Weight Patterns

    private static let weightPatterns: [String] = [
        #"(\d+(?:\.\d+)?)\s*(?:g|grams|gr)\b"#,
        #"(\d+(?:\.\d+)?)\s*(?:oz|ounces?)\b"#,
        #"(\d+(?:\.\d+)?)\s*(?:kg|kilograms?)\b"#,
        #"(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?)\b"#,
    ]

    // MARK: - Date Patterns

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "MM-dd-yyyy",
            "dd.MM.yyyy", "yyyy-MM-dd", "d MMM yyyy", "MMM d, yyyy",
            "MMMM d, yyyy", "d MMMM yyyy", "MMM yyyy", "MMMM yyyy"
        ]
        return formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }()

    // MARK: - Parse

    static func parse(ocrText: String) -> ParsedBean {
        var result = ParsedBean()
        let lines = ocrText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let fullText = ocrText.lowercased()

        // 1. Extract origin
        result.origin = extractOrigin(from: lines)

        // 2. Extract roast level
        result.roastLevel = extractRoastLevel(from: fullText)

        // 3. Extract weight
        result.weightGrams = extractWeight(from: fullText)

        // 4. Extract roast date
        result.roastDate = extractDate(from: lines, keyword: "roast")

        // 5. Extract roaster name (look for keywords like "roasted by", "roaster:", company-like lines)
        result.roasterName = extractRoaster(from: lines)

        // 6. Extract bean name (typically the most prominent line / first non-roaster line)
        result.name = extractBeanName(from: lines, roaster: result.roasterName, origin: result.origin)

        // 7. Extract tasting notes / flavour profiles
        result.tastingNotes = extractTastingNotes(from: lines, fullText: fullText)

        return result
    }

    // MARK: - Extraction Helpers

    private static func extractOrigin(from lines: [String]) -> String? {
        for line in lines {
            for origin in knownOrigins {
                if line.localizedCaseInsensitiveContains(origin) {
                    return origin
                }
            }
        }
        // Check for "origin:" prefix
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("origin") || lower.hasPrefix("region") || lower.hasPrefix("country") {
                let value = line.components(separatedBy: CharacterSet(charactersIn: ":|-"))
                    .dropFirst()
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func extractRoastLevel(from text: String) -> String? {
        for (pattern, level) in roastKeywords {
            if text.contains(pattern) {
                return level
            }
        }
        return nil
    }

    private static func extractWeight(from text: String) -> Double? {
        for (index, pattern) in weightPatterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let numRange = Range(match.range(at: 1), in: text),
               let value = Double(text[numRange]) {
                switch index {
                case 0: return value              // grams
                case 1: return value * 28.3495    // oz to grams
                case 2: return value * 1000       // kg to grams
                case 3: return value * 453.592    // lbs to grams
                default: return value
                }
            }
        }
        return nil
    }

    private static func extractDate(from lines: [String], keyword: String) -> Date? {
        // First look for lines containing the keyword (e.g. "roasted on", "roast date")
        let dateLines = lines.filter { $0.lowercased().contains(keyword) }
        let candidates = dateLines.isEmpty ? lines : dateLines

        for line in candidates {
            // Try to extract a date from this line
            for formatter in dateFormatters {
                // Try the whole line and substrings
                if let date = formatter.date(from: line), isReasonableRoastDate(date) {
                    return date
                }
                // Try to find date within the line
                let parts = line.components(separatedBy: CharacterSet(charactersIn: ":-"))
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if let date = formatter.date(from: trimmed), isReasonableRoastDate(date) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    private static func isReasonableRoastDate(_ date: Date) -> Bool {
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return date >= oneYearAgo && date <= now
    }

    private static func extractRoaster(from lines: [String]) -> String? {
        let roasterPrefixes = ["roasted by", "roaster:", "roastery:", "by ", "crafted by"]
        for line in lines {
            let lower = line.lowercased()
            for prefix in roasterPrefixes {
                if lower.hasPrefix(prefix) || lower.contains(prefix) {
                    let value = extractValueAfter(prefix: prefix, in: line)
                    if let v = value, !v.isEmpty { return v }
                }
            }
        }
        // Look for lines with common roaster suffixes
        let roasterSuffixes = ["roasters", "roastery", "coffee co", "coffee company", "coffee roasting"]
        for line in lines {
            let lower = line.lowercased()
            for suffix in roasterSuffixes {
                if lower.contains(suffix) {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private static func extractBeanName(from lines: [String], roaster: String?, origin: String?) -> String? {
        // Heuristic: the bean name is usually one of the first 3 lines
        // and is NOT the roaster, origin, or a metadata line
        let skipKeywords = ["roast", "origin", "region", "weight", "net wt", "roasted",
                           "best before", "use by", "ingredients", "contains", "oz", "grams"]

        for line in lines.prefix(5) {
            let lower = line.lowercased()

            // Skip if it's the roaster
            if let roaster = roaster, line.lowercased() == roaster.lowercased() { continue }

            // Skip if it looks like metadata
            if skipKeywords.contains(where: { lower.hasPrefix($0) }) { continue }

            // Skip very short lines (probably labels)
            if line.count < 3 { continue }

            // Skip lines that are just numbers/weights
            if line.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " || $0 == "g" }) { continue }

            return line.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - Tasting Notes

    /// Known tasting note keywords to match against OCR text
    private static let knownTastingNotes: [String] = [
        // Fruity
        "berry", "blueberry", "strawberry", "raspberry", "blackberry",
        "citrus", "lemon", "orange", "grapefruit", "lime",
        "peach", "apricot", "plum", "cherry", "stone fruit",
        "tropical", "mango", "pineapple", "passionfruit", "papaya",
        "apple", "grape", "cranberry",
        // Sweet
        "chocolate", "dark chocolate", "milk chocolate", "cocoa",
        "caramel", "toffee", "brown sugar", "molasses", "maple",
        "honey", "vanilla", "butterscotch",
        // Nutty
        "almond", "hazelnut", "walnut", "peanut", "cashew",
        "malt", "toast", "cereal",
        // Floral
        "jasmine", "rose", "lavender", "hibiscus", "chamomile",
        "bergamot", "floral", "elderflower",
        // Spicy & Earthy
        "cinnamon", "clove", "nutmeg", "cardamom", "ginger",
        "black pepper", "tobacco", "leather", "cedar", "woody",
        "earthy", "smoky",
        // Descriptors
        "bright", "clean", "crisp", "juicy", "winey",
        "creamy", "silky", "buttery", "syrupy", "balanced",
        "complex", "delicate", "tangy"
    ]

    private static func extractTastingNotes(from lines: [String], fullText: String) -> [String]? {
        var found: [String] = []

        // 1. Check for explicit "tasting notes" or "notes:" lines
        let notesPrefixes = ["tasting notes", "taste notes", "notes:", "flavour:", "flavor:",
                            "cup profile", "cupping notes", "aroma"]
        for line in lines {
            let lower = line.lowercased()
            for prefix in notesPrefixes {
                if lower.contains(prefix) {
                    // Extract the value part after the prefix
                    if let value = extractValueAfter(prefix: prefix, in: line), !value.isEmpty {
                        // Split by common delimiters (comma, bullet, pipe, slash)
                        let notes = value.components(separatedBy: CharacterSet(charactersIn: ",|\u{2022}/&"))
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                        found.append(contentsOf: notes)
                    }
                }
            }
        }

        // 2. Also scan all text for known tasting note keywords
        // Sort by length descending so "dark chocolate" matches before "chocolate"
        let sortedNotes = knownTastingNotes.sorted { $0.count > $1.count }
        for note in sortedNotes {
            let capitalized = note.prefix(1).uppercased() + note.dropFirst()
            guard !found.contains(where: { $0.lowercased() == note }) else { continue }
            if fullText.contains(note) {
                found.append(capitalized)
            }
        }

        return found.isEmpty ? nil : Array(Set(found)).sorted()
    }

    private static func extractValueAfter(prefix: String, in line: String) -> String? {
        guard let range = line.lowercased().range(of: prefix) else { return nil }
        let afterPrefix = String(line[range.upperBound...])
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":-")))
        return afterPrefix.isEmpty ? nil : afterPrefix
    }
}
