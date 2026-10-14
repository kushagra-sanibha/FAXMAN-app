import SwiftUI
import SwiftData
import StoreKit
import UserNotifications

/// "Delete my data": asks our servers to delete everything under this
/// app's anonymous ID and, only once that request succeeds, resets this
/// iPhone to a fresh install. A failed server request leaves local data
/// untouched so nothing is half-deleted.
struct DeleteMyDataView: View {
    private typealias Copy = CopyDeck.DeleteData

    private enum Phase: Equatable {
        case idle
        case deleting
        case failed(offline: Bool)
        case completed(serversFinishBy: Date)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(StoreManager.self) private var storeManager
    @Environment(NetworkMonitor.self) private var network
    @Environment(AppNavigation.self) private var navigation: AppNavigation?

    @State private var phase: Phase = .idle
    @State private var pendingDeletion: PendingDeletion?
    @State private var showsManageSubscriptions = false

    private var hasActiveSubscription: Bool {
        storeManager.hasActiveSendPlan || storeManager.hasActiveNumberRental
    }

    var body: some View {
        Form {
            switch phase {
            case .idle:
                detailSections
            case .deleting:
                deletingSection
            case .failed(let offline):
                failedSection(offline: offline)
            case .completed(let date):
                completedSection(serversFinishBy: date)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.faxitMintBackground)
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase == .deleting || isCompleted)
        .interactiveDismissDisabled(phase == .deleting || isCompleted)
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .deleteConfirmation($pendingDeletion)
    }

    private var isCompleted: Bool {
        if case .completed = phase { return true }
        return false
    }

    // MARK: - Details

    @ViewBuilder
    private var detailSections: some View {
        if hasActiveSubscription {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(Copy.subscriptionWarningTitle, systemImage: "exclamationmark.triangle.fill")
                        .font(.faxitSectionHeader)
                        .foregroundStyle(Color.faxitStatusAmber)
                    Text(Copy.subscriptionWarningBody)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                manageSubscriptionsButton
            }
        }

        Section {
            Text(Copy.intro)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkPrimary)
        }

        Section {
            ForEach(Copy.deletedItems, id: \.self) { item in
                Label {
                    Text(item).font(.faxitBody)
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.faxitStatusRed)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(Copy.deletedHeader)
        } footer: {
            Text(Copy.timingNote)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
        }

        Section {
            Text(Copy.keptBody)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkPrimary)
        } header: {
            Text(Copy.keptHeader)
        }

        if !hasActiveSubscription {
            Section {
                Text(Copy.subscriptionsNote)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkPrimary)
                manageSubscriptionsButton
            } header: {
                Text(Copy.subscriptionsHeader)
            }
        }

        Section {
            if !network.isOnline {
                Label(Copy.offlineNote, systemImage: "wifi.slash")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitStatusAmber)
            }
            deleteButton
        }
    }

    private var manageSubscriptionsButton: some View {
        Button(Copy.manageSubscriptions) { showsManageSubscriptions = true }
            .font(.faxitBody)
            .foregroundStyle(Color.faxitAccent)
            .frame(minHeight: 44)
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: confirmDeletion) {
            Text(Copy.deleteButton)
                .font(.faxitBodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.faxitStatusRed.opacity(network.isOnline ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!network.isOnline)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func confirmDeletion() {
        guard network.isOnline else { return }
        pendingDeletion = PendingDeletion(
            title: Copy.confirmTitle,
            message: Copy.confirmMessage,
            confirmLabel: Copy.confirmAction,
            perform: { Task { await deleteEverything() } }
        )
    }

    // MARK: - Progress and results

    private var deletingSection: some View {
        Section {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(Copy.deletingTitle)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
        }
    }

    private func failedSection(offline: Bool) -> some View {
        Section {
            resultContent(
                systemImage: offline ? "wifi.slash" : "exclamationmark.triangle.fill",
                tint: offline ? .faxitStatusAmber : .faxitStatusRed,
                title: Copy.failedTitle,
                body: offline ? Copy.offlineFailedBody : Copy.failedBody
            )
            if !network.isOnline {
                Label(Copy.offlineNote, systemImage: "wifi.slash")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitStatusAmber)
            }
            Button(Copy.retryAction) {
                Task { await deleteEverything() }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !network.isOnline))
            .disabled(!network.isOnline)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func completedSection(serversFinishBy date: Date) -> some View {
        Section {
            resultContent(
                systemImage: "checkmark.circle.fill",
                tint: .faxitStatusGreen,
                title: Copy.completedTitle,
                body: Copy.completedBody(completesBy: date)
            )
            Button(Copy.doneAction, action: finish)
                .buttonStyle(.faxitPrimary)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private func resultContent(systemImage: String, tint: Color, title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.faxitLargeTitle)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
            Text(body)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    /// Back to Activity, as on a fresh install.
    private func finish() {
        navigation?.selectedTab = .activity
        dismiss()
    }

    // MARK: - Deleting

    private func deleteEverything() async {
        guard network.isOnline else {
            phase = .failed(offline: true)
            return
        }
        phase = .deleting

        let receipt: DataDeletionReceipt
        do {
            receipt = try await FaxProviderContainer.shared.requestDataDeletion(anonymousID: AnonymousIdentity.current)
        } catch FaxProviderError.offline {
            phase = .failed(offline: true)
            return
        } catch {
            // The server still holds the data: keep everything on this
            // iPhone so the person can simply try again.
            phase = .failed(offline: false)
            return
        }

        resetDevice()
        phase = .completed(serversFinishBy: receipt.completesBy)
    }

    /// Removes every row and file this app keeps, then starts over with
    /// fresh settings and a new anonymous ID.
    private func resetDevice() {
        let fileManager = FileManager.default

        for draft in (try? modelContext.fetch(FetchDescriptor<FaxDraft>())) ?? [] {
            PageFileStore.delete(fileNames: draft.pageImageFileNames)
            modelContext.delete(draft)
        }
        for fax in (try? modelContext.fetch(FetchDescriptor<SentFax>())) ?? [] {
            PageFileStore.delete(fileNames: fax.pageImageFileNames)
            if let report = fax.deliveryReportFileURL {
                try? fileManager.removeItem(at: report)
            }
            modelContext.delete(fax)
        }
        for fax in (try? modelContext.fetch(FetchDescriptor<ReceivedFax>())) ?? [] {
            try? fileManager.removeItem(at: fax.pdfFileURL)
            if let thumbnail = fax.thumbnailFileURL {
                try? fileManager.removeItem(at: thumbnail)
            }
            modelContext.delete(fax)
        }
        for profile in (try? modelContext.fetch(FetchDescriptor<SenderProfile>())) ?? [] {
            modelContext.delete(profile)
        }
        try? modelContext.save()

        SignatureStore.delete()

        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()

        settingsStore.resetToDefaults()
        AnonymousIdentity.reset()
    }
}
