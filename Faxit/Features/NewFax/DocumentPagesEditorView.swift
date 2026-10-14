import SwiftUI

/// Full-screen slideshow for one document's pages — swipe through pages,
/// with the same tools the system document scanner's own edit screen
/// offers: Adjust (perspective crop), Filters, Rotate, Delete, plus the
/// brightness fix. Works identically for scans, photos, image files and
/// PDF pages, since they're all the same `ScannedPage` underneath.
struct DocumentPagesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pages: [ScannedPage]
    let title: String
    var initialPageID: UUID? = nil

    @State private var selectedPageID: UUID?
    @State private var cropTarget: CropTarget?
    @State private var showSignatureOptions = false
    /// The page Sign was tapped on, so the signature lands on that page.
    @State private var signingPageID: UUID?
    @State private var signTarget: SignTarget?
    @State private var showFilterOptions = false
    /// The Darker slider's position while dragging; applied in full on release.
    @State private var faxLevelDraft: Double?
    /// Live preview while dragging: the current page re-rendered at the
    /// slider's level from a smaller copy, so it keeps up with the finger.
    @State private var faxLevelPreview: (pageID: UUID, image: UIImage)?
    /// That smaller copy (tone already applied), made once per drag.
    @State private var faxPreviewSource: (pageID: UUID, image: UIImage)?
    @State private var isRenderingFaxPreview = false
    @State private var cropFailedAlert = false
    @State private var pendingDeletion: PendingDeletion?

    private struct CropTarget: Identifiable {
        let id: UUID
    }

    private struct SignTarget: Identifiable {
        let id = UUID()
        let pageID: UUID
        let signature: UIImage
    }

    private var currentPageIndex: Int? {
        guard let selectedPageID else { return nil }
        return pages.firstIndex { $0.id == selectedPageID }
    }

    private var currentPage: ScannedPage? {
        currentPageIndex.map { pages[$0] }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPageID) {
                ForEach(pages) { page in
                    Image(uiImage: faxLevelPreview?.pageID == page.id ? faxLevelPreview!.image : page.image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .tag(Optional(page.id))
                        .accessibilityLabel("Page \((pages.firstIndex(of: page) ?? 0) + 1)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
            .background(Color.black)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Done")
                }
                if let index = currentPageIndex, pages.count > 1 {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(title).font(.faxitBodySemibold).lineLimit(1)
                            Text("Page \(index + 1) of \(pages.count)")
                                .font(.faxitCaption)
                                .foregroundStyle(Color.faxitInkSecondary)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomPanel
            }
        }
        .onAppear {
            if selectedPageID == nil {
                selectedPageID = initialPageID.flatMap { id in pages.first { $0.id == id }?.id } ?? pages.first?.id
            }
        }
        .onChange(of: pages.count) { _, newCount in
            if newCount == 0 {
                dismiss()
            } else if currentPageIndex == nil {
                selectedPageID = pages.first?.id
            }
        }
        .fullScreenCover(item: $cropTarget) { target in
            if let page = pages.first(where: { $0.id == target.id }) {
                CropView(
                    image: page.baseImage,
                    // A tilted scan starts from its detected page edges, like an uploaded photo.
                    detectsEdges: page.source.suggestsEdgeDetection || page.tiltCorrection != nil,
                    onCancel: { cropTarget = nil },
                    onCrop: { quad in
                        cropTarget = nil
                        edit(pageID: target.id) { page in
                            if !page.crop(to: quad) { cropFailedAlert = true }
                        }
                    }
                )
            }
        }
        .signatureAcquisition(isPresented: $showSignatureOptions) { signature in
            if let pageID = signingPageID {
                signTarget = SignTarget(pageID: pageID, signature: signature)
            }
        }
        .fullScreenCover(item: $signTarget) { target in
            if let page = pages.first(where: { $0.id == target.pageID }) {
                SignaturePlacementView(
                    pageImage: page.image,
                    signature: target.signature,
                    onCancel: { signTarget = nil },
                    onPlace: { signature, rect in
                        signTarget = nil
                        edit(pageID: target.pageID) { $0.addSignature(signature, in: rect) }
                    }
                )
            }
        }
        .deleteConfirmation($pendingDeletion)
        .alert("Couldn't crop this page", isPresented: $cropFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try dragging the corners so they outline the page.")
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if let page = currentPage, page.isFlaggedDarkOrLight, let issue = page.brightnessIssue {
                AmberWarningBadge(
                    issue: issue,
                    canFix: page.canFixBrightness,
                    onRemove: confirmDeleteCurrentPage,
                    onFix: { editCurrent { $0.fixBrightness() } },
                    onKeepAsIs: { editCurrent { $0.dismissWarning() } }
                )
                .background(Color.faxitCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            if let page = currentPage, page.showsStraightenedNotice {
                StraightenedNoticeBadge(
                    onUndo: { editCurrent { $0.undoStraighten() } },
                    onKeep: { editCurrent { $0.acceptStraighten() } }
                )
                .background(Color.faxitCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 10)
            } else if let page = currentPage, page.isFlaggedTilted {
                TiltWarningBadge(
                    onAdjust: { if let id = selectedPageID { cropTarget = CropTarget(id: id) } },
                    onKeepAsIs: { editCurrent { $0.dismissTiltWarning() } }
                )
                .background(Color.faxitCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            if showFilterOptions, let page = currentPage {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        ForEach(PageFilter.allCases, id: \.self) { filter in
                            let isSelected = page.filter == filter
                            Button(filter.label) { editCurrent { $0.setFilter(filter) } }
                                .font(.faxitCaptionSemibold)
                                .foregroundStyle(isSelected ? Color.white : Color.faxitInkPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.faxitAccent : Color.faxitMintBackground)
                                .clipShape(Capsule())
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    if page.filter == .blackAndWhite {
                        faxLevelSlider(for: page)
                    }
                }
                .padding(.vertical, 10)
            }

            HStack {
                toolbarButton(label: "Adjust", systemImage: "crop") {
                    if let id = selectedPageID { cropTarget = CropTarget(id: id) }
                }
                Spacer()
                toolbarButton(label: "Filters", systemImage: "circle.lefthalf.filled") {
                    showFilterOptions.toggle()
                }
                Spacer()
                Menu {
                    Button("Rotate left", systemImage: "rotate.left") { editCurrent { $0.rotate(.counterclockwise) } }
                    Button("Rotate right", systemImage: "rotate.right") { editCurrent { $0.rotate(.clockwise) } }
                } label: {
                    toolbarLabel(label: "Rotate", systemImage: "rotate.right")
                } primaryAction: {
                    editCurrent { $0.rotate(.clockwise) }
                }
                Spacer()
                toolbarButton(label: "Sign", systemImage: "signature") {
                    signingPageID = selectedPageID
                    showSignatureOptions = selectedPageID != nil
                }
                Spacer()
                toolbarButton(label: "Delete", systemImage: "trash") {
                    confirmDeleteCurrentPage()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(Color.faxitCardBackground)
        .disabled(currentPageIndex == nil)
    }

    /// Pages start at the light (left) end; sliding right darkens. The page
    /// updates live while dragging (from a smaller copy); the full-quality
    /// render happens on release.
    private func faxLevelSlider(for page: ScannedPage) -> some View {
        HStack(spacing: 10) {
            Text(CopyDeck.Scan.lighter)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
            Slider(
                value: Binding(
                    get: { faxLevelDraft ?? page.faxThreshold },
                    set: { level in
                        faxLevelDraft = level
                        renderFaxPreview(for: page)
                    }
                ),
                in: FaxImageProcessor.faxThresholdRange,
                onEditingChanged: { editing in
                    guard !editing, let level = faxLevelDraft else { return }
                    faxLevelDraft = nil
                    editCurrent { $0.setFaxThreshold(level) }
                    faxLevelPreview = nil
                    faxPreviewSource = nil
                }
            )
            .tint(Color.faxitAccent)
            .accessibilityLabel(CopyDeck.Scan.faxLevelLabel)
            Text(CopyDeck.Scan.darker)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
        }
        .padding(.horizontal, 20)
    }

    /// One render at a time, always at the newest slider position, so fast
    /// drags never queue up stale work. Stops once the finger lifts.
    private func renderFaxPreview(for page: ScannedPage) {
        guard !isRenderingFaxPreview else { return }
        isRenderingFaxPreview = true
        Task {
            defer { isRenderingFaxPreview = false }
            let source: UIImage
            if let cached = faxPreviewSource, cached.pageID == page.id {
                source = cached.image
            } else {
                let base = page.baseImage, tone = page.tone
                source = await Task.detached(priority: .userInitiated) {
                    FaxImageProcessor.normalized(tone.apply(to: base), maxPixelDimension: Self.previewPixelDimension)
                }.value
                faxPreviewSource = (page.id, source)
            }
            var rendered: Double?
            while let level = faxLevelDraft, level != rendered {
                let image = await Task.detached(priority: .userInitiated) {
                    FaxImageProcessor.faxBlackAndWhite(source, threshold: level)
                }.value
                rendered = level
                // Released meanwhile: the full-quality page is already showing.
                guard faxLevelDraft != nil else { return }
                faxLevelPreview = (page.id, image)
            }
        }
    }

    /// Big enough to look sharp on screen, small enough to render per tick.
    private static let previewPixelDimension: CGFloat = 1400

    private func toolbarButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarLabel(label: label, systemImage: systemImage)
        }
    }

    private func toolbarLabel(label: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
            Text(label)
                .font(.faxitCaption)
        }
        .foregroundStyle(Color.faxitInkPrimary)
    }

    private func editCurrent(_ change: (inout ScannedPage) -> Void) {
        guard let selectedPageID else { return }
        edit(pageID: selectedPageID, change)
    }

    /// Looks the page up by ID at edit time rather than capturing an index
    /// — an index captured when a sheet opened can point at a different
    /// page by the time it closes.
    private func edit(pageID: UUID, _ change: (inout ScannedPage) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        var page = pages[index]
        change(&page)
        pages[index] = page
    }

    private func confirmDeleteCurrentPage() {
        guard let index = currentPageIndex else { return }
        let isLastPage = pages.count == 1
        pendingDeletion = PendingDeletion(
            title: "Delete page \(index + 1)?",
            message: isLastPage ? "This is the only page, so the whole document will be removed." : "It won't be included in this fax."
        ) {
            deleteCurrentPage()
        }
    }

    private func deleteCurrentPage() {
        guard let index = currentPageIndex else { return }
        pages.remove(at: index)
        selectedPageID = pages.indices.contains(index) ? pages[index].id : pages.last?.id
    }
}

#Preview {
    @Previewable @State var pages = [
        ScannedPage(baseImage: .previewPage(text: "Page 1"), source: .pdf),
        ScannedPage(baseImage: .previewPage(text: "Page 2"), source: .photo)
    ]
    DocumentPagesEditorView(pages: $pages, title: "Invoice.pdf")
}

private extension UIImage {
    static func previewPage(text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.black]
            (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
        }
    }
}
