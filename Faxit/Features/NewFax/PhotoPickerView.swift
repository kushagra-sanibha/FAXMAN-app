import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Wraps PHPickerViewController for picking pages straight from the photo
/// library — the one upload source Files can't reach, since
/// UIDocumentPickerViewController never surfaces the Photos library itself.
///
/// Hands back the encoded image data (not decoded UIImages) so decoding and
/// downsampling happen once, off the main actor, in DocumentImportHelper.
struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: ([DocumentImportHelper.PickedPhoto], _ failedCount: Int) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0
        configuration.selection = .ordered
        configuration.filter = .images
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([DocumentImportHelper.PickedPhoto], Int) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping ([DocumentImportHelper.PickedPhoto], Int) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onCancel()
                return
            }
            let providers = results.map(\.itemProvider)
            Task { @MainActor in
                // Loaded concurrently but collected by index — the old
                // version wrote into a shared array from several background
                // completion handlers at once (a data race that could crash
                // or drop photos), and lost the user's selection order.
                let loaded = await withTaskGroup(of: (Int, DocumentImportHelper.PickedPhoto?).self) { group in
                    for (index, provider) in providers.enumerated() {
                        group.addTask { (index, await Self.loadPhoto(from: provider)) }
                    }
                    var ordered = [DocumentImportHelper.PickedPhoto?](repeating: nil, count: providers.count)
                    for await (index, photo) in group { ordered[index] = photo }
                    return ordered
                }
                let photos = loaded.compactMap { $0 }
                onPick(photos, loaded.count - photos.count)
            }
        }

        private nonisolated static func loadPhoto(from provider: NSItemProvider) async -> DocumentImportHelper.PickedPhoto? {
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
            let name = provider.suggestedName
            return await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data.map { DocumentImportHelper.PickedPhoto(data: $0, suggestedName: name) })
                }
            }
        }
    }
}
