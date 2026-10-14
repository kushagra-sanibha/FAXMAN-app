import SwiftUI

struct OwnFaxNumberHeaderView: View {
    let number: String?
    let onGetNumber: () -> Void

    var body: some View {
        if let number {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your fax number")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                Text(number)
                    .font(.faxitPrice)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
        } else {
            PromoCard(
                title: CopyDeck.Inbox.noNumberCTA,
                actionTitle: CopyDeck.Activity.promoAction,
                action: onGetNumber
            )
        }
    }
}
