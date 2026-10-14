import Foundation

/// The rotation that makes camera frames look upright to the user, written
/// on the main thread (from the preview's rotation coordinator) and read on
/// the video queue for every analysed frame.
nonisolated final class RotationAngleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var angle: CGFloat = 90

    var value: CGFloat {
        get { lock.withLock { angle } }
        set { lock.withLock { angle = newValue } }
    }
}
