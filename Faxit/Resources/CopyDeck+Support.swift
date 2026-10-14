import Foundation

extension CopyDeck {
    enum Support {
        // Help
        static let helpTitle = "Help"
        static let searchPrompt = "Search help"
        static let noResultsTitle = "No matching articles"
        static let noResultsMessage = "Try other words, or ask us directly."
        static let stillStuck = "Still stuck?"
        static let stillStuckMessage = "Tell us what's going on and a person will help."
        static let contactUs = "Contact us"
        static let openSubscriptions = "Open subscription settings"

        // Contact
        static let contactTitle = "Contact us"
        static let contactIntro = "Email us about anything — billing, a fax that didn't go through, or a question."
        static let contactPersonNote = "A person reads every email."
        static let sendEmail = "Send email"
        static let copyAddress = "Copy address"
        static let copied = "Address copied"
        static let noMailApp = "No mail app is set up on this iPhone. Copy the address and email us from any mail app."
        static let emailSubject = "Faxit support"

        // Feedback
        static let feedbackTitle = "Send feedback"
        static let feedbackKindLabel = "Type of feedback"
        static let ideaLabel = "Idea"
        static let problemLabel = "Problem"
        static let messagePlaceholder = "What's on your mind?"
        static let messageLabel = "Your feedback"
        static let replyEmailLabel = "Email (optional)"
        static let replyEmailNote = "Only if you'd like a reply. We use it for nothing else."
        static let invalidEmail = "That email address doesn't look right. Check it, or leave it blank."
        static let send = "Send"
        static let sending = "Sending…"
        static let thanksTitle = "Thank you"
        static let thanksMessage = "We read every message. It helps us make Faxit better."
        static let sendAnother = "Send something else"
        static let offline = "Sending feedback needs an internet connection. Your text is kept here — send it when you're back online."
        static let failed = "Your feedback didn't send. Your text is still here — try again."
        static let rateLimited = "You've sent a lot of feedback recently. Please try again later — your text is still here."
        static let tryAgain = "Try again"
    }
}
