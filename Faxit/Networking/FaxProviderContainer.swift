import Foundation

/// Single shared provider instance. Swap `shared` to a real FaxProvider
/// conformance in Phase 6 without touching any view code.
enum FaxProviderContainer {
    static let shared: FaxProvider = MockFaxProvider()
}
