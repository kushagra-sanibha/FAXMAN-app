import SwiftUI

/// Visual thumbnail for a cover page template, sized for use as a selectable
/// tile (Settings default picker, per-fax override picker, home screen preview).
/// There is no full-size cover page renderer in the app yet — this is the only
/// place `CoverPageStyle` gets drawn rather than just labeled as text.
struct CoverPageTemplateView: View {
    let style: CoverPageStyle

    var body: some View {
        VStack(spacing: 0) {
            if style == .none {
                Spacer()
                Text("No cover page")
                    .font(.faxit(size: 11))
                    .foregroundStyle(Color.faxitInkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                Spacer()
            } else {
                header
                fields
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.faxitInkSecondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: style == .none ? [4, 3] : [])
                )
        )
    }

    @ViewBuilder
    private var header: some View {
        switch style {
        case .none:
            EmptyView()
        case .minimal:
            HStack {
                Text("Fax")
                    .font(.faxit(size: 13, weight: .bold))
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer()
            }
            .padding(8)
        case .professional:
            HStack {
                Text("FAX")
                    .font(.faxit(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("1 PAGE")
                    .font(.faxit(size: 7, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(8)
            .background(Color.faxitNavyBackground)
        case .confidential:
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.faxit(size: 9))
                    .foregroundStyle(Color.faxitStatusAmber)
                Text("CONFIDENTIAL")
                    .font(.faxit(size: 9, weight: .bold))
                    .foregroundStyle(Color.faxitStatusAmber)
                Spacer()
            }
            .padding(8)
            .background(Color.faxitStatusAmber.opacity(0.12))
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLine("Recipient number")
            fieldLine("To")
            fieldLine("From")
            fieldLine("Subject")

            HStack(spacing: 8) {
                checkbox("Urgent")
                checkbox("Reply")
            }

            Text("Comments…")
                .font(.faxit(size: 8))
                .foregroundStyle(Color.faxitInkSecondary.opacity(0.7))

            Spacer(minLength: 0)

            Text("faxit")
                .font(.faxit(size: 8, weight: .semibold))
                .foregroundStyle(Color.faxitInkSecondary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func fieldLine(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.faxit(size: 8))
                .foregroundStyle(Color.faxitInkSecondary)
            Rectangle()
                .fill(Color.faxitInkSecondary.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func checkbox(_ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.faxitInkSecondary, lineWidth: 1)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.faxit(size: 7))
                .foregroundStyle(Color.faxitInkSecondary)
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 14) {
        ForEach(CoverPageStyle.allCases) { style in
            CoverPageTemplateView(style: style)
                .frame(width: 130, height: 164)
        }
    }
    .padding()
    .background(Color.faxitMintBackground)
}
