//
//  FaxitApp.swift
//  Faxit
//

import SwiftUI
import SwiftData

@main
struct FaxitApp: App {
    @State private var settingsStore: AppSettingsStore
    @State private var storeManager = StoreManager()
    @State private var networkMonitor = NetworkMonitor()

    init() {
        let context = PersistenceController.modelContainer.mainContext
        _settingsStore = State(initialValue: AppSettingsStore(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                RootTabView()
            }
                .faxitTypography()
                .environment(settingsStore)
                .environment(storeManager)
                .environment(networkMonitor)
                .faxitAppearance(settingsStore)
        }
        .modelContainer(PersistenceController.modelContainer)
    }
}
