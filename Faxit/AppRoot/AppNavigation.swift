import Observation

/// App-wide navigation state shared through the environment, so screens deep
/// in a sheet (like the send flow) can steer the tab bar — e.g. returning
/// home and pointing at the Receive tab after the first delivered fax.
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .activity
    /// The one-time "get faxes back" bubble over the Receive tab.
    private(set) var isReceiveTipVisible = false

    func presentReceiveTip() {
        selectedTab = .activity
        isReceiveTipVisible = true
    }

    func dismissReceiveTip() {
        isReceiveTipVisible = false
    }

    /// Tapping the bubble takes you where it points.
    func openReceiveFromTip() {
        isReceiveTipVisible = false
        selectedTab = .receive
    }
}
