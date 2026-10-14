import PhotosUI
import SwiftUI

/// No camera (the Simulator): runs the same detection and straightening on
/// a still image so the pipeline can be tested. Starts with a generated
/// sample — a page lying at an angle on a dark table — and can load any
/// photo instead.
struct SampleScanView: View {
    let onAddPage: (UIImage) -> Void

    @State private var image = SampleScanView.makeSample()
    @State private var detection: DocumentDetector.Detection?
    @State private var isDetecting = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            Text(CopyDeck.Scanner.sampleTitle)
                .font(.faxitSectionHeader)
                .foregroundStyle(.white)
            Text(CopyDeck.Scanner.sampleMessage)
                .font(.faxitCaption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                let frame = CropView.fitFrame(imageSize: image.size, in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                    DocumentOverlayView(
                        points: detection.map { found in
                            found.quad.points.map { CGPoint(x: frame.minX + $0.x * frame.width, y: frame.minY + $0.y * frame.height) }
                        }
                    )
                }
            }

            Text(statusText)
                .font(.faxitCaption)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 12) {
                Button(CopyDeck.Scanner.useSample) { image = Self.makeSample() }
                    .buttonStyle(.faxitSecondary)
                PhotosPicker(CopyDeck.Scanner.choosePhoto, selection: $pickedItem, matching: .images)
                    .buttonStyle(.faxitSecondary)
            }
            Button(CopyDeck.Scanner.addThisPage) { onAddPage(image) }
                .buttonStyle(.faxitPrimary)
        }
        .padding(16)
        .task(id: ObjectIdentifier(image)) { await detect() }
        .task(id: pickedItem) {
            guard let pickedItem, let data = try? await pickedItem.loadTransferable(type: Data.self),
                  let picked = FaxImageProcessor.downsampledImage(from: data) else { return }
            image = picked
        }
    }

    private var statusText: String {
        if isDetecting { return CopyDeck.Scanner.detecting }
        guard let detection else { return CopyDeck.Scanner.noPageFound }
        return CopyDeck.Scanner.foundWith(detection.method.rawValue)
    }

    private func detect() async {
        isDetecting = true
        let image = image
        detection = await Task.detached(priority: .userInitiated) {
            FaxImageProcessor.ciImage(from: image).flatMap { DocumentDetector.detect(in: $0) }
        }.value
        isDetecting = false
    }

    /// A white page with text lines, in perspective, on a dark surface.
    static func makeSample() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.22, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let corners = [CGPoint(x: 260, y: 220), CGPoint(x: 930, y: 280), CGPoint(x: 1060, y: 1400), CGPoint(x: 130, y: 1360)]
            let page = UIBezierPath()
            page.move(to: corners[0])
            corners.dropFirst().forEach { page.addLine(to: $0) }
            page.close()
            UIColor(white: 0.95, alpha: 1).setFill()
            page.fill()
            UIColor(white: 0.15, alpha: 1).setFill()
            for row in 0..<24 {
                let t = CGFloat(row) / 24
                context.fill(CGRect(x: 300 - t * 120, y: 330 + t * 960, width: 560 + t * 180, height: 10))
            }
        }
    }
}
