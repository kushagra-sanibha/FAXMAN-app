import SwiftUI

/// Places a signature on a page: drag to move, drag the corner handle to
/// resize. "New signature" swaps in a different one via "Add Signature".
struct SignaturePlacementView: View {
    let pageImage: UIImage
    let onCancel: () -> Void
    /// The signature and where it goes, normalized (0...1, top-left origin).
    let onPlace: (UIImage, CGRect) -> Void

    @State private var signature: UIImage
    @State private var showSignatureOptions = false
    @State private var showEditor = false
    @State private var pendingDeletion: PendingDeletion?
    /// Normalized center and width relative to the page, so the placement
    /// is independent of the on-screen size.
    @State private var center = CGPoint(x: 0.7, y: 0.85)
    @State private var widthFraction: CGFloat = 0.35
    @State private var dragStartCenter: CGPoint?
    @State private var resizeStartWidth: CGFloat?

    private let minWidthFraction: CGFloat = 0.1
    private let handleSize: CGFloat = 28

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frame = CropView.fitFrame(imageSize: pageImage.size, in: geo.size)
                ZStack {
                    Image(uiImage: pageImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    if frame.width > 0 {
                        signatureOverlay(signature, in: frame)
                    }
                }
            }
            .padding(24)
            .background(Color.black)
            .navigationTitle("Sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { place() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("New signature", systemImage: "signature") { showSignatureOptions = true }
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear { clampToPage() }
        .deleteConfirmation($pendingDeletion)
        .fullScreenCover(isPresented: $showEditor) {
            SignatureEditView(
                signature: signature,
                onCancel: { showEditor = false },
                onSave: { edited in
                    showEditor = false
                    signature = edited
                    clampToPage()
                },
                onDelete: {
                    showEditor = false
                    onCancel()
                }
            )
        }
        .signatureAcquisition(isPresented: $showSignatureOptions) { newSignature in
            signature = newSignature
            clampToPage()
        }
    }

    init(pageImage: UIImage, signature: UIImage, onCancel: @escaping () -> Void, onPlace: @escaping (UIImage, CGRect) -> Void) {
        self.pageImage = pageImage
        self.onCancel = onCancel
        self.onPlace = onPlace
        _signature = State(initialValue: signature)
    }

    private func signatureOverlay(_ signature: UIImage, in frame: CGRect) -> some View {
        let size = CGSize(width: widthFraction * frame.width, height: heightFraction * frame.height)
        let position = CGPoint(x: frame.minX + center.x * frame.width, y: frame.minY + center.y * frame.height)
        return Image(uiImage: signature)
            .resizable()
            .frame(width: size.width, height: size.height)
            .overlay(
                Rectangle()
                    .stroke(Color.faxitAccent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .contentShape(Rectangle())
            .gesture(moveGesture(in: frame))
            .overlay(alignment: .topLeading) {
                cornerButton(systemImage: "xmark", label: "Remove signature") {
                    pendingDeletion = PendingDeletion(
                        title: "Remove signature?",
                        message: "It won't be added to this page.",
                        confirmLabel: "Remove"
                    ) {
                        onCancel()
                    }
                }
                .offset(x: -(handleSize / 2 + 10), y: -(handleSize / 2 + 10))
            }
            .overlay(alignment: .topTrailing) {
                cornerButton(systemImage: "pencil", label: "Edit signature") { showEditor = true }
                    .offset(x: handleSize / 2 + 10, y: -(handleSize / 2 + 10))
            }
            .overlay(alignment: .bottomTrailing) {
                handleCircle(systemImage: "arrow.up.left.and.arrow.down.right")
                    .gesture(resizeGesture(in: frame))
                    .accessibilityLabel("Resize signature")
                    .offset(x: handleSize / 2 + 10, y: handleSize / 2 + 10)
            }
            .position(position)
            .accessibilityLabel("Signature")
    }

    private func cornerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            handleCircle(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func handleCircle(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.faxitAccent)
            .frame(width: handleSize, height: handleSize)
            .background(Circle().fill(Color.white))
            .overlay(Circle().stroke(Color.faxitAccent, lineWidth: 2))
            .shadow(color: .black.opacity(0.5), radius: 3)
            // Generous invisible hit area — 28pt is small for a fingertip.
            .padding(10)
            .contentShape(Circle())
    }

    private func moveGesture(in frame: CGRect) -> some Gesture {
        // Global space: the dragged view moves with the finger, so local
        // translations shift under it each frame and the box jitters.
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartCenter == nil { dragStartCenter = center }
                guard let start = dragStartCenter else { return }
                center = clamped(CGPoint(
                    x: start.x + value.translation.width / frame.width,
                    y: start.y + value.translation.height / frame.height
                ))
            }
            .onEnded { _ in dragStartCenter = nil }
    }

    /// The box stays centered, so the corner moves half as far as the width grows.
    private func resizeGesture(in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if resizeStartWidth == nil { resizeStartWidth = widthFraction }
                guard let start = resizeStartWidth else { return }
                let proposed = start + 2 * value.translation.width / frame.width
                widthFraction = min(max(proposed, minWidthFraction), maxWidthFraction)
                center = clamped(center)
            }
            .onEnded { _ in resizeStartWidth = nil }
    }

    // MARK: - Geometry (normalized to the page)

    /// Signature height ÷ width, in the page's normalized space.
    private var normalizedAspect: CGFloat {
        guard signature.size.width > 0, pageImage.size.height > 0 else { return 0 }
        return (signature.size.height / signature.size.width) * (pageImage.size.width / pageImage.size.height)
    }

    private var heightFraction: CGFloat { widthFraction * normalizedAspect }

    /// Never wider or taller than 90% of the page.
    private var maxWidthFraction: CGFloat {
        normalizedAspect > 0 ? min(0.9, 0.9 / normalizedAspect) : 0.9
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let halfWidth = widthFraction / 2
        let halfHeight = heightFraction / 2
        return CGPoint(
            x: min(max(point.x, halfWidth), 1 - halfWidth),
            y: min(max(point.y, halfHeight), 1 - halfHeight)
        )
    }

    /// Keeps the box on the page after the signature (and so its aspect) changes.
    private func clampToPage() {
        widthFraction = min(max(widthFraction, minWidthFraction), maxWidthFraction)
        center = clamped(center)
    }

    private func place() {
        let rect = CGRect(
            x: center.x - widthFraction / 2,
            y: center.y - heightFraction / 2,
            width: widthFraction,
            height: heightFraction
        )
        onPlace(signature, rect)
    }
}

#Preview {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400))
    let page = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
    }
    let signature = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 40)).image { _ in
        UIColor.black.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 10, width: 120, height: 20)).fill()
    }
    SignaturePlacementView(pageImage: page, signature: signature, onCancel: {}, onPlace: { _, _ in })
}
