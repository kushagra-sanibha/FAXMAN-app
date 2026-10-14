import SwiftUI
import SwiftData

enum AppTab: Hashable, CaseIterable {
    case activity
    /// "Receive" (get a number) until the person has one, then "Inbox".
    case receive
    case settings
}

struct RootTabView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(AppSettingsStore.self) private var settingsStore
    @State private var navigation: AppNavigation
    /// Bottom safe-area inset of the tab content — i.e. the tab bar's
    /// height plus the home indicator — measured, not guessed.
    @State private var tabBarInset: CGFloat = 0

    init(navigation: AppNavigation = AppNavigation()) {
        _navigation = State(initialValue: navigation)
    }

    /// Has a number and its subscription is active. Until StoreKit has
    /// answered, the stored number alone decides, so a subscriber's tab
    /// doesn't flash "Receive" on every launch.
    private var hasReceiveNumber: Bool {
        settingsStore.settings.ownFaxNumber != nil
            && (storeManager.hasActiveNumberRental || !storeManager.hasLoadedEntitlements)
    }

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("Activity", systemImage: "house.fill", value: AppTab.activity) {
                ActivityView()
                    .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { tabBarInset = $0 }
            }
            Tab(
                hasReceiveNumber ? "Inbox" : "Receive",
                systemImage: hasReceiveNumber ? "tray.fill" : "tray.and.arrow.down.fill",
                value: AppTab.receive
            ) {
                if hasReceiveNumber {
                    InboxView()
                } else {
                    ReceiveView()
                }
            }
            // Highlights the tab the bubble points at.
            .badge(navigation.isReceiveTipVisible ? Text("New") : nil)
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(.faxitAccent)
        // Drawn above the whole TabView, not inside the Activity tab: content
        // inside a tab sits under the tab bar's Liquid Glass edge effect,
        // which blurred and washed out the bubble.
        .overlay { receiveTip }
        .environment(navigation)
        .onChange(of: navigation.selectedTab) { _, tab in
            // Leaving Activity any other way also retires the tip.
            if tab != .activity { navigation.dismissReceiveTip() }
        }
    }

    @ViewBuilder
    private var receiveTip: some View {
        if navigation.isReceiveTipVisible {
            GeometryReader { geo in
                let horizontalPadding: CGFloat = 16
                VStack {
                    Spacer()
                    ReceiveTipBubble(
                        hasOwnNumber: hasReceiveNumber,
                        tailX: Self.tabCenterX(.receive, width: geo.size.width) - horizontalPadding,
                        onOpen: { withAnimation(.snappy) { navigation.openReceiveFromTip() } },
                        onDismiss: { withAnimation(.snappy) { navigation.dismissReceiveTip() } }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, tabBarInset + 4)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(
                .scale(scale: 0.6, anchor: UnitPoint(x: 0.375, y: 1))
                .combined(with: .opacity)
            )
        }
    }

    /// Horizontal centre of a tab item: the floating tab bar is inset from
    /// the screen edges and spaces its items evenly.
    private static func tabCenterX(_ tab: AppTab, width: CGFloat) -> CGFloat {
        let barInset: CGFloat = 24
        let index = CGFloat(AppTab.allCases.firstIndex(of: tab) ?? 0)
        let itemWidth = (width - barInset * 2) / CGFloat(AppTab.allCases.count)
        return barInset + itemWidth * (index + 0.5)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: SenderProfile.self, AppSettingsModel.self, FaxDraft.self, SentFax.self, ReceivedFax.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    RootTabView()
        .faxitTypography()
        .environment(AppSettingsStore(modelContext: container.mainContext))
        .environment(StoreManager())
        .environment(NetworkMonitor())
        .modelContainer(container)
}

#Preview("Receive tip after first delivery") {
    let container = try! ModelContainer(
        for: SenderProfile.self, AppSettingsModel.self, FaxDraft.self, SentFax.self, ReceivedFax.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let navigation = AppNavigation()
    navigation.presentReceiveTip()
    return RootTabView(navigation: navigation)
        .faxitTypography()
        .environment(AppSettingsStore(modelContext: container.mainContext))
        .environment(StoreManager())
        .environment(NetworkMonitor())
        .modelContainer(container)
}
