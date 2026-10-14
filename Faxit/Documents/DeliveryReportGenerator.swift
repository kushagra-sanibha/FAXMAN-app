import UIKit

/// Generates the plain-language delivery report PDF attached to every
/// delivered or failed fax, per the strategy doc's "say what we know and
/// what we don't" rule — this report never claims legal proof.
enum DeliveryReportGenerator {
    static func generate(for fax: SentFax) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeliveryReports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent("\(fax.id.uuidString).pdf")

        let data = renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: FaxitFont.ui(size: 20, weight: .bold)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: FaxitFont.ui(size: 13)
            ]
            let noteAttributes: [NSAttributedString.Key: Any] = [
                .font: FaxitFont.ui(size: 11, weight: .italic),
                .foregroundColor: UIColor.darkGray
            ]

            var y: CGFloat = 48
            ("Faxit delivery report" as NSString).draw(at: CGPoint(x: 48, y: y), withAttributes: titleAttributes)
            y += 40

            let lines: [String] = [
                "Date and time: \(fax.createdAt.formatted(date: .long, time: .shortened))",
                "Recipient: \(PhoneNumberFormatter.displayString(fax.recipientNumber))",
                "Pages: \(fax.pageCount)",
                "Result: \(resultLine(fax))",
                "Reference: \(fax.providerHandleID.isEmpty ? "n/a" : fax.providerHandleID)"
            ]
            for line in lines {
                (line as NSString).draw(at: CGPoint(x: 48, y: y), withAttributes: bodyAttributes)
                y += 24
            }

            y += 16
            let note = "This report confirms what our fax provider reported. It is not legal proof of delivery and does not confirm the recipient read or filed these pages."
            let noteRect = CGRect(x: 48, y: y, width: pageRect.width - 96, height: 100)
            (note as NSString).draw(in: noteRect, withAttributes: noteAttributes)
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func resultLine(_ fax: SentFax) -> String {
        switch fax.status {
        case .delivered: "Delivered to the recipient's fax line"
        case .partiallyDelivered(let delivered, let total): "\(delivered) of \(total) pages delivered"
        case .notDelivered(let reason): "Not delivered (\(reason.rawValue))"
        case .providerUnavailable: "Not sent (provider unavailable)"
        default: "In progress"
        }
    }
}
