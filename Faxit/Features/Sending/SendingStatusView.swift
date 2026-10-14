import SwiftUI
import SwiftData

/// Shown immediately after Pay and send: the fax's live route
/// (In transit → Received by the other party → Delivered) advances as the
/// provider reports progress, then the outcome and next steps appear below
/// it on the same screen.
struct SendingStatusView: View {
    @Environment(\.modelContext) private var modelContext
    let fax: SentFax
    let provider: FaxProvider
    let onDone: () -> Void

    var body: some View {
        FaxStatusDetailView(fax: fax, provider: provider, attachLiveIfNeeded: false, onDone: onDone)
            .task {
                if !fax.status.isTerminal {
                    await FaxSendRunner.run(fax: fax, provider: provider, modelContext: modelContext)
                }
            }
    }
}
