import SwiftUI

/// Reached from a failure screen's "Check or change the number" action.
struct ChangeNumberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var number: String
    let onSave: (String) -> Void

    private var isValid: Bool { PhoneNumberFormatter.isPlausibleUSOrCanadaNumber(number) }

    private var numberErrorMessage: String? {
        guard let issue = PhoneNumberFormatter.recipientIssue(number), !issue.isStillTyping else { return nil }
        return CopyDeck.Compose.numberIssueMessage(issue)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                FaxNumberField(number: $number, errorMessage: numberErrorMessage)
                Spacer()
                Button("Save and try again") {
                    Keyboard.dismiss()
                    onSave(number)
                    dismiss()
                }
                .buttonStyle(.faxitPrimary)
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
            }
            .padding(16)
            .background(Color.faxitMintBackground)
            .navigationTitle("Change number")
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
