import AVFoundation

/// Owns the capture session: back camera, live frames for detection, and a
/// photo output for the final capture. All session work happens on
/// `sessionQueue`, all frame work on `videoQueue` — never the main thread.
///
/// Thread safety: `session`, inputs, outputs and `inFlightCaptures` are only
/// touched on `sessionQueue` (AVFoundation's own rule), the detector only on
/// `videoQueue`, and `onDetection` is a `let` set at init.
nonisolated final class CameraService: NSObject, @unchecked Sendable {
    nonisolated enum SetupError: Error {
        case noCamera
        case configurationFailed
    }

    nonisolated enum CaptureError: Error {
        /// The lens never settled; no photo was taken rather than a blurry one.
        case notFocused
    }

    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()

    private let sessionQueue = DispatchQueue(label: "app.faxit.camera.session")
    private let videoQueue = DispatchQueue(label: "app.faxit.camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let detector = DocumentDetector()
    private let onDetection: @Sendable (DocumentDetector.Detection?) -> Void
    /// How frames must turn to look upright; updated as the phone rotates.
    private let rotation: RotationAngleBox
    private var device: AVCaptureDevice?
    /// Keeps each photo's delegate alive until it finishes.
    private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]

    /// `onDetection` is called on a background queue with each analysed
    /// frame's page outline in capture-device-point space (sensor
    /// orientation, top-left origin), or nil when no page was found.
    init(rotation: RotationAngleBox, onDetection: @escaping @Sendable (DocumentDetector.Detection?) -> Void) {
        self.rotation = rotation
        self.onDetection = onDetection
    }

    static var backCamera: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Configures on first call, then starts the session. Returns the camera
    /// device so the preview can follow its rotation.
    func start() async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    let device = try configureIfNeeded()
                    if !session.isRunning { session.startRunning() }
                    continuation.resume(returning: device)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// The flashlight, for dim rooms. No-op on devices without one.
    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    /// Longest the shutter waits for the lens to settle before giving up.
    private static let focusTimeout: TimeInterval = 3

    /// Takes a full-quality photo, rotated to `rotationAngle` (from the
    /// preview's rotation coordinator) so it comes out upright. Only ever
    /// shoots with the lens focused: a photo taken mid-focus has soft text
    /// no filter can recover. If the lens is still focusing after
    /// `focusTimeout`, no photo is taken and `CaptureError.notFocused` is thrown.
    func capturePhoto(rotationAngle: CGFloat) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                let deadline = Date.now.addingTimeInterval(Self.focusTimeout)
                while device?.isAdjustingFocus == true {
                    guard Date.now < deadline else {
                        continuation.resume(throwing: CaptureError.notFocused)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.02)
                }
                if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { [self] result in
                    sessionQueue.async { self.inFlightCaptures[id] = nil }
                    continuation.resume(with: result)
                }
                inFlightCaptures[id] = delegate
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private func configureIfNeeded() throws -> AVCaptureDevice {
        if let device { return device }
        guard let camera = Self.backCamera else { throw SetupError.noCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            throw SetupError.configurationFailed
        }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput), session.canAddOutput(photoOutput) else {
            throw SetupError.configurationFailed
        }
        session.addOutput(videoOutput)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Paper is close and flat: keep focus and exposure continuously adjusting.
        if (try? camera.lockForConfiguration()) != nil {
            if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
            if camera.isAutoFocusRangeRestrictionSupported { camera.autoFocusRangeRestriction = .near }
            camera.unlockForConfiguration()
        }

        device = camera
        return camera
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        switch detector.detect(in: pixelBuffer, rotationAngle: rotation.value) {
        case .dropped:
            return
        case .analysed(let detection):
            onDetection(detection)
        }
    }
}

private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    nonisolated enum CaptureError: Error { case noImageData }

    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CaptureError.noImageData))
        }
    }
}
