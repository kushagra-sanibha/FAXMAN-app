import SwiftUI

struct SettingsRow: View {
    let title: String
    var value: String? = nil
    var showsDisclosure: Bool = true

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.faxitInkPrimary)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
