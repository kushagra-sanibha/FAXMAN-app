import Foundation

/// Makes the whole app demoable end-to-end with no real backend. Simulates
/// the full provider state machine with real delays via Task.sleep.
final class MockFaxProvider: FaxProvider {
    private var handles: [String: OutgoingFaxRequest] = [:]
    private static var sampleSeeded = false
    /// Export requests in the last 24 hours, for the abuse limits.
    private var exportRequests: [(email: String, at: Date)] = []

    func send(_ request: OutgoingFaxRequest) async throws -> FaxProviderHandle {
        let id = UUID().uuidString
        handles[id] = request
        return FaxProviderHandle(id: id)
    }

    func status(for handle: FaxProviderHandle) -> AsyncStream<FaxProviderStatus> {
        let request = handles[handle.id]
        let scenario = MockScenario.scenario(forNumber: request?.recipientNumber ?? "")

        return AsyncStream { continuation in
            Task {
                continuation.yield(.preparing)
                try? await Task.sleep(for: .seconds(1))
                continuation.yield(.uploading)
                try? await Task.sleep(for: .seconds(1))

                // Events that happen before the recipient's machine ever
                // answers come before `.sending`, in the same order a real
                // line produces them, so the transit route never runs
                // backwards.
                switch scenario {
                case .providerUnavailable:
                    continuation.yield(.providerUnavailable)
                    continuation.finish()
                    return
                case .busyThenSuccess:
                    let maxAttempts = 3
                    for attempt in 1...maxAttempts {
                        continuation.yield(.retrying(attempt: attempt, max: maxAttempts))
                        try? await Task.sleep(for: .seconds(1))
                    }
                default:
                    break
                }

                continuation.yield(.sending)
                try? await Task.sleep(for: .seconds(2))

                switch scenario {
                case .success, .busyThenSuccess:
                    continuation.yield(.delivered)

                case .noAnswer:
                    continuation.yield(.notDelivered(reason: .noAnswer))

                case .notAFaxLine:
                    continuation.yield(.notDelivered(reason: .notAFaxLine))

                case .disconnected:
                    continuation.yield(.notDelivered(reason: .disconnected))

                case .partialDelivery:
                    continuation.yield(.partiallyDelivered(delivered: 3, total: 5))

                case .providerUnavailable:
                    break
                }

                continuation.finish()
            }
        }
    }

    func cancel(_ handle: FaxProviderHandle) async throws {
        handles.removeValue(forKey: handle.id)
    }

    func fetchReceivedFaxes(since: Date?) async throws -> [ReceivedFaxPayload] {
        guard since == nil, !Self.sampleSeeded else { return [] }
        Self.sampleSeeded = true

        try? await Task.sleep(for: .milliseconds(300))

        let sampleDirectory = FileManager.default.temporaryDirectory
        let sampleURL = sampleDirectory.appendingPathComponent("faxit-sample-received.pdf")
        if !FileManager.default.fileExists(atPath: sampleURL.path) {
            FileManager.default.createFile(atPath: sampleURL.path, contents: Data())
        }

        return [
            ReceivedFaxPayload(senderNumberIfAvailable: "(415) 555-0123", receivedAt: .now.addingTimeInterval(-3600), pageCount: 2, pdfFileURL: sampleURL),
            ReceivedFaxPayload(senderNumberIfAvailable: "(212) 555-0100", receivedAt: .now.addingTimeInterval(-86_400), pageCount: 1, pdfFileURL: sampleURL),
            ReceivedFaxPayload(senderNumberIfAvailable: nil, receivedAt: .now.addingTimeInterval(-172_800), pageCount: 4, pdfFileURL: sampleURL)
        ]
    }

    func searchAvailableNumbers(_ search: FaxNumberSearch) async throws -> [AvailableFaxNumber] {
        try await Task.sleep(for: .milliseconds(400))
        let codes = search.isAnyNumber ? AreaCodeDirectory.allAreaCodes(in: search.country) : search.areaCodes
        return codes.flatMap { Self.inventory(areaCode: $0, country: search.country, regionName: search.regionName) }
    }

    func provisionNumber(preferred: AvailableFaxNumber?, matching search: FaxNumberSearch) async throws -> AvailableFaxNumber {
        try await Task.sleep(for: .seconds(1))
        if let preferred { return preferred }
        guard let number = try await searchAvailableNumbers(search).randomElement() else {
            throw FaxProviderError.noNumbersAvailable
        }
        return number
    }

    /// Stable demo stock per area code (seeded by the code), so scrolling
    /// the picker away and back shows the same numbers, like a real
    /// provider's inventory would. Exchanges are 200–999, never an N11
    /// service code or the reserved 555.
    private static func inventory(areaCode: String, country: FaxNumberCountry, regionName: String?) -> [AvailableFaxNumber] {
        var rng = SeededGenerator(seed: UInt64(areaCode) ?? 0)
        let locality = regionName ?? AreaCodeDirectory.regions(forAreaCode: areaCode, in: country).map(\.name).joined(separator: " / ")
        var exchanges = Set<Int>()
        let exchangeCount = Int.random(in: 3...6, using: &rng)
        while exchanges.count < exchangeCount {
            let exchange = Int.random(in: 200...999, using: &rng)
            if exchange % 100 != 11, exchange != 555 { exchanges.insert(exchange) }
        }
        return exchanges.sorted().flatMap { exchange in
            let lines = Set((0..<Int.random(in: 1...4, using: &rng)).map { _ in Int.random(in: 0...9999, using: &rng) })
            return lines.sorted().map { line in
                AvailableFaxNumber(e164: "+1\(areaCode)\(exchange)\(String(format: "%04d", line))", areaCode: areaCode, locality: locality)
            }
        }
    }

    /// SplitMix64 — tiny deterministic generator for the demo inventory.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    func releaseNumber() async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Magic addresses, like MockScenario's numbers: anything starting with
    /// "fail" fails. Limits: 3 per address and 5 per device per 24 hours.
    func requestDataExport(file: URL, email: String, anonymousID: String) async throws -> DataExportReceipt {
        try await Task.sleep(for: .seconds(1.2))
        let dayAgo = Date.now.addingTimeInterval(-86_400)
        exportRequests.removeAll { $0.at < dayAgo }
        let address = email.lowercased()
        if exportRequests.count >= 5 || exportRequests.filter({ $0.email == address }).count >= 3 {
            throw FaxProviderError.rateLimited
        }
        if address.hasPrefix("fail") { throw URLError(.badServerResponse) }
        exportRequests.append((address, .now))
        return DataExportReceipt(linkExpiresAt: .now.addingTimeInterval(86_400))
    }

    func sendFeedback(kind: FeedbackKind, message: String, replyEmail: String?, anonymousID: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
    }

    func requestDataDeletion(anonymousID: String) async throws -> DataDeletionReceipt {
        try await Task.sleep(for: .milliseconds(600))
        return DataDeletionReceipt(completesBy: .now.addingTimeInterval(30 * 86_400))
    }
}
