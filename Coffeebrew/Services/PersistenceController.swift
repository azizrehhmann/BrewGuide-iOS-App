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

        // The fallback must reopen this same file, or the user's brews would appear to vanish
        let storeURL = container.persistentStoreDescriptions.first?.url
        var storeLoadedSuccessfully = false

        container.loadPersistentStores { _, error in
            if let error {
                print("CoreData/CloudKit load failed: \(error)")
            } else {
                storeLoadedSuccessfully = true
            }
        }

        // If the CloudKit-backed store failed to load, reopen the same file without CloudKit so the
        // user's data stays visible. If that fails too, no store is loaded and saves report failure.
        if !storeLoadedSuccessfully || container.persistentStoreCoordinator.persistentStores.isEmpty {
            print("PersistenceController: CloudKit store unavailable — reopening the same store without CloudKit")

            let localDescription = NSPersistentStoreDescription()
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
                    print("PersistenceController: store reopened without CloudKit")
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
