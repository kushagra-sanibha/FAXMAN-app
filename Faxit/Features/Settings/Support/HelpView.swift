import SwiftUI

/// Bundled help articles (see `HelpArticles`) — fully offline.
struct HelpView: View {
    @State private var query = ""

    private var filteredSections: [HelpSection] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return HelpArticles.sections }
        return HelpArticles.sections.compactMap { section in
            let matches = section.articles.filter { article in
                article.title.localizedCaseInsensitiveContains(q)
                    || article.paragraphs.contains { $0.localizedCaseInsensitiveContains(q) }
            }
            return matches.isEmpty ? nil : HelpSection(id: section.id, title: section.title, articles: matches)
        }
    }

    var body: some View {
        let sections = filteredSections
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.articles) { article in
                        NavigationLink(article.title) { HelpArticleView(article: article) }
                            .font(.faxitBody)
                            .foregroundStyle(Color.faxitInkPrimary)
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label(CopyDeck.Support.noResultsTitle, systemImage: "magnifyingglass")
                } description: {
                    Text(CopyDeck.Support.noResultsMessage)
                } actions: {
                    NavigationLink(CopyDeck.Support.contactUs) { ContactUsView() }
                        .buttonStyle(.faxitPrimary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.faxitMintBackground)
        .navigationTitle(CopyDeck.Support.helpTitle)
        .searchable(text: $query, prompt: CopyDeck.Support.searchPrompt)
    }
}
