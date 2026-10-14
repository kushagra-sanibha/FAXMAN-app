import SwiftUI

struct ReceivedFaxRowView: View {
    let sender: String
    let subtitle: String
    let isRead: Bool
    let onView: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sender)
                    .font(isRead ? .faxitBody : .faxitBodySemibold)
                    .foregroundStyle(Color.faxitInkPrimary)
                Text(subtitle)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Spacer()
            Button(CopyDeck.Inbox.viewAction, action: onView)
                .font(.faxitCaptionSemibold)
                .foregroundStyle(Color.faxitAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
