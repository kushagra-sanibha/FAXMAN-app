import SwiftUI

/// Everything it takes to get pages into the app — camera permission gating,
/// the scanner, the Photos picker, the Files picker, progress, and failure
/// alerts — in one place. The home screen and the compose flow's "add more"
/// buttons both drive this same object, so they can never drift apart (they
/// used to be two hand-maintained copies).
@Observable
final class DocumentImportFlow {
    private(set) var isImporting = false

    fileprivate var showScanner = false
    fileprivate var showUploadSourceMenu = false
    fileprivate var showPhotoPicker = false
    fileprivate var showFilePicker = false
    fileprivate var showCameraDenied = false
    fileprivate var alert: ImportAlert?
    /// Apple's scanner can't host custom buttons, so after "Save" the same
    /// full-screen cover switches to Faxit's page preview (Sign, Adjust,
    /// Filters, ...) and the pages are only added once that closes.
    fileprivate enum ScanStage {
        case scanning, processing, reviewing
    }
    fileprivate var scanStage: ScanStage = .scanning
    fileprivate var scanReviewPages: [ScannedPage] = []
    fileprivate var showScanTips = false
    /// Tips show before the first scan, and again after a scan came back tilted.
    private static let showScanTipsKey = "showScanTipsBeforeNextScan"
    fileprivate var shouldShowScanTips: Bool {
        get { UserDefaults.standard.object(forKey: Self.showScanTipsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.showScanTipsKey) }
    }

    struct ImportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    func beginScan() {
        // Close the number field first: if it's still focused when a sheet
        // opens, iOS brings the keyboard straight back when the sheet closes.
        Keyboard.dismiss()
        if shouldShowScanTips {
            showScanTips = true
        } else {
            openScanner()
        }
    }

    /// After the tips sheet has gone away (its onDismiss), or straight away.
    fileprivate func openScanner() {
        switch CameraAccessManager.currentStatus() {
        case .authorized:
            showScanner = true
        case .needsPrimer:
            CameraAccessManager.requestAccess { [weak self] granted in
                if granted {
                    self?.showScanner = true
                } else {
                    self?.showCameraDenied = true
                }
            }
        case .deniedOrRestricted:
            showCameraDenied = true
        }
    }

    func beginUpload() {
        Keyboard.dismiss()
        showUploadSourceMenu = true
    }

    fileprivate func run(_ work: @escaping () async -> (pages: [ScannedPage], failures: [String]), deliver: @escaping ([ScannedPage]) -> Void) {
        isImporting = true
        Task { @MainActor in
            let result = await work()
            if !result.pages.isEmpty { deliver(result.pages) }
            if !result.failures.isEmpty {
                alert = ImportAlert(
                    title: result.pages.isEmpty ? "Couldn't add pages" : "Some files weren't added",
                    message: result.failures.joined(separator: "\n")
                )
            }
            isImporting = false
        }
    }
}

extension View {
    /// Attaches the scanner/pickers/alerts for `flow`; imported pages are
    /// handed to `onPagesAdded`.
    func documentImport(_ flow: DocumentImportFlow, onPagesAdded: @escaping ([ScannedPage]) -> Void) -> some View {
        modifier(DocumentImportModifier(flow: flow, onPagesAdded: onPagesAdded))
    }
}

private struct DocumentImportModifier: ViewModifier {
    @Bindable var flow: DocumentImportFlow
    let onPagesAdded: ([ScannedPage]) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $flow.showScanTips, onDismiss: {
                if !flow.shouldShowScanTips { flow.openScanner() }
            }) {
                ScanTipsSheet {
                    flow.shouldShowScanTips = false
                    flow.showScanTips = false
                }
            }
            .fullScreenCover(isPresented: $flow.showScanner, onDismiss: finishScan) {
                switch flow.scanStage {
                case .scanning:
                    if ScannerPreference.useFaxitScanner {
                        ScannerView(onFinish: handleScannedImages, onCancel: { flow.showScanner = false })
                    } else {
                        // Apple's scanner as-is: anything drawn over it also
                        // covers its own review screens.
                        DocumentScannerView(
                            onFinish: handleScannedImages,
                            onCancel: { flow.showScanner = false },
                            onFailure: { _ in
                                flow.showScanner = false
                                flow.alert = .init(title: "Scan failed", message: "Something went wrong while scanning. Try again.")
                            }
                        )
                        .ignoresSafeArea()
                    }
                case .processing:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.ignoresSafeArea())
                case .reviewing:
                    DocumentPagesEditorView(
                        pages: $flow.scanReviewPages,
                        title: flow.scanReviewPages.first?.documentName ?? "Scan"
                    )
                }
            }
            .sheet(isPresented: $flow.showFilePicker) {
                FilePickerView(
                    onPick: { urls in
                        flow.showFilePicker = false
                        flow.run({
                            let result = await DocumentImportHelper.importPages(from: urls)
                            return (result.pages, result.failures.map(\.message))
                        }, deliver: onPagesAdded)
                    },
                    onCancel: { flow.showFilePicker = false }
                )
            }
            .sheet(isPresented: $flow.showPhotoPicker) {
                PhotoPickerView(
                    onPick: { photos, failedCount in
                        flow.showPhotoPicker = false
                        flow.run({
                            let result = await DocumentImportHelper.makePages(fromPhotos: photos)
                            var failures = result.failures.map(\.message)
                            if failedCount > 0 {
                                failures.append("\(failedCount) photo\(failedCount == 1 ? "" : "s") couldn't be loaded from your library.")
                            }
                            return (result.pages, failures)
                        }, deliver: onPagesAdded)
                    },
                    onCancel: { flow.showPhotoPicker = false }
                )
                .ignoresSafeArea()
            }
            .confirmationDialog(CopyDeck.Compose.uploadSourceTitle, isPresented: $flow.showUploadSourceMenu, titleVisibility: .visible) {
                Button(CopyDeck.Compose.uploadSourcePhotos) { flow.showPhotoPicker = true }
                Button(CopyDeck.Compose.uploadSourceFiles) { flow.showFilePicker = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(CopyDeck.Compose.uploadSourceFilesHint)
            }
            .alert(CopyDeck.Compose.cameraDeniedMessage, isPresented: $flow.showCameraDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(item: $flow.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .cancel(Text("OK")))
            }
    }

    /// Either scanner's pages: prepared off the main thread, then the
    /// same full-screen cover switches to the page preview.
    private func handleScannedImages(_ images: [UIImage]) {
        flow.scanStage = .processing
        Task { @MainActor in
            let pages = await DocumentImportHelper.makePages(fromScan: images)
            flow.scanReviewPages = pages
            if pages.contains(where: \.wasCapturedTilted) { flow.shouldShowScanTips = true }
            if pages.isEmpty {
                flow.showScanner = false
            } else {
                flow.scanStage = .reviewing
            }
        }
    }

    /// Runs however the scanner cover closes; adds whatever pages survived review.
    private func finishScan() {
        let pages = flow.scanReviewPages
        flow.scanReviewPages = []
        flow.scanStage = .scanning
        if !pages.isEmpty { onPagesAdded(pages) }
    }
}
