import UIKit
import SwiftData

/// Plain values copied from SwiftData on the main actor, so the PDF can be
/// built off the main actor without touching any `@Model` object.
nonisolated struct DataExportSnapshot: Sendable {
    nonisolated struct Field: Sendable {
        let label: String
        let value: String
    }

    nonisolated struct SentFaxEntry: Sendable {
        let date: Date
        let recipient: String
        let pageCount: Int
        let status: String
        let paymentMethod: String
        let price: String
        let pageImageURLs: [URL]
    }

    nonisolated struct ReceivedFaxEntry: Sendable {
        let date: Date
        let sender: String
        let pageCount: Int
        let pdfFileURL: URL
    }

    nonisolated struct DraftEntry: Sendable {
        let lastEditedAt: Date
        let recipient: String
        let pageCount: Int
        let pageImageURLs: [URL]
    }

    let appName: String
    let generatedAt: Date
    /// Empty when no sender info was ever saved.
    let senderInfo: [Field]
    let settings: [Field]
    let sentFaxes: [SentFaxEntry]
    let receivedFaxes: [ReceivedFaxEntry]
    let drafts: [DraftEntry]
}

extension DataExportSnapshot {
    private typealias Copy = CopyDeck.ExportData.PDF

    /// Reads everything the export covers. Main actor only: it reads
    /// `@Model` objects and main-actor formatters.
    @MainActor
    static func capture(from context: ModelContext, settings: AppSettingsModel) throws -> DataExportSnapshot {
        let sent = try context.fetch(FetchDescriptor<SentFax>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        let received = try context.fetch(FetchDescriptor<ReceivedFax>(sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]))
        let drafts = try context.fetch(FetchDescriptor<FaxDraft>(sortBy: [SortDescriptor(\.lastEditedAt, order: .reverse)]))
        let profile = try context.fetch(FetchDescriptor<SenderProfile>()).first

        return DataExportSnapshot(
            appName: AppInfo.appName,
            generatedAt: .now,
            senderInfo: senderFields(profile),
            settings: settingsFields(settings),
            sentFaxes: sent.map { fax in
                SentFaxEntry(
                    date: fax.createdAt,
                    recipient: PhoneNumberFormatter.displayString(fax.recipientNumber),
                    pageCount: fax.pageCount,
                    status: statusText(fax.status),
                    paymentMethod: fax.paymentMethod == .oneTimePass ? Copy.paymentOneTime : Copy.paymentPlan,
                    price: priceText(cents: fax.pricePaidCents, method: fax.paymentMethod),
                    pageImageURLs: fax.pageImageURLs
                )
            },
            receivedFaxes: received.map { fax in
                ReceivedFaxEntry(
                    date: fax.receivedAt,
                    sender: fax.senderNumberIfAvailable.map(PhoneNumberFormatter.displayString) ?? Copy.unknownSender,
                    pageCount: fax.pageCount,
                    pdfFileURL: fax.pdfFileURL
                )
            },
            drafts: drafts.map { draft in
                DraftEntry(
                    lastEditedAt: draft.lastEditedAt,
                    recipient: draft.recipientNumberRaw.isEmpty
                        ? Copy.noRecipientYet
                        : PhoneNumberFormatter.displayString(draft.recipientNumberRaw),
                    pageCount: draft.pageCount,
                    pageImageURLs: draft.pageImageURLs
                )
            }
        )
    }

