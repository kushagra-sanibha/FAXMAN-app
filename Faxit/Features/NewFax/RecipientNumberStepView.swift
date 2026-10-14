import SwiftUI

struct RecipientNumberStepView: View {
    @Binding var recipientNumber: String
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showCountryNote = false

    private var isValid: Bool {
        PhoneNumberFormatter.isPlausibleUSOrCanadaNumber(recipientNumber)
    }

    /// Next stays disabled while typing; clearly invalid numbers also say why.
    private var numberErrorMessage: String? {
        guard let issue = PhoneNumberFormatter.recipientIssue(recipientNumber), !issue.isStillTyping else { return nil }
        return CopyDeck.Compose.numberIssueMessage(issue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(CopyDeck.Compose.title)
                    .font(.faxitHero)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .padding(.top, 8)

                FaxNumberField(number: $recipientNumber, onInvalidCountryTapped: { showCountryNote = true }, errorMessage: numberErrorMessage)

                Text(showCountryNote ? CopyDeck.Compose.countryNote : " ")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)

                Spacer()

                HStack(spacing: 12) {
                    Button("Back", action: onBack)
                        .buttonStyle(.faxitSecondary)
                    Button("Next") {
                        Keyboard.dismiss()
                        onNext()
                    }
                        .buttonStyle(.faxitPrimary)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }
}
