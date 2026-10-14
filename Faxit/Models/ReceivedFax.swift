import Foundation
import SwiftData

@Model
final class ReceivedFax {
    var id: UUID
    var senderNumberIfAvailable: String?
    var receivedAt: Date
    var pageCount: Int
    var pdfFileURL: URL
    var thumbnailFileURL: URL?
    var isRead: Bool

    init(
        id: UUID = UUID(),
        senderNumberIfAvailable: String? = nil,
        receivedAt: Date = .now,
        pageCount: Int,
        pdfFileURL: URL,
        thumbnailFileURL: URL? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.senderNumberIfAvailable = senderNumberIfAvailable
        self.receivedAt = receivedAt
        self.pageCount = pageCount
        self.pdfFileURL = pdfFileURL
        self.thumbnailFileURL = thumbnailFileURL
        self.isRead = isRead
    }
}
