import SwiftUI
import SwiftData
import PDFKit

private struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct ReceivedFaxDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let fax: ReceivedFax

    var body: some View {
        PDFKitView(url: fax.pdfFileURL)
            .navigationTitle(fax.senderNumberIfAvailable.map(PhoneNumberFormatter.displayString) ?? "Unknown sender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: fax.pdfFileURL)
                }
            }
            .task {
                if !fax.isRead {
                    fax.isRead = true
                    try? modelContext.save()
                }
            }
    }
}
