import Foundation
import SwiftData
import Observation

/// Thin @Observable wrapper around the single AppSettingsModel row so views
/// can bind to it directly without each one running its own fetch-or-create.
@Observable
final class AppSettingsStore {
    private(set) var settings: AppSettingsModel
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let existing = try? modelContext.fetch(FetchDescriptor<AppSettingsModel>())
        if let found = existing?.first {
            self.settings = found
        } else {
            let created = AppSettingsModel()
            modelContext.insert(created)
            self.settings = created
        }
    }

    func save() {
        try? modelContext.save()
    }

    var appearanceMode: AppearanceMode? {
        get { settings.appearanceMode }
        set {
            settings.appearanceMode = newValue
            save()
        }
    }

    /// "Delete my data": replaces every preference with a fresh-install row.
    func resetToDefaults() {
        try? modelContext.delete(model: AppSettingsModel.self)
        let created = AppSettingsModel()
        modelContext.insert(created)
        settings = created
        save()
    }
}
