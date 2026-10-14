import SwiftUI
import StoreKit

struct HelpArticleView: View {
    let article: HelpArticle
    @State private var showManageSubscriptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.faxitHero)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(article.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if article.showsManageSubscriptions {
                    Button(CopyDeck.Support.openSubscriptions) { showManageSubscriptions = true }
                        .buttonStyle(.faxitPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(CopyDeck.Support.stillStuck)
                        .font(.faxitSectionHeader)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(CopyDeck.Support.stillStuckMessage)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                    NavigationLink { ContactUsView() } label: {
                        Text(CopyDeck.Support.contactUs).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.faxitSecondary)
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .background(Color.faxitMintBackground)
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }
}
