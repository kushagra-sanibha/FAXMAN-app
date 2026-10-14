import SwiftUI

enum SignatureMethod {
    case draw
    case scan
}

/// "Add Signature": draw one on screen, or scan one signed on paper.
struct SignatureMethodSheet: View {
    let onSelect: (SignatureMethod) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Signature")
                    .font(.faxitTitle2Bold)
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.faxitInkSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.faxitMintBackground))
                }
                .accessibilityLabel("Close")
            }
            .padding(.bottom, 8)

            optionRow(title: "Draw Signature", systemImage: "pencil.and.scribble") {
                onSelect(.draw)
            }
            optionRow(title: "Scan Signature", systemImage: "signature", framed: true) {
                onSelect(.scan)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
    }

    private func optionRow(title: String, systemImage: String, framed: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    if framed {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 26, weight: .regular))
                    }
                    Image(systemName: systemImage)
                        .font(.system(size: framed ? 12 : 20, weight: .medium))
                }
                .frame(width: 28)
                Text(title)
                    .font(.faxitBodySemibold)
                Spacer()
            }
            .foregroundStyle(Color.faxitInkPrimary)
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(Color.faxitMintBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Shows "Add Signature" over this view; drawing or scanning ends with
    /// `onSignature` (transparent black-ink image, also saved on-device).
    /// Closing or cancelling at any step just returns to this view.
    func signatureAcquisition(isPresented: Binding<Bool>, onSignature: @escaping (UIImage) -> Void) -> some View {
        modifier(SignatureAcquisitionModifier(isPresented: isPresented, onSignature: onSignature))
    }
}

/// Each step hands off in the previous presentation's `onDismiss`, since a
/// new sheet/cover can't present while the old one is still animating away.
private struct SignatureAcquisitionModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onSignature: (UIImage) -> Void

    @Environment(\.openURL) private var openURL
    @State private var pendingMethod: SignatureMethod?
    @State private var showDraw = false
    @State private var drawnSignature: UIImage?
    @State private var showScanner = false
    @State private var scannedImage: UIImage?
    @State private var isExtractingScan = false
    @State private var scanFailedAlert = false
    @State private var cameraDeniedAlert = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isExtractingScan {
                    ProgressView("Reading signature…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: startPendingMethod) {
                SignatureMethodSheet(
                    onSelect: { method in
                        pendingMethod = method
                        isPresented = false
                    },
                    onClose: { isPresented = false }
                )
            }
            .sheet(isPresented: $showDraw, onDismiss: deliverDrawnSignature) {
                SignatureCaptureView(
                    onCancel: { showDraw = false },
                    onSave: { image in
                        drawnSignature = image
                        showDraw = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showScanner, onDismiss: extractScannedSignature) {
                DocumentScannerView(
                    onFinish: { images in
                        scannedImage = images.first
                        showScanner = false
                    },
                    onCancel: { showScanner = false },
                    onFailure: { _ in showScanner = false }
                )
                .ignoresSafeArea()
            }
            .alert("Couldn't find a signature", isPresented: $scanFailedAlert) {
                Button("Try again") { isPresented = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sign in dark ink on plain white paper, then scan it so the signature fills most of the frame.")
            }
            .alert("Camera access is off", isPresented: $cameraDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow camera access in Settings to scan a signature, or draw one instead.")
            }
    }

    private func startPendingMethod() {
        let method = pendingMethod
        pendingMethod = nil
        switch method {
        case .draw:
            showDraw = true
        case .scan:
            startScan()
        case nil:
            break
        }
    }

    private func startScan() {
        switch CameraAccessManager.currentStatus() {
        case .authorized:
            showScanner = true
        case .needsPrimer:
            CameraAccessManager.requestAccess { granted in
                if granted {
                    showScanner = true
                } else {
                    cameraDeniedAlert = true
                }
            }
        case .deniedOrRestricted:
            cameraDeniedAlert = true
        }
    }

    private func deliverDrawnSignature() {
        guard let image = drawnSignature else { return }
        drawnSignature = nil
        deliver(image)
    }

    /// A scanner failure also lands here with no image and simply returns.
    private func extractScannedSignature() {
        guard let scan = scannedImage else { return }
        scannedImage = nil
        isExtractingScan = true
        Task {
            let cutout = await Task.detached(priority: .userInitiated) {
                FaxImageProcessor.signatureCutout(from: scan)
            }.value
            isExtractingScan = false
            if let cutout {
                deliver(cutout)
            } else {
                scanFailedAlert = true
            }
        }
    }

    private func deliver(_ image: UIImage) {
        SignatureStore.save(image)
        onSignature(image)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SignatureMethodSheet(onSelect: { _ in }, onClose: {})
    }
}
