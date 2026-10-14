import SwiftUI

/// Perspective-correcting crop tool, matching the system document
/// scanner's own edit screen — four independently draggable corners over
/// the image; "Done" hands back the quadrilateral, which the page warps
/// into a straightened rectangle (`CIPerspectiveCorrection`).
///
/// Works the same for every page source. For photos (library or image
/// files) — which, unlike camera scans, never went through VisionKit's edge
/// detection — it starts from the automatically detected paper edges.
struct CropView: View {
    let image: UIImage
    var detectsEdges: Bool = false
    let onCancel: () -> Void
    let onCrop: (NormalizedQuad) -> Void

    /// Normalized (0...1, top-left origin) so the selection is independent
    /// of the on-screen size — the old version stored view-space points,
    /// which went stale on rotation/resizing and mis-cropped.
    @State private var quad: NormalizedQuad = .fullImage
    @State private var detectedQuad: NormalizedQuad?
    @State private var isDetecting = false
    @State private var userHasEdited = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frame = Self.fitFrame(imageSize: image.size, in: geo.size)
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    if frame.width > 0 {
                        QuadOverlay(quad: $quad, imageFrame: frame, onEdit: { userHasEdited = true })
                    }
                }
            }
            .padding(24)
            .background(Color.black)
            .navigationTitle("Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onCrop(quad) }
                        .disabled(!quad.isValid)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Full page") {
                        quad = .fullImage
                        userHasEdited = true
                    }
                    .disabled(quad == .fullImage)
                    Spacer()
                    if isDetecting {
                        ProgressView()
                    } else if let detectedQuad {
                        Button("Auto-detect") {
                            quad = detectedQuad
                            userHasEdited = true
                        }
                        .disabled(quad == detectedQuad)
                    }
                }
            }
        }
        .task {
            guard detectsEdges else { return }
            isDetecting = true
            let image = image
            let detected = await Task.detached(priority: .userInitiated) {
                DocumentEdgeDetector.detectDocument(in: image)
            }.value
            isDetecting = false
            detectedQuad = detected
            // Never yank the selection out from under someone mid-drag.
            if let detected, !userHasEdited { quad = detected }
        }
    }

    /// Centered aspect-fit frame of `imageSize` within `containerSize` —
    /// matches what `.scaledToFit()` renders, so the overlay lines up with
    /// the actual displayed image.
    static func fitFrame(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else { return .zero }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        var size = containerSize
        if imageAspect > containerAspect {
            size.height = containerSize.width / imageAspect
        } else {
            size.width = containerSize.height * imageAspect
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }
}

#Preview {
    // Plain white, like a real document page — this is exactly the case
    // that exposed the white-on-white invisible overlay bug.
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400))
    let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
    }
    CropView(image: image, onCancel: {}, onCrop: { _ in })
}

/// Draws the quadrilateral outline and one independently draggable circular
/// handle per corner, clamped to the image and never allowed to cross over
/// into a self-intersecting shape.
private struct QuadOverlay: View {
    @Binding var quad: NormalizedQuad
    let imageFrame: CGRect
    let onEdit: () -> Void

    @State private var dragStart: NormalizedQuad?
    private let handleSize: CGFloat = 28

    private func viewPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: imageFrame.minX + point.x * imageFrame.width, y: imageFrame.minY + point.y * imageFrame.height)
    }

    private var quadPath: Path {
        Path { path in
            let points = quad.points.map(viewPoint)
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
    }

    var body: some View {
        ZStack {
            // Dims everything outside the selected quad so it's visually
            // obvious what will be kept vs. cropped away — without this,
            // a white quad outline on a plain white document page is
            // essentially invisible and there's nothing to see or drag.
            Path { path in
                path.addRect(imageFrame)
                path.addPath(quadPath)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // Dark shadow line behind the accent stroke so the outline
            // itself has contrast against light page backgrounds too.
            quadPath.stroke(Color.black.opacity(0.6), lineWidth: 4)
                .allowsHitTesting(false)
            quadPath.stroke(Color.faxitAccent, lineWidth: 2)
                .allowsHitTesting(false)

            handle(\.topLeft, label: "Top left corner")
            handle(\.topRight, label: "Top right corner")
            handle(\.bottomLeft, label: "Bottom left corner")
            handle(\.bottomRight, label: "Bottom right corner")
        }
    }

    private func handle(_ corner: WritableKeyPath<NormalizedQuad, CGPoint>, label: String) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.faxitAccent, lineWidth: 3))
            .shadow(color: .black.opacity(0.5), radius: 3)
            .frame(width: handleSize, height: handleSize)
            // Generous invisible hit area — 28pt is small for a fingertip.
            .padding(10)
            .contentShape(Circle())
            .position(viewPoint(quad[keyPath: corner]))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil { dragStart = quad }
                        guard let start = dragStart, imageFrame.width > 0, imageFrame.height > 0 else { return }
                        var point = start[keyPath: corner]
                        point.x = min(max(point.x + value.translation.width / imageFrame.width, 0), 1)
                        point.y = min(max(point.y + value.translation.height / imageFrame.height, 0), 1)
                        var updated = quad
                        updated[keyPath: corner] = point
                        // Keep the last valid shape instead of letting the
                        // quad fold over itself.
                        if updated.isValid {
                            quad = updated
                            onEdit()
                        }
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .accessibilityLabel(label)
    }
}
