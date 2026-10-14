import SwiftUI
import SwiftData

/// The send sheet reached directly from the home screen's "Send" button —
/// pages and recipient are already finalized there, so this screen skips
/// straight past page review to the one decision left: the send plan.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    let pages: [ScannedPage]
    let recipientNumber: String
    let coverPageStyle: CoverPageStyle?
    var coverPageDetails = CoverPageDetails()
    let onSent: (SentFax) -> Void

    @State private var sentFax: SentFax?

    private var submission: FaxSubmission {
        FaxSubmission(pages: pages, recipientNumber: recipientNumber, coverPageStyle: coverPageStyle, coverPageDetails: coverPageDetails)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send your fax")
                            .font(.faxitHero)
                            .foregroundStyle(Color.faxitInkPrimary)
                        Text("\(submission.transmittedPageCount) page\(submission.transmittedPageCount == 1 ? "" : "s")\(submission.transmittedPageCount > pages.count ? " (incl. free cover page)" : "") to \(PhoneNumberFormatter.displayString(recipientNumber))")
                            .font(.faxitCaption)
                            .foregroundStyle(Color.faxitInkSecondary)
                    }

                    SendPlanPanel(submission: submission) { fax in
                        onSent(fax)
                        sentFax = fax
                    }

                    Text(CopyDeck.Compose.retentionDisclosure)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
                .padding(16)
            }
            .navigationTitle(CopyDeck.Compose.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .fullScreenCover(item: $sentFax) { fax in
            SendingStatusView(fax: fax, provider: FaxProviderContainer.shared, onDone: {
                dismiss()
            })
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: SentFax.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400))
    let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
    }
    PaywallView(
        pages: [ScannedPage(baseImage: image, source: .pdf), ScannedPage(baseImage: image, source: .pdf)],
        recipientNumber: "5551234567",
        coverPageStyle: nil,
        onSent: { _ in }
    )
    .environment(StoreManager())
    .modelContainer(container)
}
