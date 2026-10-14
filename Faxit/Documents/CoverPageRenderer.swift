import UIKit

/// Renders the filled-in cover page as an actual fax page (US Letter at fax
/// resolution, pure black on white). It's prepended to the pages that get
/// saved and transmitted, so what the user filled in is what the recipient
/// receives.
enum CoverPageRenderer {
    struct Content {
        let style: CoverPageStyle
        let details: CoverPageDetails
        let recipientNumber: String
        /// Falls back to the Sender information profile when "From" is blank.
        let senderName: String
        /// Including the cover page itself.
        let totalPageCount: Int
        var date: Date = .now
    }

    static func render(_ content: Content) -> UIImage {
        let dpi = FaxImageProcessor.faxDPI
        let size = CGSize(width: 8.5 * dpi, height: 11 * dpi)
        let margin = 0.75 * dpi
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let width = size.width - margin * 2
            var y = margin

            // Header — each template keeps its identity in pure B&W.
            let headerHeight = 0.9 * dpi
            let headerRect = CGRect(x: margin, y: y, width: width, height: headerHeight)
            switch content.style {
            case .professional:
                UIColor.black.setFill()
                cg.fill(headerRect)
                draw("FAX", in: headerRect.insetBy(dx: 0.25 * dpi, dy: 0.15 * dpi), font: .boldSystemFont(ofSize: 0.5 * dpi), color: .white)
                draw("\(content.totalPageCount) PAGE\(content.totalPageCount == 1 ? "" : "S")", in: headerRect.insetBy(dx: 0.25 * dpi, dy: 0.3 * dpi), font: .boldSystemFont(ofSize: 0.16 * dpi), color: .white, alignment: .right)
            case .confidential:
                cg.setStrokeColor(UIColor.black.cgColor)
                cg.setLineWidth(0.04 * dpi)
                cg.stroke(headerRect)
                draw("CONFIDENTIAL", in: headerRect.insetBy(dx: 0.25 * dpi, dy: 0.22 * dpi), font: .boldSystemFont(ofSize: 0.36 * dpi), color: .black, alignment: .center)
            case .minimal, .none:
                draw("Fax", in: headerRect, font: .boldSystemFont(ofSize: 0.55 * dpi), color: .black)
            }
            y += headerHeight + 0.35 * dpi

            let labelFont = FaxitFont.ui(size: 0.17 * dpi, weight: .bold)
            let valueFont = FaxitFont.ui(size: 0.17 * dpi)
            let rowHeight = 0.42 * dpi
            let labelWidth = 1.4 * dpi
            let from = content.details.from.trimmingCharacters(in: .whitespacesAndNewlines)
            let rows: [(String, String)] = [
                ("To:", content.details.to),
                ("Fax:", PhoneNumberFormatter.displayString(content.recipientNumber)),
                ("From:", from.isEmpty ? content.senderName : from),
                ("Date:", content.date.formatted(date: .long, time: .shortened)),
                ("Pages:", "\(content.totalPageCount) (including cover)"),
                ("Subject:", content.details.subject)
            ]
            for (label, value) in rows {
                draw(label, in: CGRect(x: margin, y: y, width: labelWidth, height: rowHeight), font: labelFont, color: .black)
                draw(value, in: CGRect(x: margin + labelWidth, y: y, width: width - labelWidth, height: rowHeight), font: valueFont, color: .black)
                y += rowHeight
                cg.setStrokeColor(UIColor.black.cgColor)
                cg.setLineWidth(2)
                cg.move(to: CGPoint(x: margin + labelWidth, y: y - 0.1 * dpi))
                cg.addLine(to: CGPoint(x: margin + width, y: y - 0.1 * dpi))
                cg.strokePath()
            }
            y += 0.2 * dpi

            // Checkboxes, two per row.
            let boxes: [(String, Bool)] = [
                ("Urgent", content.details.isUrgent),
                ("Please Reply", content.details.pleaseReply),
                ("For Review", content.details.forReview),
                ("Please Comment", content.details.pleaseComment)
            ]
            let boxSide = 0.2 * dpi
            for (index, box) in boxes.enumerated() {
                let x = margin + CGFloat(index % 2) * (width / 2)
                let rowY = y + CGFloat(index / 2) * (rowHeight * 0.9)
                let boxRect = CGRect(x: x, y: rowY + 0.03 * dpi, width: boxSide, height: boxSide)
                cg.setLineWidth(3)
                cg.stroke(boxRect)
                if box.1 {
                    cg.move(to: CGPoint(x: boxRect.minX + boxSide * 0.2, y: boxRect.midY))
                    cg.addLine(to: CGPoint(x: boxRect.minX + boxSide * 0.42, y: boxRect.maxY - boxSide * 0.2))
                    cg.addLine(to: CGPoint(x: boxRect.maxX - boxSide * 0.15, y: boxRect.minY + boxSide * 0.15))
                    cg.setLineWidth(5)
                    cg.strokePath()
                }
                draw(box.0, in: CGRect(x: x + boxSide + 0.12 * dpi, y: rowY, width: width / 2 - boxSide, height: rowHeight), font: valueFont, color: .black)
            }
            y += rowHeight * 0.9 * 2 + 0.3 * dpi

            let comments = content.details.comments.trimmingCharacters(in: .whitespacesAndNewlines)
            if !comments.isEmpty {
                draw("Comments:", in: CGRect(x: margin, y: y, width: width, height: rowHeight), font: labelFont, color: .black)
                y += rowHeight
                draw(comments, in: CGRect(x: margin, y: y, width: width, height: size.height - margin - y - 0.4 * dpi), font: valueFont, color: .black)
            }

            draw("Sent with Faxit", in: CGRect(x: margin, y: size.height - margin - 0.25 * dpi, width: width, height: 0.3 * dpi), font: .systemFont(ofSize: 0.12 * dpi), color: .darkGray, alignment: .center)
        }
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph],
            context: nil
        )
    }
}
