import AVFoundation

/// Gates the document scanner on real camera authorization — never present
/// VNDocumentCameraViewController and hope for the best, since a denied or
/// restricted camera leaves it stuck on a blank capture session.
enum CameraAccessManager {
    enum Status {
        case authorized
        case needsPrimer
        case deniedOrRestricted
    }

    /// Call before showing the scanner. `needsPrimer` means permission has
    /// never been asked for — show our own explanation first, then call
    /// `requestAccess` from the primer's "Continue" action.
    static func currentStatus() -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .needsPrimer
        case .denied, .restricted: .deniedOrRestricted
        @unknown default: .deniedOrRestricted
        }
    }

    static func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}
