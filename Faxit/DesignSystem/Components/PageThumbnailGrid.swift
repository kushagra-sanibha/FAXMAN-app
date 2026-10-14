import SwiftUI

/// Thumbnails with delete; the amber badge is a warning only, never a block.
struct PageThumbnailGrid: View {
    @Binding var pages: [ScannedPage]
    var onTapPage: ((ScannedPage) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 10)]
    @State private var pendingDeletion: PendingDeletion?

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(pages) { page in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: page.image)
                        .resizable()
                        .aspectRatio(0.77, contentMode: .fill)
                        .frame(width: 84, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.faxitInkSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onTapPage?(page) }

                    if page.isFlaggedDarkOrLight {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.faxitCaption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.faxitStatusAmber)
                            .clipShape(Circle())
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .allowsHitTesting(false)
                    }

                    Button {
                        let number = (pages.firstIndex(of: page) ?? 0) + 1
                        pendingDeletion = PendingDeletion(title: "Delete page \(number)?", message: "It won't be included in this fax.") {
                            pages.removeAll { $0.id == page.id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.faxitCaption)
                            .foregroundStyle(.white, Color.black.opacity(0.6))
                    }
                    .padding(2)
                    .offset(x: 6, y: -6)
                    .accessibilityLabel("Remove page")
                }
                .frame(width: 84, height: 108)
            }
        }
        .deleteConfirmation($pendingDeletion)
    }
}
