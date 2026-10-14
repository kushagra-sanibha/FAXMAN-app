import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.faxitInkSecondary)
            TextField(placeholder, text: $text)
                .font(.faxitBody)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
