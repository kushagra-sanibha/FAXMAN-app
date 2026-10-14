import PencilKit
import SwiftUI

/// Draw a signature with a finger or Apple Pencil. Hands back a tightly
/// trimmed, transparent image in black ink, ready to place on a page.
struct SignatureCaptureView: View {
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    @State private var drawing = PKDrawing()

    private var isEmpty: Bool { drawing.strokes.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                SignatureCanvas(drawing: $drawing)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.faxitInkSecondary.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 48)
                            .allowsHitTesting(false)
                    }
                Text("Sign above the line with your finger or Apple Pencil.")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                Spacer()
            }
            .padding(16)
            .background(Color.faxitMintBackground)
            .navigationTitle("Your signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let image = Self.signatureImage(from: drawing) { onSave(image) }
                    }
                    .disabled(isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") { drawing = PKDrawing() }
                        .disabled(isEmpty)
                }
            }
        }
        // A downward stroke must draw, not dismiss the sheet.
        .interactiveDismissDisabled()
    }

    /// Rendered in light mode: PencilKit shows black ink as white in dark
    /// mode, and the page needs real black ink.
    private static func signatureImage(from drawing: PKDrawing) -> UIImage? {
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -6, dy: -6)
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: bounds, scale: 3)
        }
        return image
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.isScrollEnabled = false
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

#Preview {
    SignatureCaptureView(onCancel: {}, onSave: { _ in })
}
