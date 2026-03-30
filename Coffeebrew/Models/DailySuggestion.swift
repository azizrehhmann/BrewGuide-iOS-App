import Foundation

struct DailySuggestion {
    let technique: Technique
    let method: BrewMethod
    let computedDate: Date
    let personalScore: Double           // 0–1, for debugging
    let reasonLabel: String             // e.g. "You haven't tried pour over in 3 weeks"
    let streakDays: Int                 // 0 if no active streak
    let hasPreviousBrew: Bool
    let previousBestRating: Int?        // 1–5 if brewed before
    let flavourHook: String             // e.g. "Bright & floral"
}
