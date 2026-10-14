import Foundation
import Network
import Observation

/// App-wide connectivity, so screens that need the network can say so
/// plainly instead of failing. Injected through the environment.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "app.faxit.network-monitor"))
    }

    deinit {
        monitor.cancel()
    }
}
