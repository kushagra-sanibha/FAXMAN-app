import Foundation
import SwiftData

/// Shared send/retry logic used by the initial send (SendingStatusView) and
/// by "Try the same number again" from a failure screen — both need the
/// exact same upload-attempt-then-status-stream behavior.
enum FaxSendRunner {
    static let maxUploadAttempts = 3

    @MainActor
    static func run(fax: SentFax, provider: FaxProvider, modelContext: ModelContext) async {
        fax.status = .preparing
        try? modelContext.save()

        // The cover page (if any) is already rendered into the first page
        // image by FaxSubmission, so the provider never adds its own.
        let request = OutgoingFaxRequest(recipientNumber: fax.recipientNumber, pageImageURLs: fax.pageImageURLs, coverPage: nil)

        var handle: FaxProviderHandle?
        for attempt in 1...maxUploadAttempts {
            do {
                handle = try await provider.send(request)
                break
            } catch {
                if attempt < maxUploadAttempts {
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }

        guard let handle else {
            // The pass was already charged at purchase time, but the fax
            // never reached the provider — the app's ledger never marks
            // this send consumed, matching the "never charged on a send
            // that didn't go through" guarantee.
            fax.status = .providerUnavailable
            try? modelContext.save()
            await notifyOutcome(of: fax.status, modelContext: modelContext)
            return
        }

        fax.providerHandleID = handle.id
        try? modelContext.save()

        var hasNotified = false
        for await status in provider.status(for: handle) {
            let mapped = SentFaxStatusMapper.map(status)
            fax.status = mapped
            if case .retrying(let attempt, _) = mapped {
                fax.retryCount = attempt
            }
            try? modelContext.save()
            if mapped.isTerminal && !hasNotified {
                hasNotified = true
                await notifyOutcome(of: mapped, modelContext: modelContext)
            }
        }
    }

    /// Posts the generic delivery-update notification for a finished fax.
    /// Cancelled faxes were the user's own action, so they get none.
    @MainActor
    private static func notifyOutcome(of status: FaxStatus, modelContext: ModelContext) async {
        let outcome: NotificationManager.FaxUpdateOutcome
        switch status {
        case .delivered: outcome = .delivered
        case .partiallyDelivered: outcome = .partiallyDelivered
        case .notDelivered, .providerUnavailable: outcome = .notDelivered
        case .preparing, .uploading, .sending, .retrying, .cancelled: return
        }
        guard let settings = try? modelContext.fetch(FetchDescriptor<AppSettingsModel>()).first else { return }
        await NotificationManager.postFaxUpdate(outcome, settings: settings)
    }
}
