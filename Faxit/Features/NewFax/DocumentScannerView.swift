import SwiftUI
import VisionKit

/// Thin wrapper over VisionKit's document camera — auto edge detection and
/// autocapture come for free from the system controller. Camera permission
/// must already be authorized before this is presented (see
/// CameraAccessManager) — VisionKit does not surface a denied/restricted
/// camera as a usable state of its own.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void
    let onCancel: () -> Void
    var onFailure: (Error) -> Void = { _ in }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel, onFailure: onFailure)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void
        let onFailure: (Error) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void, onFailure: @escaping (Error) -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
            self.onFailure = onFailure
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: pageIndex))
            }
            onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFailure(error)
        }
    }
}
