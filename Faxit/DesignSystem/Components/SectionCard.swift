import SwiftUI

/// The rounded card container used for list rows throughout (Activity's
/// recent list, Inbox rows, Settings rows).
struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
