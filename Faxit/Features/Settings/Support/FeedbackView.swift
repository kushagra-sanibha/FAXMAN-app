import SwiftUI

/// Idea / Problem feedback. Separate from the rating prompt; never mentions
/// App Store reviews.
struct FeedbackView: View {
    @Environment(NetworkMonitor.self) private var network

    private enum Phase: Equatable { case editing, sending, sent, failed(String) }

    @State private var kind: FeedbackKind = .idea
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var phase: Phase = .editing

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { replyEmail.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var emailIsValid: Bool {
        trimmedEmail.isEmpty
            || trimmedEmail.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
    private var canSend: Bool {
        !trimmedMessage.isEmpty && emailIsValid && network.isOnline && phase != .sending
    }

    var body: some View {
        Group {
            if phase == .sent { thanks } else { form }
        }
        .background(Color.faxitMintBackground)
        .navigationTitle(CopyDeck.Support.feedbackTitle)
    }

    private var thanks: some View {
        ContentUnavailableView {
            Label(CopyDeck.Support.thanksTitle, systemImage: "checkmark.circle")
        } description: {
            Text(CopyDeck.Support.thanksMessage)
        } actions: {
            Button(CopyDeck.Support.sendAnother) {
                message = ""
                phase = .editing
            }
            .buttonStyle(.faxitSecondary)
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(CopyDeck.Support.feedbackKindLabel, selection: $kind) {
                    Text(CopyDeck.Support.ideaLabel).tag(FeedbackKind.idea)
                    Text(CopyDeck.Support.problemLabel).tag(FeedbackKind.problem)
                }
                .pickerStyle(.segmented)

                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text(CopyDeck.Support.messagePlaceholder)
                            .font(.faxitBody)
                            .foregroundStyle(Color.faxitInkSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $message)
                        .font(.faxitBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .accessibilityLabel(CopyDeck.Support.messageLabel)
                }
                .padding(8)
                .background(Color.faxitCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    TextField(CopyDeck.Support.replyEmailLabel, text: $replyEmail)
                        .font(.faxitBody)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .frame(minHeight: 44)
                        .background(Color.faxitCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(emailIsValid ? CopyDeck.Support.replyEmailNote : CopyDeck.Support.invalidEmail)
                        .font(.faxitCaption)
                        .foregroundStyle(emailIsValid ? Color.faxitInkSecondary : Color.faxitStatusRed)
                }

                if !network.isOnline {
                    Text(CopyDeck.Support.offline)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitStatusAmber)
                } else if case .failed(let reason) = phase {
                    Text(reason)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitStatusRed)
                }

                Button(action: send) {
                    Group {
                        if phase == .sending {
                            HStack { ProgressView(); Text(CopyDeck.Support.sending) }
                        } else if case .failed = phase {
                            Text(CopyDeck.Support.tryAgain)
                        } else {
                            Text(CopyDeck.Support.send)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !canSend))
                .disabled(!canSend)
            }
            .padding()
        }
    }

    private func send() {
        guard canSend else { return }
        phase = .sending
        let kind = kind, text = trimmedMessage
        let email = trimmedEmail.isEmpty ? nil : trimmedEmail
        Task {
            do {
                try await FaxProviderContainer.shared.sendFeedback(
                    kind: kind, message: text, replyEmail: email, anonymousID: AnonymousIdentity.current)
                replyEmail = ""
                phase = .sent
            } catch FaxProviderError.offline {
                phase = .failed(CopyDeck.Support.offline)
            } catch FaxProviderError.rateLimited {
                phase = .failed(CopyDeck.Support.rateLimited)
            } catch {
                phase = .failed(CopyDeck.Support.failed)
            }
        }
    }
}
