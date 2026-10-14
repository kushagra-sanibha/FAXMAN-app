import SwiftUI

struct PromoCard: View {
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "number")
                .font(.faxitTitle2)
                .foregroundStyle(.white)
            Text(title)
                .font(.faxitSectionHeader)
                .foregroundStyle(.white)
            Button(action: action) {
                Text(actionTitle)
                    .font(.faxitBodySemibold)
                    .foregroundStyle(Color.faxitNavyBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.faxitNavyBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
