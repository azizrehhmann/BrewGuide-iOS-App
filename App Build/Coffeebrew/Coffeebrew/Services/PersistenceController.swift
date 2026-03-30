import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()

    /// The CloudKit container identifier — must match the iCloud container in entitlements
    static let cloudKitContainerIdentifier = "iCloud.Aziz.Coffeebrew"

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for i in 0..<5 {
            let session = BrewSession(context: context)
            session.id = UUID()
            session.brewedAt = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            session.methodName = ["Pour Over", "French Press", "AeroPress"][i % 3]
            session.equipmentName = ["Hario V60", "French Press", "AeroPress"][i % 3]
            session.techniqueName = ["Standard Pour", "James Hoffmann Method", "Inverted"][i % 3]
            session.beanName = "Ethiopia Yirgacheffe"
            session.beanOrigin = "Ethiopia"
            session.roastLevel = "Light"
            session.servingSize = Int16(i % 3 + 1)
            session.coffeeAmountGrams = Double(15 + i * 2)
            session.waterAmountMl = Double(250 + i * 30)
            session.grindSize = "Medium"
            session.waterTempC = 94.0
            session.rating = Int16(i % 6)
            session.notes = i % 2 == 0 ? "Lovely bright cup, slightly acidic finish." : nil
            session.flavourTags = "Fruity,Bright"
            session.totalBrewTimeSeconds = Int32(240 + i * 30)
            session.isFavourite = i == 1
        }
        try? context.save()
        return controller
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "BrewGuide")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let description = container.persistentStoreDescriptions.first {
            // Configure for CloudKit sync
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )

            // Enable persistent history tracking (required for CloudKit sync)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        } else {
            print("PersistenceController: No persistent store description found — skipping CloudKit config")
        }

        var storeLoadedSuccessfully = false

        container.loadPersistentStores { _, error in
            if let error {
                print("CoreData/CloudKit load failed: \(error)")
            } else {
                storeLoadedSuccessfully = true
            }
        }

        // If CloudKit store failed to load (e.g. no iCloud account in simulator),
        // fall back to a local-only SQLite store so the app still works.
        // Also verify the coordinator actually has at least one store.
        if !storeLoadedSuccessfully || container.persistentStoreCoordinator.persistentStores.isEmpty {
            print("PersistenceController: CloudKit store unavailable — falling back to local-only store")

            // Create a fresh local-only description pointing to a known path
            let localDescription = NSPersistentStoreDescription()
            let storeURL = NSPersistentContainer.defaultDirectoryURL()
                .appendingPathComponent("BrewGuide-local.sqlite")
            localDescription.url = storeURL
            localDescription.cloudKitContainerOptions = nil
            localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            localDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [localDescription]
            container.loadPersistentStores { _, error in
                if let error {
                    print("CoreData local fallback also failed: \(error)")
                } else {
                    storeLoadedSuccessfully = true
                    print("PersistenceController: Local-only store loaded at \(storeURL.path)")
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Listen for remote changes
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AuthenticationService.shared.updateSyncStatus(.synced)
            }
        }

        // Start monitoring sync events
        #if DEBUG
        if storeLoadedSuccessfully {
            do {
                try container.initializeCloudKitSchema(options: [])
            } catch {
                print("CloudKit schema initialization skipped: \(error)")
            }
        }
        #endif
    }
}
