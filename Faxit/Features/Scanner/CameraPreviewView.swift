import AVFoundation
import SwiftUI

/// Converts page outlines from capture-device-point space to points in the
/// preview, using the preview layer itself — so rotation and the
/// aspect-fill crop are always accounted for exactly. Also carries the
/// rotation a photo needs to come out upright.
@Observable
final class PreviewGeometry {
    fileprivate weak var layer: AVCaptureVideoPreviewLayer?
    /// Shared with the camera so frames are analysed upright.
    let rotationBox = RotationAngleBox()
    /// From the rotation coordinator; 90° = portrait.
    fileprivate(set) var captureRotationAngle: CGFloat = 90 {
        didSet { rotationBox.value = captureRotationAngle }
    }
    /// The rotation the preview is shown with. Photos use this, not the
    /// gravity-based capture angle, so a page shot with the phone held flat
    /// over a table comes out exactly as it looked on screen.
    fileprivate(set) var photoRotationAngle: CGFloat = 90

    func viewPoints(for quad: NormalizedQuad) -> [CGPoint]? {
        guard let layer else { return nil }
        return quad.points.map { layer.layerPointConverted(fromCaptureDevicePoint: $0) }
    }
}

/// Live camera preview (AVCaptureVideoPreviewLayer), filling its frame.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Set once the session has a camera, so the preview can follow its rotation.
    let device: AVCaptureDevice?
    let geometry: PreviewGeometry

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        // The whole frame, nothing cropped: what you see is exactly what the
        // scanner analyses, so "all four corners in view" means on screen too.
        view.previewLayer.videoGravity = .resizeAspect
        geometry.layer = view.previewLayer
        return view
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {
        view.follow(device, geometry: geometry)
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var observations: [NSKeyValueObservation] = []

        /// Keeps the preview upright as the phone rotates (iOS 17 rotation
        /// API) and records the angle photos need.
        func follow(_ device: AVCaptureDevice?, geometry: PreviewGeometry) {
            guard let device, rotationCoordinator?.device != device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            rotationCoordinator = coordinator
            applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
            geometry.photoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
            geometry.captureRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
            observations = [
                coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self, weak geometry] _, change in
                    guard let angle = change.newValue else { return }
                    DispatchQueue.main.async {
                        self?.applyPreviewRotation(angle)
                        geometry?.photoRotationAngle = angle
                    }
                },
                coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak geometry] _, change in
                    guard let angle = change.newValue else { return }
                    DispatchQueue.main.async { geometry?.captureRotationAngle = angle }
                },
            ]
        }

        private func applyPreviewRotation(_ angle: CGFloat) {
            guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}