    @MainActor
    private static func senderFields(_ profile: SenderProfile?) -> [Field] {
        guard let profile else { return [] }
        return [
            Field(label: Copy.senderName, value: profile.name),
            Field(label: Copy.senderCompany, value: profile.company),
            Field(label: Copy.senderPhone, value: profile.phone.isEmpty ? "" : PhoneNumberFormatter.displayString(profile.phone)),
            Field(label: Copy.senderEmail, value: profile.email),
        ].filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @MainActor
    private static func settingsFields(_ settings: AppSettingsModel) -> [Field] {
        var fields = [
            Field(label: Copy.defaultCoverPage, value: settings.defaultCoverPage.title),
            Field(label: Copy.deliveryNotifications, value: settings.notifyDeliveryUpdates ? Copy.on : Copy.off),
            Field(
                label: Copy.quietHours,
                value: settings.quietHoursEnabled
                    ? Copy.quietHoursRange(timeText(settings.quietHoursStartMinute), timeText(settings.quietHoursEndMinute))
                    : Copy.off
            ),
            Field(label: Copy.appearance, value: settings.appearanceMode?.title ?? Copy.appearanceDevice),
            Field(label: Copy.appLock, value: settings.pinLockEnabled ? Copy.on : Copy.off),
        ]
        if let number = settings.ownFaxNumber, !number.isEmpty {
            fields.append(Field(label: Copy.ownFaxNumber, value: PhoneNumberFormatter.displayString(number)))
        }
        return fields
    }

    private static func timeText(_ minutesAfterMidnight: Int) -> String {
        let date = Calendar.current.date(
            bySettingHour: minutesAfterMidnight / 60,
            minute: minutesAfterMidnight % 60,
            second: 0,
            of: .now
        ) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private static func statusText(_ status: FaxStatus) -> String {
        switch status {
        case .preparing: Copy.statusPreparing
        case .uploading: Copy.statusUploading
        case .sending: Copy.statusSending
        case .retrying: Copy.statusRetrying
        case .partiallyDelivered(let delivered, let total): Copy.statusPartial(delivered, total)
        case .delivered: Copy.statusDelivered
        case .notDelivered: Copy.statusNotDelivered
        case .providerUnavailable: Copy.statusUnavailable
        case .cancelled: Copy.statusCancelled
        }
    }

    private static func priceText(cents: Int?, method: FaxPaymentMethod) -> String {
        if let cents {
            let currency = Locale.current.currency?.identifier ?? "USD"
            return (Decimal(cents) / 100).formatted(.currency(code: currency))
        }
        return method == .planAllowance ? Copy.priceIncluded : Copy.priceUnknown
    }
}

/// Builds the single PDF behind "Export my data": a summary, history
/// tables, then every page image and every received page. Runs off the
/// main actor; the file lives in a private temporary folder that the
/// caller removes with `discard(_:)` once the request has finished.
nonisolated enum DataExportBuilder {
    private typealias Copy = CopyDeck.ExportData.PDF

    static func build(_ snapshot: DataExportSnapshot) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try render(snapshot)
        }.value
    }

