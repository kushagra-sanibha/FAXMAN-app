import Foundation

extension CopyDeck {
    /// Guidance around Apple's document scanner: tips before, a level hint
    /// during, and a tilt check after.
    enum Scan {
        static let tipsTitle = "Get a clean scan"
        static let tips: [(symbol: String, title: String, detail: String)] = [
            ("iphone.gen3.radiowaves.left.and.right", "Hold your phone flat", "Straight above the page, parallel to it — not at an angle."),
            ("viewfinder", "Fit the whole page", "All four corners in view, filling most of the screen."),
            ("rectangle.fill.on.rectangle.fill", "Use a darker surface", "White paper on a dark table makes the edges easy to find."),
            ("sun.max", "Good, even light", "Avoid shadows from your hand or phone."),
        ]
        static let tipsContinue = "Start scanning"
        static let straightenedNotice = "Straightened automatically"
        static let undo = "Undo"
        static let ok = "OK"
        static let tiltWarning = "This page looks tilted, so it may print at an angle."
        static let adjust = "Adjust"
        static let keepAsIs = "Keep as is"
        static let lighter = "Lighter"
        static let darker = "Darker"
        static let faxLevelLabel = "Fax black-and-white level"
    }
}
