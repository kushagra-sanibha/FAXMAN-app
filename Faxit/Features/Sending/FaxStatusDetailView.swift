import SwiftUI
import SwiftData
import StoreKit

/// One view, branching per FaxStatus. "Delivered" always states plainly what
/// it does and does not mean; failures always show a reason plus a next step
/// plus the never-charged assurance.
struct FaxStatusDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.requestReview) private var requestReview
    /// Optional so previews / contexts outside RootTabView still work.
    @Environment(AppNavigation.self) private var navigation: AppNavigation?

    let fax: SentFax
    let provider: FaxProvider
    var attachLiveIfNeeded: Bool = false
    var onDone: (() -> Void)? = nil

    @State private var isRetrying = false
    @State private var showChangeNumber = false
    @State private var reportURL: URL?
    @State private var notificationPermission: NotificationManager.NotificationPermission?
    @State private var hidesNotificationPrompt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fax.status.isTerminal ? "Fax to" : "Sending to")
                            .font(.faxitCaption)
                            .foregroundStyle(Color.faxitInkSecondary)
                        Text(PhoneNumberFormatter.displayString(fax.recipientNumber))
                            .font(.faxitSectionHeader)
                            .foregroundStyle(Color.faxitInkPrimary)
                    }
                    Spacer()
                    StatusChip(status: fax.status)
                }

                SectionCard {
                    FaxTransitTimeline(status: fax.status)
                        .padding(16)
                }

                if showsNotificationPrompt {
                    NotificationPermissionCard(
                        onNotifyMe: requestNotificationPermission,
                        onNotNow: { hidesNotificationPrompt = true }
                    )
                    .transition(.opacity)
                }

                Group {
                    switch fax.status {
                    case .preparing, .uploading, .sending, .retrying:
                        // The route above already narrates in-progress states.
                        EmptyView()

                    case .delivered:
                        deliveredBody

                    case .partiallyDelivered(let delivered, let total):
                        Text(CopyDeck.Status.partiallyDelivered(delivered, total))
                            .foregroundStyle(Color.faxitStatusAmber)
                        reportButton

                    case .notDelivered(let reason):
                        failureBody(reasonText: failureReasonText(reason), retryable: false)

                    case .providerUnavailable:
                        Text(CopyDeck.Status.providerUnavailable)
                            .foregroundStyle(Color.faxitStatusRed)
                        retryControls(showChangeNumberOption: false)

                    case .cancelled:
                        Text("This fax was cancelled.")
                    }
                }
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.35), value: fax.status.kind)
        }
        .background(Color.faxitMintBackground)
        .safeAreaInset(edge: .bottom) {
            // Only once the fax is finished — closing mid-send tore down
            // the view running the send and left it stuck "in progress".
            if let onDone, fax.status.isTerminal {
                Button("Done", action: onDone)
                    .buttonStyle(.faxitPrimary)
                    .padding(16)
                    .background(Color.faxitMintBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: fax.status.isTerminal)
        .sheet(isPresented: $showChangeNumber) {
            ChangeNumberSheet(number: fax.recipientNumber) { newNumber in
                fax.recipientNumber = newNumber
                try? modelContext.save()
                retry()
            }
        }
        .task {
            notificationPermission = await NotificationManager.permission()
        }
        .animation(.easeInOut(duration: 0.25), value: showsNotificationPrompt)
        .task {
            if attachLiveIfNeeded && !fax.status.isTerminal {
                await reattach()
            }
            // Only count a delivery once, when it happens live — opening
            // an old delivered fax from Activity used to bump the counter
            // again each time, triggering the review prompt early.
            if fax.status == .delivered && !attachLiveIfNeeded {
                handleDeliveredSideEffects()
            }
        }
        .onChange(of: fax.status) { old, new in
            // The live send flow now shows this view from the start, so
            // the delivery is observed here rather than on appear.
            if new == .delivered, old != .delivered, !attachLiveIfNeeded {
                handleDeliveredSideEffects()
                handleFirstDeliveryIfNeeded()
            }
        }
    }

    /// Asked only here, mid-send, never on launch: the fax in flight is the
    /// one-line reason the user sees.
    private var showsNotificationPrompt: Bool {
        !fax.status.isTerminal
            && !hidesNotificationPrompt
            && notificationPermission == .notAsked
            && settingsStore.settings.notifyDeliveryUpdates
    }

    private func requestNotificationPermission() {
        hidesNotificationPrompt = true
        Task {
            await NotificationManager.requestPermission()
            settingsStore.settings.hasRequestedNotificationPermission = true
            settingsStore.save()
            notificationPermission = await NotificationManager.permission()
        }
    }

    private var deliveredBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CopyDeck.Status.delivered(PhoneNumberFormatter.displayString(fax.recipientNumber)))
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitStatusGreen)
            Text(CopyDeck.Status.deliveredNote)
            reportButton
        }
    }

    private var reportButton: some View {
        Group {
            if let reportURL {
                ShareLink(item: reportURL) {
                    Text(CopyDeck.Status.downloadReport)
                }
                .buttonStyle(.faxitSecondary)
            } else {
                Button(CopyDeck.Status.downloadReport) {
                    let url = DeliveryReportGenerator.generate(for: fax)
                    fax.deliveryReportFileURL = url
                    try? modelContext.save()
                    reportURL = url
                }
                .buttonStyle(.faxitSecondary)
            }
        }
    }

    private func failureBody(reasonText: String, retryable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CopyDeck.Status.failedHeadline)
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitStatusRed)
            Text(CopyDeck.Status.failureReason(reasonText))
            Text(CopyDeck.Status.notChargedNote)
                .foregroundStyle(Color.faxitInkPrimary)
            retryControls(showChangeNumberOption: true)
        }
    }

    private func retryControls(showChangeNumberOption: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRetrying {
                ProgressView()
            } else {
                Button(CopyDeck.Status.tryAgainSameNumber) { retry() }
                if showChangeNumberOption {
                    Button(CopyDeck.Status.checkOrChangeNumber) { showChangeNumber = true }
                }
                Button(CopyDeck.Status.getHelp) { openHelp() }
            }
        }
        .font(.faxitCaptionSemibold)
        .foregroundStyle(Color.faxitAccent)
    }

    private func retry() {
        isRetrying = true
        Task {
            await FaxSendRunner.run(fax: fax, provider: provider, modelContext: modelContext)
            isRetrying = false
        }
    }

    private func openHelp() {
        if let url = URL(string: "mailto:support@faxit.app") {
            UIApplication.shared.open(url)
        }
    }

    private func failureReasonText(_ reason: FailureReason) -> String {
        switch reason {
        case .busy: "The line was busy."
        case .noAnswer: "Nobody answered at this number."
        case .notAFaxLine: "This doesn't look like a fax line."
        case .disconnected: "This number isn't in service."
        case .invalidNumber: "That number doesn't look complete."
        case .uploadFailed: "We couldn't upload your pages."
        case .insufficientStorage: "Not enough space on this iPhone."
        case .unknown: "Something went wrong on our end."
        }
    }

    private func reattach() async {
        guard !fax.providerHandleID.isEmpty else { return }
        let handle = FaxProviderHandle(id: fax.providerHandleID)
        for await status in provider.status(for: handle) {
            fax.status = SentFaxStatusMapper.map(status)
            try? modelContext.save()
        }
    }

    /// The very first delivered fax: after a beat on the "Delivered" state,
    /// close the send flow back to the home screen and point the user at
    /// Receive. Later deliveries keep the normal Done button.
    private func handleFirstDeliveryIfNeeded() {
        guard let onDone, let navigation,
              !settingsStore.settings.hasShownFirstDeliveryReceiveTip else { return }
        // "First" means first ever, not first since this setting existed —
        // someone with earlier deliveries shouldn't get the intro now.
        let deliveredKind = FaxStatus.delivered.kind
        let deliveredCount = (try? modelContext.fetchCount(FetchDescriptor<SentFax>(
            predicate: #Predicate { $0.statusKind == deliveredKind }
        ))) ?? 0
        settingsStore.settings.hasShownFirstDeliveryReceiveTip = true
        settingsStore.save()
        guard deliveredCount <= 1 else { return }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            onDone()
            // Let the sheet finish sliding away before the bubble pops up.
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
                navigation.presentReceiveTip()
            }
        }
    }

    private func handleDeliveredSideEffects() {
        guard !settingsStore.settings.hasRequestedReview else { return }
        settingsStore.settings.deliveredFaxCountForRatingPrompt += 1
        settingsStore.save()
        if settingsStore.settings.deliveredFaxCountForRatingPrompt == 2 {
            settingsStore.settings.hasRequestedReview = true
            settingsStore.save()
            requestReview()
        }
    }
}
