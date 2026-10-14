import SwiftUI

/// The actual cover letter the user fills in once a template is chosen —
/// real text fields and checkboxes, not a static mockup. `CoverPageTemplateView`
/// is the small non-editable thumbnail used only to pick a style; this is what
/// renders once a style (other than `.none`) is active.
struct CoverPageFormView: View {
    let style: CoverPageStyle
    @Binding var recipientNumber: String
    @Binding var details: CoverPageDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 16) {
                recipientNumberField
                formField(label: "To", text: $details.to, placeholder: "Recipient name")
                formField(label: "From", text: $details.from, placeholder: "Your name")
                formField(label: "Subject", text: $details.subject, placeholder: "Subject")

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        checkboxToggle("Urgent", isOn: $details.isUrgent)
                        checkboxToggle("Please Reply", isOn: $details.pleaseReply)
                    }
                    HStack(spacing: 20) {
                        checkboxToggle("For Review", isOn: $details.forReview)
                        checkboxToggle("Please Comment", isOn: $details.pleaseComment)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments")
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                    TextField("Add a note…", text: $details.comments, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.faxitBody)
                        .padding(10)
                        .background(Color.faxitMintBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(16)
        }
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.faxitInkSecondary.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        switch style {
        case .none:
            EmptyView()
        case .minimal:
            HStack {
                Text("Fax")
                    .font(.faxitHero)
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer()
            }
            .padding(16)
        case .professional:
            HStack {
                Text("FAX")
                    .font(.faxitHero)
                    .foregroundStyle(.white)
                Spacer()
                Text("1 PAGE")
                    .font(.faxitCaptionSemibold)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .background(Color.faxitNavyBackground)
        case .confidential:
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.faxitStatusAmber)
                Text("CONFIDENTIAL")
                    .font(.faxitBodyBold)
                    .foregroundStyle(Color.faxitStatusAmber)
                Spacer()
            }
            .padding(16)
            .background(Color.faxitStatusAmber.opacity(0.12))
        }
    }

    private var recipientNumberField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Recipient no.")
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitInkPrimary)
            Text("+1")
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
            VStack(spacing: 4) {
                TextField("", text: $recipientNumber)
                    .keyboardType(.phonePad)
                    .font(.faxitBody)
                Rectangle()
                    .fill(Color.faxitInkSecondary.opacity(0.3))
                    .frame(height: 1)
            }
        }
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(label):")
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitInkPrimary)
            VStack(spacing: 4) {
                TextField(placeholder, text: text)
                    .font(.faxitBody)
                Rectangle()
                    .fill(Color.faxitInkSecondary.opacity(0.3))
                    .frame(height: 1)
            }
        }
    }

    private func checkboxToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn.wrappedValue ? Color.faxitAccent : Color.faxitInkSecondary)
                Text(label)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var details = CoverPageDetails()
    @Previewable @State var recipientNumber = "5551234567"
    ScrollView {
        CoverPageFormView(style: .professional, recipientNumber: $recipientNumber, details: $details)
            .padding()
    }
    .background(Color.faxitMintBackground)
}
