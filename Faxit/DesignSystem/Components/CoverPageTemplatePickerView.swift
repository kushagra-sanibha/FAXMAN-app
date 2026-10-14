import SwiftUI

/// Grid of selectable cover page templates. Used both for choosing the
/// account-wide default (Settings) and for overriding it on a single fax
/// (home screen, compose flow) — the caller decides what `selection` writes to.
struct CoverPageTemplatePickerView: View {
    @Binding var selection: CoverPageStyle
    let title: String
    let caption: String

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(CoverPageStyle.allCases) { style in
                        Button {
                            selection = style
                        } label: {
                            CoverPageTemplateView(style: style)
                                .frame(height: 164)
                                .overlay(alignment: .topTrailing) {
                                    if selection == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.faxitAccent, .white)
                                            .padding(6)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(selection == style ? Color.faxitAccent : .clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(caption)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            .padding(16)
        }
        .background(Color.faxitMintBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Image(systemName: "checkmark") }
            }
        }
    }
}
