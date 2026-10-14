import SwiftUI

/// The final look before sending: page preview, recipient, then the send
/// plan panel (plan status or plan choice, and the Send button). Page
/// editing already happened in EditPagesStepView.
struct ReviewSendView: View {
    @Binding var pages: [ScannedPage]
    @Binding var coverPageStyle: CoverPageStyle?
    let coverPageDetails: CoverPageDetails
    let recipientNumber: String
    let onBack: () -> Void
    let onSent: (SentFax) -> Void

    @State private var zoomedPage: ScannedPage?

    private var submission: FaxSubmission {
        FaxSubmission(pages: pages, recipientNumber: recipientNumber, coverPageStyle: coverPageStyle, coverPageDetails: coverPageDetails)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(CopyDeck.Review.previewCaption)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)

                PageThumbnailGrid(pages: $pages, onTapPage: { zoomedPage = $0 })

                SectionCard {
                    HStack {
                        Text(PhoneNumberFormatter.displayString(recipientNumber))
                            .font(.faxitBodySemibold)
                        Spacer()
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    Text(CopyDeck.Review.numberFormatValid)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if let coverPageStyle, coverPageStyle != .none {
                    Text("\(CopyDeck.Compose.coverPageToggle): \(coverPageStyle.title) · \(submission.transmittedPageCount) pages will be sent")
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }

                Text(CopyDeck.Compose.retentionDisclosure)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)

                SendPlanPanel(submission: submission, onSent: onSent)
            }
            .padding(16)
        }
        .navigationTitle(CopyDeck.Compose.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", action: onBack)
            }
        }
        .sheet(item: $zoomedPage) { page in
            Image(uiImage: page.image)
                .resizable()
                .scaledToFit()
                .background(Color.black)
        }
    }
}
