import Foundation
import SwiftData

enum PersistenceController {
    static var modelContainer: ModelContainer = {
        let schema = Schema([
            SenderProfile.self,
            AppSettingsModel.self,
            FaxDraft.self,
            SentFax.self,
            ReceivedFax.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
