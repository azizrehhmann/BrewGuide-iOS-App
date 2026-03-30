import SwiftUI
import Combine

final class MethodViewModel: ObservableObject {
    @Published var methods: [BrewMethod] = []
    @Published var selectedMethodTechniques: [Technique] = []

    private var databaseService: DatabaseService?

    func load(from service: DatabaseService) {
        self.databaseService = service
        methods = service.methods
    }

    func loadTechniques(forMethodId methodId: String) {
        guard let service = databaseService else { return }
        selectedMethodTechniques = service.techniques(forMethodId: methodId)
    }
}
