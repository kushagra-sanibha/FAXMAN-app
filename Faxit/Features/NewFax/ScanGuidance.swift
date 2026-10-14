import SwiftUI

/// Shown before a scan the first time, and again after a scan came back tilted.
struct ScanTipsSheet: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(CopyDeck.Scan.tipsTitle)
                .font(.faxitHero)
                .foregroundStyle(Color.faxitInkPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(CopyDeck.Scan.tips, id: \.title) { tip in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: tip.symbol)
                            .font(.faxitTitle3)
                            .foregroundStyle(Color.faxitAccent)
                            .frame(width: 32)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.faxitSectionHeader)
                                .foregroundStyle(Color.faxitInkPrimary)
                            Text(tip.detail)
                                .font(.faxitBody)
                                .foregroundStyle(Color.faxitInkSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer(minLength: 0)

            Button(CopyDeck.Scan.tipsContinue, action: onContinue)
                .buttonStyle(.faxitPrimary)
        }
        .padding(24)
        .background(Color.faxitMintBackground.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
