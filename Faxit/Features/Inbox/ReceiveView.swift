import SwiftUI
import SwiftData

/// The Receive tab for someone without a fax number: straight into picking
/// one and subscribing. Once that succeeds, RootTabView swaps this tab for
/// the Inbox.
struct ReceiveView: View {
    var body: some View {
        NavigationStack {
            NumberProvisioningView(provider: FaxProviderContainer.shared, showsCloseButton: false)
        }
    }
}

#Preview {
    ReceiveView()
        .environment(AppSettingsStore(modelContext: try! ModelContainer(for: AppSettingsModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
        .environment(StoreManager())
}
