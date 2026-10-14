import SwiftUI
import SwiftData

enum ComposeStep: Hashable {
    case edit
    case recipient
    case review
}

/// Always has a visible close (X) — never a hard paywall, never blocks
/// preparing a fax. Payment only happens from ReviewSendView.
///
/// Flow: edit pages -> enter the recipient's number -> review and send.
/// Scanning/uploading happens before this view is even presented (the home
/// screen's Scan/Upload cards launch the camera or file picker directly) —
/// this view only opens once at least one page exists. At any point after
/// a page exists, "Save for later" writes the draft to disk (PageFileStore)
/// only — it is never transmitted anywhere until the draft is resumed and
/// actually sent.
struct NewFaxComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State var step: ComposeStep
    @State private var recipientNumber: String
    @State private var pages: [ScannedPage]
    @State private var coverPageStyle: CoverPageStyle?
    @State private var coverPageDetails: CoverPageDetails
    @State private var sentFax: SentFax?
    @State private var existingDraftID: UUID?
    @State private var showSaveConfirmation = false
    var onRecipientNumberChanged: (String) -> Void = { _ in }

    init(
        initialPages: [ScannedPage] = [],
        initialStep: ComposeStep = .edit,
        initialRecipientNumber: String = "",
        initialCoverPageStyle: CoverPageStyle? = nil,
        initialCoverPageDetails: CoverPageDetails = CoverPageDetails(),
        onRecipientNumberChanged: @escaping (String) -> Void = { _ in }
    ) {
        _step = State(initialValue: initialStep)
        _recipientNumber = State(initialValue: initialRecipientNumber)
        _pages = State(initialValue: initialPages)
        _coverPageStyle = State(initialValue: initialCoverPageStyle)
        _coverPageDetails = State(initialValue: initialCoverPageDetails)
        _existingDraftID = State(initialValue: nil)
        self.onRecipientNumberChanged = onRecipientNumberChanged
    }

    /// Resumes a fax someone scanned/uploaded earlier and chose to finish later.
    init(draft: FaxDraft, onRecipientNumberChanged: @escaping (String) -> Void = { _ in }) {
        _step = State(initialValue: .edit)
        _recipientNumber = State(initialValue: draft.recipientNumberRaw)
        _pages = State(initialValue: PageFileStore.loadDraftPages(forDraftID: draft.id, fileNames: draft.pageImageFileNames))
        _coverPageStyle = State(initialValue: draft.coverPageStyle)
        _coverPageDetails = State(initialValue: draft.coverPageDetails)
        _existingDraftID = State(initialValue: draft.id)
        self.onRecipientNumberChanged = onRecipientNumberChanged
    }

    private var canSaveForLater: Bool { !pages.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .edit:
                    EditPagesStepView(
                        pages: $pages,
                        coverPageStyle: $coverPageStyle,
                        coverPageDetails: $coverPageDetails,
                        recipientNumber: $recipientNumber,
                        onNext: { step = .recipient },
                        onBack: { dismiss() }
                    )
                case .recipient:
                    RecipientNumberStepView(recipientNumber: $recipientNumber, onNext: { step = .review }, onBack: { step = .edit })
                case .review:
                    ReviewSendView(
                        pages: $pages,
                        coverPageStyle: $coverPageStyle,
                        coverPageDetails: coverPageDetails,
                        recipientNumber: recipientNumber,
                        onBack: { step = .recipient },
                        onSent: { fax in
                            if let existingDraftID {
                                deleteDraft(id: existingDraftID)
                            }
                            sentFax = fax
                        }
                    )
                }
            }
            .background(Color.faxitMintBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                if canSaveForLater {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(CopyDeck.Compose.saveForLaterButton) {
                            showSaveConfirmation = true
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            CopyDeck.Compose.saveForLaterConfirmTitle,
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button(CopyDeck.Compose.saveForLaterConfirmAction) { saveDraftForLater() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(CopyDeck.Compose.saveForLaterConfirmMessage)
        }
        .fullScreenCover(item: $sentFax) { fax in
            SendingStatusView(fax: fax, provider: FaxProviderContainer.shared, onDone: {
                dismiss()
            })
        }
        .onChange(of: recipientNumber) { _, newValue in
            onRecipientNumberChanged(newValue)
        }
    }

    /// Persists pages/number/cover choice to local disk via PageFileStore —
    /// purely on-device storage, nothing sent to the fax provider.
    private func saveDraftForLater() {
        guard canSaveForLater else { return }
        let draftID = existingDraftID ?? UUID()

        if let existingDraftID,
           let existing = fetchDraft(id: existingDraftID) {
            PageFileStore.delete(fileNames: existing.pageImageFileNames)
            existing.pageImageFileNames = PageFileStore.saveDraft(pages, draftID: draftID)
            existing.recipientNumberRaw = recipientNumber
            existing.coverPageStyle = coverPageStyle
            existing.coverPageDetails = coverPageDetails
            existing.lastEditedAt = .now
        } else {
            let fileNames = PageFileStore.saveDraft(pages, draftID: draftID)
            let draft = FaxDraft(
                id: draftID,
                recipientNumberRaw: recipientNumber,
                pageImageFileNames: fileNames,
                coverPageStyle: coverPageStyle,
                coverPageDetails: coverPageDetails
            )
            modelContext.insert(draft)
        }
        try? modelContext.save()
        self.existingDraftID = draftID
        dismiss()
    }

    private func fetchDraft(id: UUID) -> FaxDraft? {
        let descriptor = FetchDescriptor<FaxDraft>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func deleteDraft(id: UUID) {
        guard let draft = fetchDraft(id: id) else { return }
        PageFileStore.delete(fileNames: draft.pageImageFileNames)
        modelContext.delete(draft)
        try? modelContext.save()
    }
}
