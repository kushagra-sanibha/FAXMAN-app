import SwiftUI
import SwiftData

/// "Export my data": one PDF of everything kept about the person, emailed
/// as an expiring download link. The address typed here lives only in this
/// screen's state — it is never saved anywhere and is dropped once sent.
struct ExportMyDataView: View {
    private typealias Copy = CopyDeck.ExportData

    private enum Phase: Equatable {
        case editing
        case sending
        case sent(linkExpiresAt: Date)
        case failed(Failure)
    }

    private enum Failure: Equatable {
        case generic
        case buildFailed
        case offline
        case rateLimited
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(NetworkMonitor.self) private var network

    @State private var email = ""
    @State private var showsValidation = false
    @State private var isConfirming = false
    @State private var phase: Phase = .editing
    @FocusState private var isEmailFocused: Bool

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        trimmedEmail.wholeMatch(of: #/[^@\s]+@[^@\s]+\.[^@\s.]{2,}/#) != nil
    }

    var body: some View {
        Form {
            switch phase {
            case .editing:
                editingSections
            case .sending:
                sendingSection
            case .sent(let linkExpiresAt):
                sentSection(linkExpiresAt: linkExpiresAt)
            case .failed(let failure):
                failedSection(failure)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.faxitMintBackground)
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase == .sending)
        .interactiveDismissDisabled(phase == .sending)
        .alert(Copy.confirmTitle, isPresented: $isConfirming) {
            Button(Copy.editAction, role: .cancel) { isEmailFocused = true }
            Button(Copy.confirmAction) { Task { await sendExport() } }
        } message: {
            Text(Copy.confirmMessage(trimmedEmail))
        }
    }

    // MARK: - Editing

    @ViewBuilder
    private var editingSections: some View {
        Section {
            Text(Copy.intro)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkPrimary)
        }

        Section {
            ForEach(Copy.includedItems, id: \.self) { item in
                Label {
                    Text(item).font(.faxitBody)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.faxitStatusGreen)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(Copy.includedHeader)
        }

        Section {
            Label {
                Text(Copy.formatBody).font(.faxitBody)
            } icon: {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(Color.faxitAccent)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text(Copy.formatHeader)
        }

        Section {
            TextField(Copy.emailPlaceholder, text: $email)
                .font(.faxitBody)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($isEmailFocused)
                .frame(minHeight: 44)
                .accessibilityLabel(Copy.emailFieldLabel)
                .onSubmit(requestSend)

            if showsValidation && !trimmedEmail.isEmpty && !isEmailValid {
                Label(Copy.invalidEmail, systemImage: "exclamationmark.circle.fill")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitStatusRed)
            }
        } header: {
            Text(Copy.emailHeader)
        } footer: {
            Text(Copy.emailPrivacyNote)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
        }

        Section {
            if !network.isOnline {
                Label(Copy.offlineNote, systemImage: "wifi.slash")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitStatusAmber)
            }
            Button(Copy.sendButton, action: requestSend)
                .buttonStyle(PrimaryButtonStyle(isDisabled: !canSend))
                .disabled(!canSend)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private var canSend: Bool {
        !trimmedEmail.isEmpty && network.isOnline
    }

    private func requestSend() {
        guard canSend else { return }
        showsValidation = true
        guard isEmailValid else {
            isEmailFocused = true
            return
        }
        isEmailFocused = false
        isConfirming = true
    }

    // MARK: - Progress and results

    private var sendingSection: some View {
        Section {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(Copy.sendingTitle)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitInkPrimary)
                Text(Copy.sendingBody)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
        }
    }

    private func sentSection(linkExpiresAt: Date) -> some View {
        Section {
            resultContent(
                systemImage: "checkmark.circle.fill",
                tint: .faxitStatusGreen,
                title: Copy.sentTitle,
                body: Copy.sentBody(linkExpiresAt: linkExpiresAt)
            )
            Button(Copy.doneAction) { dismiss() }
                .buttonStyle(.faxitPrimary)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func failedSection(_ failure: Failure) -> some View {
        Section {
            switch failure {
            case .rateLimited:
                resultContent(
                    systemImage: "clock.badge.exclamationmark",
                    tint: .faxitStatusAmber,
                    title: Copy.rateLimitedTitle,
                    body: Copy.rateLimitedBody
                )
                Button(Copy.backAction) { dismiss() }
                    .buttonStyle(.faxitPrimary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            case .generic, .buildFailed, .offline:
                resultContent(
                    systemImage: failure == .offline ? "wifi.slash" : "exclamationmark.triangle.fill",
                    tint: failure == .offline ? .faxitStatusAmber : .faxitStatusRed,
                    title: Copy.failedTitle,
                    body: failureBody(failure)
                )
                Button(Copy.retryAction) {
                    Task { await sendExport() }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !network.isOnline))
                .disabled(!network.isOnline)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                Button(Copy.editAction) { phase = .editing }
                    .buttonStyle(.faxitSecondary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func failureBody(_ failure: Failure) -> String {
        switch failure {
        case .generic: Copy.failedBody
        case .buildFailed: Copy.buildFailedBody
        case .offline: Copy.offlineFailedBody
        case .rateLimited: Copy.rateLimitedBody
        }
    }

    private func resultContent(systemImage: String, tint: Color, title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.faxitLargeTitle)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
            Text(body)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sending

    private func sendExport() async {
        let address = trimmedEmail
        guard isEmailValid else {
            phase = .editing
            showsValidation = true
            return
        }
        guard network.isOnline else {
            phase = .failed(.offline)
            return
        }
        phase = .sending

        let fileURL: URL
        do {
            let snapshot = try DataExportSnapshot.capture(from: modelContext, settings: settingsStore.settings)
            fileURL = try await DataExportBuilder.build(snapshot)
        } catch {
            phase = .failed(.buildFailed)
            return
        }
        // The export file never outlives the request, whatever the outcome.
        defer { DataExportBuilder.discard(fileURL) }

        do {
            let receipt = try await FaxProviderContainer.shared.requestDataExport(
                file: fileURL,
                email: address,
                anonymousID: AnonymousIdentity.current
            )
            // Used once, then forgotten.
            email = ""
            showsValidation = false
            phase = .sent(linkExpiresAt: receipt.linkExpiresAt)
        } catch FaxProviderError.rateLimited {
            phase = .failed(.rateLimited)
        } catch FaxProviderError.offline {
            phase = .failed(.offline)
        } catch {
            phase = .failed(.generic)
        }
    }
}