    /// Removes the export file and its temporary folder.
    static func discard(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private static func render(_ snapshot: DataExportSnapshot) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("\(snapshot.appName) data export.pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: Copy.title(appName: snapshot.appName),
            kCGPDFContextCreator as String: snapshot.appName,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: PDFLayout.pageRect, format: format)

        do {
            try renderer.writePDF(to: fileURL) { context in
                let layout = PDFLayout(context: context)
                drawSummary(snapshot, in: layout)
                drawTables(snapshot, in: layout)
                drawPages(snapshot, in: layout)
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return fileURL
    }

    // MARK: - Sections

    private static func drawSummary(_ snapshot: DataExportSnapshot, in layout: PDFLayout) {
        layout.newPage()
        layout.text(Copy.title(appName: snapshot.appName), style: .title)
        layout.text(Copy.generated(snapshot.generatedAt), style: .caption, spacingAfter: 20)

        layout.text(Copy.senderHeader, style: .heading)
        if snapshot.senderInfo.isEmpty {
            layout.text(Copy.senderEmpty, style: .body, spacingAfter: 16)
        } else {
            layout.table(columns: [0.3, 0.7], header: nil, rows: snapshot.senderInfo.map { [$0.label, $0.value] })
        }

        layout.text(Copy.settingsHeader, style: .heading)
        layout.table(columns: [0.3, 0.7], header: nil, rows: snapshot.settings.map { [$0.label, $0.value] })
    }

    private static func drawTables(_ snapshot: DataExportSnapshot, in layout: PDFLayout) {
        layout.text(Copy.sentHeader, style: .heading)
        if snapshot.sentFaxes.isEmpty {
            layout.text(Copy.sentEmpty, style: .body, spacingAfter: 16)
        } else {
            layout.table(
                columns: [0.2, 0.2, 0.08, 0.2, 0.18, 0.14],
                header: [Copy.columnDate, Copy.columnRecipient, Copy.columnPages, Copy.columnStatus, Copy.columnPayment, Copy.columnPrice],
                rows: snapshot.sentFaxes.map {
                    [dateText($0.date), $0.recipient, "\($0.pageCount)", $0.status, $0.paymentMethod, $0.price]
                }
            )
        }

        layout.text(Copy.receivedHeader, style: .heading)
        if snapshot.receivedFaxes.isEmpty {
            layout.text(Copy.receivedEmpty, style: .body, spacingAfter: 16)
        } else {
            layout.table(
                columns: [0.35, 0.45, 0.2],
                header: [Copy.columnDate, Copy.columnSender, Copy.columnPages],
                rows: snapshot.receivedFaxes.map { [dateText($0.date), $0.sender, "\($0.pageCount)"] }
            )
        }

        layout.text(Copy.draftsHeader, style: .heading)
        if snapshot.drafts.isEmpty {
            layout.text(Copy.draftsEmpty, style: .body, spacingAfter: 16)
        } else {
            layout.table(
                columns: [0.35, 0.45, 0.2],
                header: [Copy.columnLastEdited, Copy.columnRecipient, Copy.columnPages],
                rows: snapshot.drafts.map { [dateText($0.lastEditedAt), $0.recipient, "\($0.pageCount)"] }
            )
        }
    }

    private static func drawPages(_ snapshot: DataExportSnapshot, in layout: PDFLayout) {
        for fax in snapshot.sentFaxes {
            let total = fax.pageImageURLs.count
            for (index, url) in fax.pageImageURLs.enumerated() {
                let caption = Copy.sentPageCaption(recipient: fax.recipient, date: dateText(fax.date), page: index + 1, of: total)
                drawImagePage(at: url, caption: caption, in: layout)
            }
        }

        for draft in snapshot.drafts {
            let total = draft.pageImageURLs.count
            for (index, url) in draft.pageImageURLs.enumerated() {
                let caption = Copy.draftPageCaption(recipient: draft.recipient, date: dateText(draft.lastEditedAt), page: index + 1, of: total)
                drawImagePage(at: url, caption: caption, in: layout)
            }
        }

        for fax in snapshot.receivedFaxes {
            guard let document = CGPDFDocument(fax.pdfFileURL as CFURL), document.numberOfPages > 0 else {
                layout.newPage()
                layout.text(Copy.receivedPageCaption(sender: fax.sender, date: dateText(fax.date), page: 1, of: max(fax.pageCount, 1)), style: .caption)
                layout.text(Copy.pageMissing, style: .body)
                continue
            }
            let total = document.numberOfPages
            for pageNumber in 1...total {
                autoreleasepool {
                    layout.newPage()
                    layout.text(Copy.receivedPageCaption(sender: fax.sender, date: dateText(fax.date), page: pageNumber, of: total), style: .caption)
                    if let page = document.page(at: pageNumber) {
                        layout.drawPDFPage(page)
                    } else {
                        layout.text(Copy.pageMissing, style: .body)
                    }
                }
            }
        }
    }

    private static func drawImagePage(at url: URL, caption: String, in layout: PDFLayout) {
        autoreleasepool {
            layout.newPage()
            layout.text(caption, style: .caption)
            if let image = FaxImageProcessor.downsampledImage(at: url, maxPixelDimension: 2200) {
                layout.drawImage(image)
            } else {
                layout.text(Copy.pageMissing, style: .body)
            }
        }
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Top-down text/table/page layout on US Letter pages.
private nonisolated final class PDFLayout {
    static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48

    nonisolated enum Style {
        case title, heading, body, caption, tableHeader, tableCell

        var attributes: [NSAttributedString.Key: Any] {
            switch self {
            case .title: [.font: FaxitFont.ui(size: 22, weight: .bold), .foregroundColor: UIColor.black]
            case .heading: [.font: FaxitFont.ui(size: 15, weight: .bold), .foregroundColor: UIColor.black]
            case .body: [.font: FaxitFont.ui(size: 11), .foregroundColor: UIColor.black]
            case .caption: [.font: FaxitFont.ui(size: 10), .foregroundColor: UIColor.darkGray]
            case .tableHeader: [.font: FaxitFont.ui(size: 9, weight: .bold), .foregroundColor: UIColor.black]
            case .tableCell: [.font: FaxitFont.ui(size: 9), .foregroundColor: UIColor.black]
            }
        }
    }

    private let context: UIGraphicsPDFRendererContext
    private var y: CGFloat = 0
    private var hasPage = false

    private var contentWidth: CGFloat { Self.pageRect.width - Self.margin * 2 }
    private var bottom: CGFloat { Self.pageRect.height - Self.margin }

    init(context: UIGraphicsPDFRendererContext) {
        self.context = context
    }

    func newPage() {
        context.beginPage()
        hasPage = true
        y = Self.margin
    }

    private func ensureSpace(_ height: CGFloat) {
        if !hasPage || (y + height > bottom && y > Self.margin) {
            newPage()
        }
    }

    func text(_ string: String, style: Style, spacingAfter: CGFloat = 8) {
        let attributes = style.attributes
        let height = Self.height(of: string, attributes: attributes, width: contentWidth)
        ensureSpace(height)
        (string as NSString).draw(
            with: CGRect(x: Self.margin, y: y, width: contentWidth, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        y += height + spacingAfter
    }

    /// `columns` are fractions of the content width. The header row is
    /// repeated at the top of every page the table runs onto.
    func table(columns: [CGFloat], header: [String]?, rows: [[String]]) {
        let padding: CGFloat = 4
        let widths = columns.map { $0 * contentWidth }

        func rowHeight(_ cells: [String], _ style: Style) -> CGFloat {
            zip(cells, widths).map { Self.height(of: $0, attributes: style.attributes, width: $1 - padding * 2) }.max() ?? 0
        }

        func draw(_ cells: [String], _ style: Style, height: CGFloat) {
            var x = Self.margin
            for (cell, width) in zip(cells, widths) {
                (cell as NSString).draw(
                    with: CGRect(x: x + padding, y: y + padding, width: width - padding * 2, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: style.attributes,
                    context: nil
                )
                x += width
            }
            y += height + padding * 2
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            cgContext.setLineWidth(style == .tableHeader ? 0.8 : 0.3)
            cgContext.move(to: CGPoint(x: Self.margin, y: y))
            cgContext.addLine(to: CGPoint(x: Self.margin + contentWidth, y: y))
            cgContext.strokePath()
        }

        let headerHeight = header.map { rowHeight($0, .tableHeader) } ?? 0
        if let header {
            ensureSpace(headerHeight + padding * 2 + 30)
            draw(header, .tableHeader, height: headerHeight)
        }
        for row in rows {
            let height = rowHeight(row, .tableCell)
            if !hasPage || y + height + padding * 2 > bottom {
                newPage()
                if let header { draw(header, .tableHeader, height: headerHeight) }
            }
            draw(row, .tableCell, height: height)
        }
        y += 16
    }

    /// Fills the rest of the page with `image`, aspect-fit.
    func drawImage(_ image: UIImage) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let available = remainingRect
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(
            x: available.midX - size.width / 2,
            y: available.minY,
            width: size.width,
            height: size.height
        ))
        y = bottom
    }

    /// Fills the rest of the page with a received PDF page, aspect-fit
    /// and honoring the page's own rotation.
    func drawPDFPage(_ page: CGPDFPage) {
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return }
        let isSideways = page.rotationAngle % 180 != 0
        let pageSize = isSideways ? CGSize(width: box.height, height: box.width) : box.size

        let available = remainingRect
        let scale = min(available.width / pageSize.width, available.height / pageSize.height)
        let drawSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        let origin = CGPoint(x: available.midX - drawSize.width / 2, y: available.minY)

        let cgContext = context.cgContext
        cgContext.saveGState()
        // UIKit's PDF context is flipped (origin top-left); PDF pages draw
        // with the origin at the bottom-left.
        cgContext.translateBy(x: origin.x, y: origin.y + drawSize.height)
        cgContext.scaleBy(x: scale, y: -scale)
        cgContext.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: pageSize), rotate: 0, preserveAspectRatio: true))
        cgContext.addRect(box)
        cgContext.clip()
        cgContext.drawPDFPage(page)
        cgContext.restoreGState()
        y = bottom
    }

    private var remainingRect: CGRect {
        CGRect(x: Self.margin, y: y, width: contentWidth, height: max(bottom - y, 1))
    }

    private static func height(of string: String, attributes: [NSAttributedString.Key: Any], width: CGFloat) -> CGFloat {
        (string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height.rounded(.up)
    }
}
