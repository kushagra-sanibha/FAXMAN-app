import AVFoundation
import Observation
import QuartzCore
import UIKit

/// Camera permission, session lifecycle, the steadied page outline, capture
/// progress, and capture. Main-actor isolated; the camera reports
/// detections from its video queue and they hop here.
@Observable
final class ScannerViewModel {
    enum State: Equatable {
        case starting
        case running
        /// Camera access denied or restricted: show the Settings button.
        case denied
        /// No camera (the Simulator): show the sample-image fallback.
        case noCamera
        case failed
    }

    /// The border appears once a page has been held still this long, and
    /// hides the moment the camera moves — none while aiming.
    static let outlineAfter: Double = 0.5
    /// Then the shutter ring fills over this long and the page is captured.
    static let captureHold: Double = 1.5
    /// How long the flattened capture is shown before scanning resumes.
    static let confirmationDuration: Duration = .milliseconds(1000)
    private static let autoCaptureKey = "scannerAutoCapture"

    private(set) var state: State = .starting
    /// Steadied outline in capture-device-point space.
    private(set) var quad: NormalizedQuad?
    /// Whether to draw the outline right now.
    private(set) var showsOutline = false
    private(set) var instruction: ScanInstruction = .findPage
    /// 0…1 shutter ring: fills while the border holds still, then captures.
    private(set) var autoCaptureProgress: Double = 0
    /// The page just captured, flattened, shown briefly as confirmation.
    private(set) var confirmation: UIImage?
    private(set) var pages: [UIImage] = []
    private(set) var isCapturing = false
    /// Bumped on each capture, for the flash and haptic.
    private(set) var captureCount = 0
    private(set) var device: AVCaptureDevice?
    private(set) var isTorchOn = false
    var autoCapture: Bool {
        didSet { UserDefaults.standard.set(autoCapture, forKey: Self.autoCaptureKey) }
    }
    let previewGeometry = PreviewGeometry()

    private var camera: CameraService?
    private var stabilizer: QuadStabilizer?
    /// Set by a capture: auto-capture waits until the page is removed or
    /// moved, so one page isn't captured over and over.
    private var capturedQuad: NormalizedQuad?

    init() {
        autoCapture = UserDefaults.standard.object(forKey: Self.autoCaptureKey) as? Bool ?? true
    }

    var session: AVCaptureSession? { camera?.session }
    var hasTorch: Bool { device?.hasTorch ?? false }

    func start() async {
        guard CameraService.backCamera != nil else {
            state = .noCamera
            return
        }
        guard await Self.requestAccess() else {
            state = .denied
            return
        }
        let update: @Sendable @MainActor (DocumentDetector.Detection?) -> Void = { [weak self] detection in
            self?.handle(detection)
        }
        let camera = camera ?? CameraService(rotation: previewGeometry.rotationBox) { detection in
            Task { @MainActor in update(detection) }
        }
        self.camera = camera
        do {
            device = try await camera.start()
            state = .running
        } catch {
            state = .failed
        }
    }

    func stop() {
        camera?.stop()
        stabilizer?.reset()
        quad = nil
        showsOutline = false
        instruction = .findPage
        autoCaptureProgress = 0
        isTorchOn = false
    }

    func toggleTorch() {
        isTorchOn.toggle()
        camera?.setTorch(isTorchOn)
    }

    func removeLastPage() {
        _ = pages.popLast()
    }

    /// Shutter button. Always works, even when the page isn't well framed.
    func capture() async {
        guard let camera, !isCapturing else { return }
        isCapturing = true
        autoCaptureProgress = 0
        // Flatten exactly what the border showed; with no border, the
        // full-resolution detection (or the whole photo) is used.
        let liveQuad = showsOutline ? quad : nil
        let angle = previewGeometry.photoRotationAngle
        capturedQuad = quad
        showsOutline = false
        defer {
            isCapturing = false
            stabilizer?.reset()
        }
        do {
            let data = try await camera.capturePhoto(rotationAngle: angle)
            captureCount += 1
            let page = await Task.detached(priority: .userInitiated) {
                ScannedPhotoProcessor.page(fromPhotoData: data, liveQuad: liveQuad)
            }.value
            if let page {
                pages.append(page)
                confirmation = page
                try? await Task.sleep(for: Self.confirmationDuration)
                confirmation = nil
            }
        } catch {
            // No photo (e.g. the lens never focused): the page wasn't
            // captured, so auto-capture may try it again.
            capturedQuad = nil
        }
    }

    /// Simulator fallback: the same processing on a still image.
    func addPage(from image: UIImage) async {
        let page = await Task.detached(priority: .userInitiated) {
            ScannedPhotoProcessor.page(from: image)
        }.value
        pages.append(page)
        captureCount += 1
    }

    private func handle(_ detection: DocumentDetector.Detection?) {
        guard state == .running, !isCapturing else { return }
        let now = CACurrentMediaTime()
        if stabilizer == nil, let detection {
            stabilizer = QuadStabilizer(frameAspect: detection.imageAspect)
        }
        guard let stabilizer else { return }
        // Only frames where the detector is sure it sees one page count;
        // anything else is "no page" (the stabilizer keeps the last outline
        // through a 0.3 s grace for a single doubtful frame).
        let seenNow = detection?.isConfident == true
        stabilizer.update(with: seenNow ? detection?.quad : nil, at: now)
        quad = stabilizer.quad
        let steady = stabilizer.steadyDuration(at: now)

        if let captured = capturedQuad {
            // Same page still in place: wait. Gone, or moved by more than a
            // fifth of the frame: it's a new page.
            if let quad, stabilizer.distance(Self.center(of: quad), Self.center(of: captured)) < 0.2 {
                instruction = .nextPage
                autoCaptureProgress = 0
                showsOutline = false
                return
            }
            capturedQuad = nil
        }

        instruction = ScanInstruction.evaluate(quad: quad, frameAspect: stabilizer.frameAspect, isStable: steady >= Self.outlineAfter)
        let framedWell = instruction == .ready || instruction == .holdSteady
        guard framedWell else {
            showsOutline = false
            autoCaptureProgress = 0
            return
        }
        // A missed frame keeps the border and ring as they are; real
        // movement restarts the steady clock, which hides the border.
        guard seenNow else { return }
        showsOutline = steady >= Self.outlineAfter
        autoCaptureProgress = showsOutline ? min(1, (steady - Self.outlineAfter) / Self.captureHold) : 0

        // Only shoot once the lens has settled: the ring stays full while
        // it focuses, and the photo is taken the moment it's sharp.
        if autoCapture, showsOutline, autoCaptureProgress >= 1, device?.isAdjustingFocus != true {
            Task { await capture() }
        }
    }

    private static func center(of quad: NormalizedQuad) -> CGPoint {
        let p = quad.points
        return CGPoint(x: p.map(\.x).reduce(0, +) / 4, y: p.map(\.y).reduce(0, +) / 4)
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}
