import Foundation

extension CopyDeck {
    /// Faxit's own document camera.
    enum Scanner {
        static let title = "Scan pages"
        static let close = "Close"
        static let deniedTitle = "Camera access is off"
        static let deniedMessage = "Allow camera access in Settings to scan pages. You can still add pages from Photos or Files."
        static let openSettings = "Open Settings"
        static let failedTitle = "The camera couldn't start"
        static let failedMessage = "Another app may be using it. Close other camera apps and try again."
        static let tryAgain = "Try again"

        static func instruction(_ instruction: ScanInstruction) -> String {
            switch instruction {
            case .findPage: "Move your phone on top of the page"
            case .holdFlat: "Hold your phone flat over the page"
            case .fitCorners: "Move back — fit all four corners"
            case .moveCloser: "Move closer to the page"
            case .holdSteady: "Hold steady…"
            case .ready: "Hold still — capturing"
            case .nextPage: "Got it! Place the next page"
            }
        }

        static let autoOn = "Auto"
        static let autoOff = "Manual"
        static let autoHint = "Auto takes the photo when the page is in view and still."
        static let torchOn = "Turn on flashlight"
        static let torchOff = "Turn off flashlight"
        static let shutter = "Take photo"
        static let done = "Done"
        static let undoLastPage = "Remove last page"
        static func pageCount(_ count: Int) -> String { "\(count) page\(count == 1 ? "" : "s")" }

        static let sampleTitle = "No camera here"
        static let sampleMessage = "This runs the same page detection and straightening on a sample or a photo."
        static let useSample = "Sample page"
        static let choosePhoto = "Choose photo"
        static let addThisPage = "Add this page"
        static let noPageFound = "No page found"
        static func foundWith(_ method: String) -> String { "Page found (\(method))" }
        static let detecting = "Looking for the page…"

        static let developerSection = "Developer"
        static let previewEntry = "Open new scanner"
        static let useForScanning = "Use Faxit scanner for Scan"
        static let useForScanningFooter = "Debug builds only. On by default. Turn off to compare with Apple's scanner."
    }
}
