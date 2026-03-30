import SwiftUI
import Combine

final class BeansViewModel: ObservableObject {
    @Published var beans: [Bean] = []
    @Published var selectedBean: Bean?

    func load(forTechniqueId techniqueId: String, from service: DatabaseService) {
        beans = service.beans(forTechniqueId: techniqueId)
        selectedBean = beans.first
    }
}
