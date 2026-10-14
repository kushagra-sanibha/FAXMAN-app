import SwiftUI

/// Shared detail screen for a tapped Activity row. For a SentFax this is
/// effectively the same content as FaxStatusDetailView reached live after sending.
struct FaxDetailView: View {
    let fax: SentFax

    var body: some View {
        FaxStatusDetailView(fax: fax, provider: FaxProviderContainer.shared, attachLiveIfNeeded: true)
            .navigationTitle(PhoneNumberFormatter.displayString(fax.recipientNumber))
            .navigationBarTitleDisplayMode(.inline)
    }
}
