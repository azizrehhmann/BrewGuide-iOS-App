import Foundation

struct DailySuggestion {
    let technique: Technique
    let streakDays: Int                 // 0 if no active streak
    let flavourHook: String             // e.g. "Bright & floral"
}
