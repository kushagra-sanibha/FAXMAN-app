import AVFoundation
import SwiftUI
import UIKit

/// One row per permission Faxit actually uses: Camera (document scanner) and
/// Notifications (delivery updates). Photos go through the system picker,
/// which needs no permission, and Faxit doesn't track — so neither appears.
struct AccessView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var camera: AccessStatus?
    @State private var notifications: AccessStatus?

    enum AccessStatus {
        case notRequested
        case allowed
        case provisional
        case denied
        case restricted

        var text: String {
            switch self {
            case .notRequested: CopyDeck.Access.statusNotRequested
            case .allowed: CopyDeck.Access.statusAllowed
            case .provisional: CopyDeck.Access.statusProvisional
            case .denied: CopyDeck.Access.statusDenied
            case .restricted: CopyDeck.Access.statusRestricted
            }
        }

        var color: Color {
            switch self {
            case .allowed: .faxitStatusGreen
            case .notRequested, .provisional: .faxitInkSecondary
            case .denied, .restricted: .faxitStatusAmber
            }
        }

        var isLimited: Bool {
            self == .denied || self == .restricted
        }
    }

    var body: some View {
        Form {
            Section {
                row(
                    title: CopyDeck.Access.cameraTitle,
                    icon: "camera",
                    status: camera,
                    reason: CopyDeck.Access.cameraReason,
                    reducedMode: CopyDeck.Access.cameraReducedMode
                )
            } footer: {
                Text(CopyDeck.Access.intro)
            }

            Section {
                row(
                    title: CopyDeck.Access.notificationsTitle,
                    icon: "bell",
                    status: notifications,
                    reason: CopyDeck.Access.notificationsReason,
                    reducedMode: CopyDeck.Access.notificationsReducedMode
                )
            }

            Section {
                Button(CopyDeck.Access.openSettings, action: openSettings)
                    .buttonStyle(.faxitSecondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .font(.faxitBody)
        .tint(.faxitAccent)
        .navigationTitle(CopyDeck.Access.screenTitle)
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refresh() }
            }
        }
    }

    private func row(title: String, icon: String, status: AccessStatus?, reason: String, reducedMode: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer()
                if let status {
                    Text(status.text)
                        .font(.faxitCaption)
                        .foregroundStyle(status.color)
                        .multilineTextAlignment(.trailing)
                } else {
                    ProgressView()
                }
            }
            Text(reason)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
            if status == .restricted {
                Text(CopyDeck.Access.restrictedNote)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            if status?.isLimited == true {
                Text(reducedMode)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func refresh() async {
        camera = cameraStatus()
        notifications = switch await NotificationManager.permission() {
        case .notAsked: .notRequested
        case .allowed: .allowed
        case .provisional: .provisional
        case .denied: .denied
        }
    }

    /// `CameraAccessManager` folds denied and restricted together for the
    /// scanner gate; this screen separates them so a device policy isn't
    /// presented as the user's own choice.
    private func cameraStatus() -> AccessStatus {
        switch CameraAccessManager.currentStatus() {
        case .authorized:
            return .allowed
        case .needsPrimer:
            return .notRequested
        case .deniedOrRestricted:
            return AVCaptureDevice.authorizationStatus(for: .video) == .restricted ? .restricted : .denied
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
