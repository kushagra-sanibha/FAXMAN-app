import SwiftUI

/// Scan + upload buttons for the compose flow's "add more pages" step.
/// All gating (camera permission, pickers, failure alerts) lives in the
/// shared `DocumentImportFlow`, the same one the home screen uses.
struct DocumentCaptureControls: View {
    let scanLabel: String
    let fileLabel: String
    let onPagesAdded: ([ScannedPage]) -> Void

    @State private var importFlow = DocumentImportFlow()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    importFlow.beginScan()
                } label: {
                    Label(scanLabel, systemImage: "camera.fill")
                }
                .buttonStyle(.faxitSecondary)

                Button {
                    importFlow.beginUpload()
                } label: {
                    Label(fileLabel, systemImage: "doc.fill")
                }
                .buttonStyle(.faxitSecondary)
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
        }
        .documentImport(importFlow, onPagesAdded: onPagesAdded)
    }
}
