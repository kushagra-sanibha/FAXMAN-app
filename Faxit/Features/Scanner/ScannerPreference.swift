import Foundation

/// Which scanner the Scan button opens. Faxit's own camera is the default:
/// the border appears when a page is held still, the shutter ring fills,
/// and the page is captured and flattened. In Debug builds a Developer
/// switch opens Apple's VisionKit scanner instead, for comparison.
enum ScannerPreference {
    private static let key = "useAppleScannerInstead"

    static var useFaxitScanner: Bool {
        get {
            #if DEBUG
            !UserDefaults.standard.bool(forKey: key)
            #else
            true
            #endif
        }
        set { UserDefaults.standard.set(!newValue, forKey: key) }
    }
}
