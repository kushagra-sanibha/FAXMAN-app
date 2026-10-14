import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settingsStore
    @Query(sort: \ReceivedFax.receivedAt, order: .reverse) private var receivedFaxes: [ReceivedFax]

    @State private var searchText = ""
    @State private var selectedFax: ReceivedFax?
    private var filtered: [ReceivedFax] {
        guard !searchText.isEmpty else { return receivedFaxes }
        return receivedFaxes.filter {
            ($0.senderNumberIfAvailable ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var countThisMonth: Int {
        let calendar = Calendar.current
        return receivedFaxes.filter { calendar.isDate($0.receivedAt, equalTo: .now, toGranularity: .month) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(CopyDeck.Inbox.header)
                        .font(.faxitHero)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .padding(.top, 8)

                    // No "Get your own fax number" promo here — that lives in
                    // the Receive tab. Once there's a number, show it.
                    if let number = settingsStore.settings.ownFaxNumber {
                        OwnFaxNumberHeaderView(number: number, onGetNumber: {})
                    }

                    StatPill(text: "\(countThisMonth) \(CopyDeck.Inbox.statPillSuffix)")

                    SearchField(text: $searchText, placeholder: CopyDeck.Inbox.searchPlaceholder)

                    HStack {
                        Text(CopyDeck.Inbox.listHeader)
                            .font(.faxitCaptionSemibold)
                            .foregroundStyle(Color.faxitInkSecondary)
                        Spacer()
                        ShareLink(items: filtered.map(\.pdfFileURL)) {
                            Text(CopyDeck.Inbox.exportButton)
                        }
                        .font(.faxitCaptionSemibold)
                        .disabled(filtered.isEmpty)
                    }

                    if filtered.isEmpty {
                        Text(CopyDeck.Inbox.emptyState)
                            .font(.faxitCaption)
                            .foregroundStyle(Color.faxitInkSecondary)
                    } else {
                        SectionCard {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, fax in
                                if index > 0 { Divider().padding(.leading, 16) }
                                ReceivedFaxRowView(
                                    sender: fax.senderNumberIfAvailable.map(PhoneNumberFormatter.displayString) ?? "Unknown sender",
                                    subtitle: "\(fax.pageCount) page\(fax.pageCount == 1 ? "" : "s") · \(fax.receivedAt.formatted(date: .abbreviated, time: .shortened))",
                                    isRead: fax.isRead,
                                    onView: { selectedFax = fax }
                                )
                            }
                        }
                    }

                    Text(CopyDeck.Inbox.privacyNote)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
                .padding(16)
            }
            .background(Color.faxitMintBackground)
            .navigationDestination(item: $selectedFax) { fax in
                ReceivedFaxDetailView(fax: fax)
            }
            .task {
                await loadReceivedFaxes()
            }
        }
    }

    private func loadReceivedFaxes() async {
        // Ask only for faxes newer than what's already stored — always
        // passing nil re-fetched (and re-inserted) the full history on
        // every launch, duplicating the whole inbox each time.
        let since = receivedFaxes.map(\.receivedAt).max()
        guard let payloads = try? await FaxProviderContainer.shared.fetchReceivedFaxes(since: since) else { return }
        for payload in payloads {
            let fax = ReceivedFax(
                senderNumberIfAvailable: payload.senderNumberIfAvailable,
                receivedAt: payload.receivedAt,
                pageCount: payload.pageCount,
                pdfFileURL: payload.pdfFileURL
            )
            modelContext.insert(fax)
        }
        try? modelContext.save()
    }
}
