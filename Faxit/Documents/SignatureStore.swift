import UIKit

/// The person's most recent signature — one transparent PNG kept
/// on-device only. Removed by "Delete my data".
enum SignatureStore {
    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("signature.png")
    }

    @discardableResult
    static func save(_ signature: UIImage) -> Bool {
        guard let data = signature.pngData() else { return false }
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
