import SwiftUI

struct StatPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.faxitCaptionSemibold)
            .foregroundStyle(Color.faxitAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.faxitAccent.opacity(0.12))
            .clipShape(Capsule())
    }
}
