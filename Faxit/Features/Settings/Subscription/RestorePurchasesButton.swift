import SwiftUI
import StoreKit

/// Restores subscriptions bought on this Apple ID. Works as a List row or,
/// with a button style applied by the caller, on the paywall. Every outcome
/// ends in an alert so nothing happens silently.
struct RestorePurchasesButton: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var isRestoring = false
    @State private var outcome: Outcome?

    private enum Outcome {
        case restored([String])
        case nothingFound
        case failed
        case offline

        var title: String {
            switch self {
            case .restored: CopyDeck.Subscription.restoredTitle
            case .nothingFound: CopyDeck.Subscription.nothingFoundTitle
            case .failed: CopyDeck.Subscription.restoreFailedTitle
            case .offline: CopyDeck.Subscription.restoreOfflineTitle
            }
        }

        var message: String {
            switch self {
            case .restored(let names): CopyDeck.Subscription.restoredMessage(names)
            case .nothingFound: CopyDeck.Subscription.nothingFoundMessage
            case .failed: CopyDeck.Subscription.restoreFailedMessage
            case .offline: CopyDeck.Subscription.restoreOfflineMessage
            }
        }
    }

    var body: some View {
        Button {
            Task { await restore() }
        } label: {
            HStack(spacing: 8) {
                Text(CopyDeck.Subscription.restorePurchases)
                if isRestoring {
                    ProgressView()
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(isRestoring)
        .accessibilityValue(isRestoring ? Text(CopyDeck.Subscription.checkingResult) : Text(""))
        .alert(
            outcome?.title ?? "",
            isPresented: Binding(get: { outcome != nil }, set: { if !$0 { outcome = nil } }),
            presenting: outcome
        ) { outcome in
            switch outcome {
            case .failed, .offline:
                Button(CopyDeck.Subscription.retry) {
                    Task { await restore() }
                }
                Button(CopyDeck.Subscription.cancel, role: .cancel) {}
            case .restored, .nothingFound:
                Button(CopyDeck.Subscription.ok, role: .cancel) {}
            }
        } message: { outcome in
            Text(outcome.message)
        }
    }

    private func restore() async {
        guard networkMonitor.isOnline else {
            outcome = .offline
            return
        }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let restored = try await storeManager.restorePurchases()
            outcome = restored.isEmpty ? .nothingFound : .restored(restored.map(\.displayName))
        } catch {
            outcome = .failed
        }
    }
}
