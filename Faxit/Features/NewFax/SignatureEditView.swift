import SwiftUI

/// Edits the signature being placed: crop, rotate, or delete it.
struct SignatureEditView: View {
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void
    let onDelete: () -> Void

    @State private var signature: UIImage
    @State private var showCrop = false
    @State private var cropFailedAlert = false
    @State private var pendingDeletion: PendingDeletion?

    init(signature: UIImage, onCancel: @escaping () -> Void, onSave: @escaping (UIImage) -> Void, onDelete: @escaping () -> Void) {
        _signature = State(initialValue: signature)
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Image(uiImage: signature)
                .resizable()
                .scaledToFit()
                .padding(24)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationTitle("Edit Signature")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onSave(signature) }
                    }
                }
                .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .fullScreenCover(isPresented: $showCrop) {
            // Black ink is invisible on the crop screen's black backdrop,
            // so crop against a white copy; the quad is normalized, so it
            // applies to the transparent original unchanged.
            CropView(
                image: Self.onWhite(signature),
                onCancel: { showCrop = false },
                onCrop: { quad in
                    showCrop = false
                    if let cropped = FaxImageProcessor.perspectiveCorrected(signature, to: quad) {
                        signature = cropped
                    } else {
                        cropFailedAlert = true
                    }
                }
            )
        }
        .deleteConfirmation($pendingDeletion)
        .alert("Couldn't crop the signature", isPresented: $cropFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try dragging the corners so they outline the signature.")
        }
    }

    private var bottomBar: some View {
        HStack {
            toolbarButton(label: "Crop", systemImage: "crop") { showCrop = true }
            Spacer()
            Menu {
                Button("Rotate left", systemImage: "rotate.left") { rotate(.counterclockwise) }
                Button("Rotate right", systemImage: "rotate.right") { rotate(.clockwise) }
            } label: {
                toolbarLabel(label: "Rotate", systemImage: "rotate.right")
            } primaryAction: {
                rotate(.clockwise)
            }
            Spacer()
            toolbarButton(label: "Delete", systemImage: "trash") {
                pendingDeletion = PendingDeletion(
                    title: "Delete signature?",
                    message: "It won't be added to this page."
                ) {
                    onDelete()
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 14)
        .background(Color.faxitCardBackground)
    }

    private func rotate(_ direction: FaxImageProcessor.RotationDirection) {
        signature = FaxImageProcessor.rotated(signature, direction)
    }

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

    private static func onWhite(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }
}
