import SwiftUI

/// Step 2 of compose: edit the captured pages — reorder by deleting and
/// re-adding, fix flagged pages, add a cover page, or add more pages before
/// moving on to the recipient number.
struct EditPagesStepView: View {
    @Binding var pages: [ScannedPage]
    @Binding var coverPageStyle: CoverPageStyle?
    @Binding var coverPageDetails: CoverPageDetails
    @Binding var recipientNumber: String
    let onNext: () -> Void
    let onBack: () -> Void

    @Environment(AppSettingsStore.self) private var settingsStore
    @State private var editingPage: EditingPage?
    @State private var showTemplatePicker = false
    @State private var pendingDeletion: PendingDeletion?

    private struct EditingPage: Identifiable {
        let id: UUID
    }

    private var effectiveDefaultStyle: CoverPageStyle {
        let fallback = settingsStore.settings.defaultCoverPage
        return fallback == .none ? .minimal : fallback
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(CopyDeck.Compose.editDocumentPrompt)
                    .font(.faxitHero)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .padding(.top, 8)

                PageThumbnailGrid(pages: $pages, onTapPage: {
                    Keyboard.dismiss()
                    editingPage = EditingPage(id: $0.id)
                })

                if !pages.isEmpty {
                    Text("Tap a page to crop, rotate or change its filter.")
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }

                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    if page.isFlaggedDarkOrLight, let issue = page.brightnessIssue {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page \(index + 1)")
                                .font(.faxitCaptionSemibold)
                                .foregroundStyle(Color.faxitInkSecondary)
                            AmberWarningBadge(
                                issue: issue,
                                canFix: page.canFixBrightness,
                                onRemove: {
                                    pendingDeletion = PendingDeletion(title: "Delete page \(index + 1)?", message: "It won't be included in this fax.") {
                                        pages.removeAll { $0.id == page.id }
                                    }
                                },
                                onFix: { edit(page) { $0.fixBrightness() } },
                                onKeepAsIs: { edit(page) { $0.dismissWarning() } }
                            )
                        }
                    }
                }

                DocumentCaptureControls(
                    scanLabel: CopyDeck.Compose.addMoreScan,
                    fileLabel: CopyDeck.Compose.addMoreFile,
                    onPagesAdded: { pages.append(contentsOf: $0) }
                )

                Toggle(CopyDeck.Compose.coverPageToggle, isOn: Binding(
                    get: { coverPageStyle != nil },
                    set: { coverPageStyle = $0 ? effectiveDefaultStyle : nil }
                ))
                .tint(.faxitAccent)
                Text(CopyDeck.Compose.coverPageNote)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)

                if let coverPageStyle {
                    Button(CopyDeck.Compose.changeTemplate) {
                        Keyboard.dismiss()
                        showTemplatePicker = true
                    }
                    .font(.faxitCaptionSemibold)
                    .foregroundStyle(Color.faxitAccent)

                    CoverPageFormView(style: coverPageStyle, recipientNumber: $recipientNumber, details: $coverPageDetails)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Back", action: onBack)
                        .buttonStyle(.faxitSecondary)
                    Button("Next") {
                        Keyboard.dismiss()
                        onNext()
                    }
                        .buttonStyle(.faxitPrimary)
                        .disabled(pages.isEmpty)
                        .opacity(pages.isEmpty ? 0.5 : 1)
                }
            }
            .padding(16)
        }
        // The cover page form has a phone-pad field and free-text fields.
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .deleteConfirmation($pendingDeletion)
        .sheet(item: $editingPage) { page in
            DocumentPagesEditorView(pages: $pages, title: "Pages", initialPageID: page.id)
        }
        .sheet(isPresented: $showTemplatePicker) {
            NavigationStack {
                CoverPageTemplatePickerView(
                    selection: Binding(
                        get: { coverPageStyle ?? effectiveDefaultStyle },
                        set: { coverPageStyle = $0 }
                    ),
                    title: CopyDeck.Settings.defaultCoverPage,
                    caption: CopyDeck.Settings.defaultCoverPageCaption
                )
            }
        }
    }

    private func edit(_ page: ScannedPage, _ change: (inout ScannedPage) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        change(&pages[index])
    }
}
