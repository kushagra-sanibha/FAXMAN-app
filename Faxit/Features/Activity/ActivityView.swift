import QuickLook
import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settingsStore
    @Query(sort: \SentFax.createdAt, order: .reverse) private var sentFaxes: [SentFax]
    @Query(sort: \ReceivedFax.receivedAt, order: .reverse) private var receivedFaxes: [ReceivedFax]
    @Query(sort: \FaxDraft.lastEditedAt, order: .reverse) private var drafts: [FaxDraft]

    @State private var selectedDetailFax: SentFax?
    @State private var resumingDraft: FaxDraft?
    @State private var sendToNumber: String = ""
    @State private var includeCoverPage = false
    @State private var coverPageOverride: CoverPageStyle?
    @State private var coverPageDetails = CoverPageDetails()
    @State private var showTemplatePicker = false

    @State private var importFlow = DocumentImportFlow()
    /// Set when Send is tapped; from then on incomplete numbers are flagged
    /// inline too, not just clearly invalid ones.
    @State private var hasAttemptedSend = false
    @State private var numberIssueAlert: RecipientNumberIssue?
    @State private var newComposePages: [ScannedPage] = []
    @State private var hasAppliedDefaultCoverPage = false
    @State private var isPresentingPaywall = false
    @State private var viewingDocument: ViewingDocument?
    @State private var previewedReportURL: URL?
    @State private var pendingDeletion: PendingDeletion?
    /// The number validated when Send was tapped. The paywall gets this
    /// snapshot, not the live text field, so the number that was checked
    /// is exactly the number that gets charged for and sent.
    @State private var paywallRecipientNumber = ""

    private struct ViewingDocument: Identifiable {
        let id: UUID
        let name: String
    }

    private struct PageDocument: Identifiable {
        let id: UUID
        let name: String
        var pages: [ScannedPage]
    }

    private var recentCount: Int { 5 }

    private var effectiveCoverPageStyle: CoverPageStyle {
        let fallback = settingsStore.settings.defaultCoverPage
        return coverPageOverride ?? (fallback == .none ? .minimal : fallback)
    }

    /// Groups the flat page list back into the documents they were
    /// imported as (one PDF file, one scan session, one photo selection),
    /// preserving the order each document was first added in.
    private var newComposeDocuments: [PageDocument] {
        var order: [UUID] = []
        var grouped: [UUID: PageDocument] = [:]
        for page in newComposePages {
            if grouped[page.documentID] == nil {
                order.append(page.documentID)
                grouped[page.documentID] = PageDocument(id: page.documentID, name: page.documentName, pages: [])
            }
            grouped[page.documentID]?.pages.append(page)
        }
        return order.compactMap { grouped[$0] }
    }

    /// A two-way view onto just one document's pages within the flat
    /// `newComposePages` array — reads filter by documentID; writes splice
    /// the edited sub-array back in at the same position.
    private func pagesBinding(for documentID: UUID) -> Binding<[ScannedPage]> {
        Binding(
            get: { newComposePages.filter { $0.documentID == documentID } },
            set: { updated in
                guard let firstIndex = newComposePages.firstIndex(where: { $0.documentID == documentID }) else {
                    newComposePages.append(contentsOf: updated)
                    return
                }
                newComposePages.removeAll { $0.documentID == documentID }
                newComposePages.insert(contentsOf: updated, at: min(firstIndex, newComposePages.count))
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(CopyDeck.Activity.hero)
                        .font(.faxitHero)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(CopyDeck.Activity.sendToHeader)
                            .font(.faxitSectionHeader)
                            .foregroundStyle(Color.faxitInkPrimary)

                        FaxNumberField(
                            number: $sendToNumber,
                            favorites: FavoriteFaxNumber.from(sentFaxes),
                            onRemoveFavorite: removeFavorite,
                            errorMessage: numberErrorMessage
                        )
                    }

                    ZStack {
                        VStack(spacing: 14) {
                            ActionSectionCard(
                                systemImage: "camera.fill",
                                title: CopyDeck.Activity.scanAction,
                                subtitle: CopyDeck.Activity.scanActionSubtitle,
                                action: { importFlow.beginScan() }
                            )

                            ActionSectionCard(
                                systemImage: "doc.fill",
                                title: CopyDeck.Activity.uploadAction,
                                subtitle: CopyDeck.Activity.uploadActionSubtitle,
                                gradientReversed: true,
                                action: { importFlow.beginUpload() }
                            )
                        }
                        OrSeparatorBadge()
                    }
                    .disabled(importFlow.isImporting)

                    if importFlow.isImporting {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Importing pages…")
                                .font(.faxitCaption)
                                .foregroundStyle(Color.faxitInkSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(CopyDeck.Compose.coverPageToggle, isOn: $includeCoverPage)
                            .tint(.faxitAccent)
                        Text(CopyDeck.Compose.coverPageNote)
                            .font(.faxitCaption)
                            .foregroundStyle(Color.faxitInkSecondary)

                        if includeCoverPage {
                            Button(CopyDeck.Compose.changeTemplate) {
                                Keyboard.dismiss()
                                showTemplatePicker = true
                            }
                            .font(.faxitCaptionSemibold)
                            .foregroundStyle(Color.faxitAccent)

                            CoverPageFormView(style: effectiveCoverPageStyle, recipientNumber: $sendToNumber, details: $coverPageDetails)
                        }
                    }

                    if !newComposeDocuments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionCard {
                                ForEach(Array(newComposeDocuments.enumerated()), id: \.element.id) { index, document in
                                    if index > 0 { Divider().padding(.leading, 16) }
                                    documentRow(document)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Keyboard.dismiss()
                                            viewingDocument = ViewingDocument(id: document.id, name: document.name)
                                        }
                                }
                            }

                            Text("Total Pages: \(newComposePages.count)")
                                .font(.faxitCaption)
                                .foregroundStyle(Color.faxitInkSecondary)

                            Button("Add image or document") { importFlow.beginUpload() }
                                .font(.faxitCaptionSemibold)
                                .foregroundStyle(Color.faxitAccent)

                            Button("Send") { attemptSend() }
                                .buttonStyle(.faxitPrimary)
                        }
                    }

                    if !drafts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CopyDeck.Activity.draftsHeader)
                                .font(.faxitSectionHeader)
                                .foregroundStyle(Color.faxitInkPrimary)

                            SectionCard {
                                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                                    if index > 0 { Divider().padding(.leading, 16) }
                                    draftRow(draft)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Keyboard.dismiss()
                                            resumingDraft = draft
                                        }
                                }
                            }

                            Text(CopyDeck.Activity.draftsFooter)
                                .font(.faxitCaption)
                                .foregroundStyle(Color.faxitInkSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(CopyDeck.Activity.recentFaxesHeader)
                            .font(.faxitSectionHeader)
                            .foregroundStyle(Color.faxitInkPrimary)

                        if sentFaxes.isEmpty && receivedFaxes.isEmpty {
                            Text(CopyDeck.Activity.emptyState)
                                .font(.faxitCaption)
                                .foregroundStyle(Color.faxitInkSecondary)
                                .padding(.vertical, 8)
                        } else {
                            SectionCard {
                                ForEach(Array(sentFaxes.prefix(recentCount).enumerated()), id: \.element.id) { index, fax in
                                    if index > 0 { Divider().padding(.leading, 16) }
                                    RecentFaxRow(
                                        title: PhoneNumberFormatter.displayString(fax.recipientNumber),
                                        subtitle: "\(fax.pageCount) page\(fax.pageCount == 1 ? "" : "s") · \(fax.createdAt.formatted(date: .abbreviated, time: .shortened))",
                                        status: fax.status,
                                        isFavorite: fax.isFavorite,
                                        onShowReport: { showDeliveryReport(for: fax) },
                                        onToggleFavorite: { toggleFavorite(fax) },
                                        onShowStatus: { selectedDetailFax = fax }
                                    )
                                    .contentShape(Rectangle())
                                    // Opaque so the row slides over its swipe actions cleanly.
                                    .background(Color.faxitCardBackground)
                                    .onTapGesture {
                                        Keyboard.dismiss()
                                        selectedDetailFax = fax
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        // Only finished faxes: one still sending is being read
                                        // by the send runner and can't be pulled out from under it.
                                        if fax.status.isTerminal {
                                            Button {
                                                confirmDelete(fax)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            // Not `role: .destructive`, which would animate the row
                                            // away before the user confirms.
                                            .tint(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.faxitMintBackground)
            // Phone pads have no Done key: scrolling or the toolbar button
            // above the keyboard puts it away.
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            // Lets Recent faxes rows use swipe actions outside a List: one
            // open row at a time, closed on scroll or tap elsewhere.
            .swipeActionsContainer()
            .navigationDestination(item: $selectedDetailFax) { fax in
                FaxDetailView(fax: fax)
            }
            .sheet(item: $resumingDraft) { draft in
                NewFaxComposeView(draft: draft, onRecipientNumberChanged: { sendToNumber = $0 })
            }
            .sheet(isPresented: $showTemplatePicker) {
                NavigationStack {
                    CoverPageTemplatePickerView(
                        selection: Binding(
                            get: { effectiveCoverPageStyle },
                            set: { coverPageOverride = $0 }
                        ),
                        title: CopyDeck.Settings.defaultCoverPage,
                        caption: CopyDeck.Settings.defaultCoverPageCaption
                    )
                }
            }
            .sheet(item: $viewingDocument) { document in
                DocumentPagesEditorView(pages: pagesBinding(for: document.id), title: document.name)
            }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallView(
                    pages: newComposePages,
                    recipientNumber: paywallRecipientNumber,
                    coverPageStyle: includeCoverPage ? effectiveCoverPageStyle : nil,
                    coverPageDetails: coverPageDetails,
                    onSent: { _ in
                        newComposePages = []
                        coverPageDetails = CoverPageDetails()
                    }
                )
            }
            .alert(
                numberIssueAlert.map { CopyDeck.Compose.numberIssueTitle($0) } ?? "",
                isPresented: Binding(get: { numberIssueAlert != nil }, set: { if !$0 { numberIssueAlert = nil } }),
                presenting: numberIssueAlert
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { issue in
                Text(CopyDeck.Compose.numberIssueMessage(issue))
            }
            .onChange(of: sendToNumber) {
                if PhoneNumberFormatter.recipientIssue(sendToNumber) == nil { hasAttemptedSend = false }
            }
            .documentImport(importFlow) { newComposePages.append(contentsOf: $0) }
            .quickLookPreview($previewedReportURL)
            .deleteConfirmation($pendingDeletion)
            .onAppear {
                // The Settings "Default cover page" choice now actually
                // pre-enables the cover page instead of only picking which
                // template appears once someone flips the toggle.
                guard !hasAppliedDefaultCoverPage else { return }
                hasAppliedDefaultCoverPage = true
                includeCoverPage = settingsStore.settings.defaultCoverPage != .none
            }
        }
    }

    /// Regenerated on every tap so the report always reflects the fax's
    /// current status (e.g. a retry that has since been delivered).
    private func showDeliveryReport(for fax: SentFax) {
        guard let url = DeliveryReportGenerator.generate(for: fax) else { return }
        fax.deliveryReportFileURL = url
        try? modelContext.save()
        previewedReportURL = url
    }

    /// Un-hearts every sent fax to that number, so it leaves the list.
    private func removeFavorite(_ favorite: FavoriteFaxNumber) {
        for fax in sentFaxes where String(fax.recipientNumber.filter(\.isNumber).suffix(10)) == favorite.id {
            fax.isFavorite = false
        }
        try? modelContext.save()
    }

    private func toggleFavorite(_ fax: SentFax) {
        fax.isFavorite.toggle()
        try? modelContext.save()
    }

    /// Clearly invalid numbers are flagged as soon as they're typed; ones
    /// still being typed only after a Send attempt.
    private var numberErrorMessage: String? {
        guard let issue = PhoneNumberFormatter.recipientIssue(sendToNumber) else { return nil }
        guard hasAttemptedSend || !issue.isStillTyping else { return nil }
        return CopyDeck.Compose.numberIssueMessage(issue)
    }

    private func attemptSend() {
        Keyboard.dismiss()
        if let issue = PhoneNumberFormatter.recipientIssue(sendToNumber) {
            hasAttemptedSend = true
            numberIssueAlert = issue
            return
        }
        paywallRecipientNumber = sendToNumber
        isPresentingPaywall = true
    }

    private func documentRow(_ document: PageDocument) -> some View {
        HStack(spacing: 12) {
            if let firstPage = document.pages.first {
                Image(uiImage: firstPage.image)
                    .resizable()
                    .aspectRatio(0.77, contentMode: .fill)
                    .frame(width: 44, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.faxitInkSecondary.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.faxitBodySemibold)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .lineLimit(1)
                Text("\(document.pages.count) page\(document.pages.count == 1 ? "" : "s")")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }

            Spacer()

            Button(role: .destructive) {
                pendingDeletion = PendingDeletion(
                    title: "Delete “\(document.name)”?",
                    message: "Its \(document.pages.count) page\(document.pages.count == 1 ? "" : "s") will be removed from this fax."
                ) {
                    newComposePages.removeAll { $0.documentID == document.id }
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.faxitInkSecondary)
            }

            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(Color.faxitAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func draftRow(_ draft: FaxDraft) -> some View {
        let numberText = draft.recipientNumberRaw.isEmpty
            ? "No number yet"
            : PhoneNumberFormatter.displayString(draft.recipientNumberRaw)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(numberText)
                    .font(.faxitBodySemibold)
                    .foregroundStyle(Color.faxitInkPrimary)
                Text("\(draft.pageCount) page\(draft.pageCount == 1 ? "" : "s") · \(draft.lastEditedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Spacer()
            Button(role: .destructive) {
                pendingDeletion = PendingDeletion(
                    title: "Delete this saved fax?",
                    message: "Its pages are removed from this iPhone. This can't be undone."
                ) {
                    deleteDraft(draft)
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func confirmDelete(_ fax: SentFax) {
        pendingDeletion = PendingDeletion(
            title: "Delete this fax?",
            message: "The fax to \(PhoneNumberFormatter.displayString(fax.recipientNumber)) and its delivery report are removed from this iPhone. This can't be undone."
        ) {
            deleteSentFax(fax)
        }
    }

    /// Removes the record plus everything stored for it on disk — page
    /// images and the generated delivery report — not just the list row.
    private func deleteSentFax(_ fax: SentFax) {
        PageFileStore.delete(fileNames: fax.pageImageFileNames)
        if let report = fax.deliveryReportFileURL {
            try? FileManager.default.removeItem(at: report)
        }
        if selectedDetailFax?.id == fax.id { selectedDetailFax = nil }
        modelContext.delete(fax)
        try? modelContext.save()
    }

    private func deleteDraft(_ draft: FaxDraft) {
        PageFileStore.delete(fileNames: draft.pageImageFileNames)
        modelContext.delete(draft)
        try? modelContext.save()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: SentFax.self, ReceivedFax.self, FaxDraft.self, AppSettingsModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // Sample history so the Recent faxes rows are visible in the canvas.
    let delivered = SentFax(recipientNumber: "5551234567", pageCount: 3, status: .delivered, documentContentHash: "a")
    delivered.isFavorite = true
    container.mainContext.insert(delivered)
    container.mainContext.insert(SentFax(recipientNumber: "(555) 123-0188", pageCount: 1, status: .notDelivered(reason: .noAnswer), documentContentHash: "b"))
    return ActivityView()
        .environment(AppSettingsStore(modelContext: container.mainContext))
        .environment(StoreManager())
        .modelContainer(container)
}
