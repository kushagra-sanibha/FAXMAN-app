import SwiftUI

/// Faxit's own document camera.
///
/// Layout (Faxit's own look): a navy header with close, title and
/// flashlight; the camera in a rounded card showing the whole frame the
/// scanner analyses; and a fixed-height control bar with Auto, the
/// brand-blue shutter, and the captured pages. The page border appears only
/// when one page fits — all corners in view, close enough, held flat — and
/// the shutter's ring fills while it holds still, then captures.
struct ScannerView: View {
    let onFinish: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var model = ScannerViewModel()
    @State private var flash = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let chrome = Color.faxitNavyBackground

    var body: some View {
        VStack(spacing: 0) {
            header
            cameraCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            controls
        }
        .background(Self.chrome.ignoresSafeArea())
        .task { await model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await model.start() }
            case .background: model.stop()
            default: break
            }
        }
        .onChange(of: model.captureCount) {
            guard !reduceMotion else { return }
            flash = true
            withAnimation(.easeOut(duration: 0.25)) { flash = false }
        }
        .sensoryFeedback(.success, trigger: model.captureCount)
        .onChange(of: model.instruction) { _, instruction in
            AccessibilityNotification.Announcement(CopyDeck.Scanner.instruction(instruction)).post()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            iconButton(systemImage: "xmark", label: CopyDeck.Scanner.close, action: onCancel)
            Spacer()
            Text(CopyDeck.Scanner.title)
                .font(.faxitSectionHeader)
                .foregroundStyle(.white)
            Spacer()
            if model.hasTorch {
                iconButton(
                    systemImage: model.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                    label: model.isTorchOn ? CopyDeck.Scanner.torchOff : CopyDeck.Scanner.torchOn,
                    action: model.toggleTorch
                )
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }

    private func iconButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.faxitBodySemibold)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel(label)
    }

    // MARK: Camera card

    private var cameraCard: some View {
        ZStack {
            Color.black
            content
            if let page = model.confirmation {
                confirmationView(page)
                    .transition(.opacity)
            }
            Color.white
                .opacity(flash ? 0.7 : 0)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.2), value: model.confirmation)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .top) {
            if let hint = hintText {
                Label(hint, systemImage: hintSymbol)
                    .font(.faxitCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.faxitAccent, in: Capsule())
                    .padding(.top, 14)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hintText)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .starting:
            ProgressView().tint(.white)
        case .running:
            if let session = model.session {
                CameraPreviewView(session: session, device: model.device, geometry: model.previewGeometry)
                    .overlay {
                        if model.showsOutline, let points = model.quad.flatMap({ model.previewGeometry.viewPoints(for: $0) }) {
                            DocumentOverlayView(points: points)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: model.showsOutline)
            }
        case .denied:
            message(
                title: CopyDeck.Scanner.deniedTitle,
                body: CopyDeck.Scanner.deniedMessage,
                action: (CopyDeck.Scanner.openSettings, {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                })
            )
        case .noCamera:
            SampleScanView { image in Task { await model.addPage(from: image) } }
        case .failed:
            message(
                title: CopyDeck.Scanner.failedTitle,
                body: CopyDeck.Scanner.failedMessage,
                action: (CopyDeck.Scanner.tryAgain, { Task { await model.start() } })
            )
        }
    }

    /// One short instruction while something needs fixing; nothing when all is well.
    private var hintText: String? {
        guard model.state == .running, model.confirmation == nil else { return nil }
        switch model.instruction {
        case .findPage, .holdFlat, .fitCorners, .moveCloser, .nextPage: return CopyDeck.Scanner.instruction(model.instruction)
        case .holdSteady, .ready: return nil
        }
    }

    private var hintSymbol: String {
        switch model.instruction {
        case .holdFlat: "iphone.gen3"
        case .fitCorners: "arrow.up.left.and.arrow.down.right"
        case .moveCloser: "arrow.down.right.and.arrow.up.left"
        case .nextPage: "checkmark.circle.fill"
        default: "doc.viewfinder"
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(alignment: .center, spacing: 0) {
            autoToggle
                .frame(maxWidth: .infinity, alignment: .leading)
            shutter
            pagesButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 132)
    }

    private var autoToggle: some View {
        Button {
            model.autoCapture.toggle()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: model.autoCapture ? "a.circle.fill" : "a.circle")
                    .font(.faxitTitle3)
                Text(model.autoCapture ? CopyDeck.Scanner.autoOn : CopyDeck.Scanner.autoOff)
                    .font(.faxitCaptionBold)
            }
            .foregroundStyle(model.autoCapture ? Color.faxitStatusGreen : Color.white.opacity(0.75))
            .frame(minWidth: 64, minHeight: 56)
        }
        .accessibilityHint(CopyDeck.Scanner.autoHint)
    }

    /// Brand-blue shutter; a green ring fills while the page holds still.
    private var shutter: some View {
        Button {
            Task { await model.capture() }
        } label: {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: model.autoCapture ? model.autoCaptureProgress : 0)
                    .stroke(Color.faxitStatusGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: model.autoCaptureProgress)
                Circle()
                    .fill(Color.faxitAccent)
                    .padding(11)
                if model.confirmation != nil {
                    Image(systemName: "checkmark")
                        .font(.faxitTitle2Bold)
                        .foregroundStyle(.white)
                } else if model.isCapturing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "doc.viewfinder")
                        .font(.faxitTitle2Bold)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 84, height: 84)
        }
        .disabled(model.isCapturing || !(model.state == .running || model.state == .noCamera))
        .accessibilityLabel(CopyDeck.Scanner.shutter)
        .accessibilityValue(CopyDeck.Scanner.pageCount(model.pages.count))
    }

    @ViewBuilder
    private var pagesButton: some View {
        if let last = model.pages.last {
            Button {
                onFinish(model.pages)
            } label: {
                VStack(spacing: 4) {
                    Image(uiImage: last)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Text("\(model.pages.count)")
                                .font(.faxitCaptionBold)
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Color.faxitAccent, in: Capsule())
                                .offset(x: 8, y: -8)
                        }
                    Text(CopyDeck.Scanner.done)
                        .font(.faxitCaptionBold)
                        .foregroundStyle(.white)
                }
                .frame(minWidth: 64, minHeight: 56)
            }
            .accessibilityLabel("\(CopyDeck.Scanner.done), \(CopyDeck.Scanner.pageCount(model.pages.count))")
            .contextMenu {
                Button(CopyDeck.Scanner.undoLastPage, systemImage: "trash", role: .destructive) { model.removeLastPage() }
            }
        } else {
            Color.clear.frame(width: 64, height: 56)
        }
    }

    /// The captured page, flattened, over the dimmed camera with a check.
    private func confirmationView(_ page: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.6)
            Image(uiImage: page)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .overlay(alignment: .bottom) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.faxitLargeTitle)
                        .foregroundStyle(.white, Color.faxitStatusGreen)
                        .offset(y: 22)
                }
                .padding(.horizontal, 36)
                .padding(.top, 28)
                .padding(.bottom, 52)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func message(title: String, body: String, action: (String, () -> Void)) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.faxitLargeTitle)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(title)
                .font(.faxitSectionHeader)
                .foregroundStyle(.white)
            Text(body)
                .font(.faxitBody)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button(action.0, action: action.1)
                .buttonStyle(.faxitPrimary)
                .frame(maxWidth: 260)
        }
        .padding(32)
    }
}
