import SwiftUI
import UIKit

/// System permission status first, then the one category Faxit actually
/// sends (delivery updates) and quiet hours. Faxit sends no marketing or
/// billing notifications, so there are no toggles for them.
struct NotificationsSettingsView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var permission: NotificationManager.NotificationPermission?
    @State private var isRequesting = false
    @State private var requestDeclined = false

    var body: some View {
        Form {
            permissionSection

            Section {
                Toggle(CopyDeck.Notifications.deliveryUpdates, isOn: Binding(
                    get: { settingsStore.settings.notifyDeliveryUpdates },
                    set: { settingsStore.settings.notifyDeliveryUpdates = $0; settingsStore.save() }
                ))
            } header: {
                Text(CopyDeck.Notifications.categoriesHeader)
            } footer: {
                Text(CopyDeck.Notifications.deliveryUpdatesNote)
            }

            Section {
                Toggle(CopyDeck.Notifications.quietHours, isOn: Binding(
                    get: { settingsStore.settings.quietHoursEnabled },
                    set: { settingsStore.settings.quietHoursEnabled = $0; settingsStore.save() }
                ))
                if settingsStore.settings.quietHoursEnabled {
                    DatePicker(
                        CopyDeck.Notifications.quietHoursStart,
                        selection: minuteBinding(\.quietHoursStartMinute),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        CopyDeck.Notifications.quietHoursEnd,
                        selection: minuteBinding(\.quietHoursEndMinute),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text(CopyDeck.Notifications.quietHoursHeader)
            } footer: {
                Text(CopyDeck.Notifications.quietHoursNote)
            }
        }
        .font(.faxitBody)
        .tint(.faxitAccent)
        .navigationTitle(CopyDeck.Notifications.screenTitle)
        .task { await refreshPermission() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPermission() }
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        Section {
            HStack {
                Text(CopyDeck.Notifications.permissionRowTitle)
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer()
                if let permission {
                    Text(statusText(permission))
                        .foregroundStyle(statusColor(permission))
                } else {
                    ProgressView()
                }
            }
            .accessibilityElement(children: .combine)

            switch permission {
            case .notAsked:
                VStack(alignment: .leading, spacing: 12) {
                    Text(CopyDeck.Notifications.turnOnReason)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                    Button(CopyDeck.Notifications.turnOn, action: requestPermission)
                        .buttonStyle(PrimaryButtonStyle(isDisabled: isRequesting))
                        .disabled(isRequesting)
                }
                .padding(.vertical, 4)

            case .denied:
                VStack(alignment: .leading, spacing: 12) {
                    Text(requestDeclined ? CopyDeck.Notifications.turnOnFailed : CopyDeck.Notifications.deniedExplanation)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                    Button(CopyDeck.Notifications.openIOSSettings, action: openNotificationSettings)
                        .buttonStyle(.faxitSecondary)
                }
                .padding(.vertical, 4)

            case .provisional:
                Text(CopyDeck.Notifications.provisionalNote)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                Button(CopyDeck.Notifications.openIOSSettings, action: openNotificationSettings)
                    .buttonStyle(.faxitSecondary)

            case .allowed, nil:
                EmptyView()
            }
        } header: {
            Text(CopyDeck.Notifications.permissionHeader)
        }
    }

    private func statusText(_ permission: NotificationManager.NotificationPermission) -> String {
        switch permission {
        case .allowed: CopyDeck.Notifications.statusAllowed
        case .provisional: CopyDeck.Notifications.statusProvisional
        case .notAsked: CopyDeck.Notifications.statusNotAsked
        case .denied: CopyDeck.Notifications.statusDenied
        }
    }

    private func statusColor(_ permission: NotificationManager.NotificationPermission) -> Color {
        switch permission {
        case .allowed: .faxitStatusGreen
        case .provisional, .notAsked: .faxitInkSecondary
        case .denied: .faxitStatusAmber
        }
    }

    private func refreshPermission() async {
        permission = await NotificationManager.permission()
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            let granted = await NotificationManager.requestPermission()
            settingsStore.settings.hasRequestedNotificationPermission = true
            settingsStore.save()
            requestDeclined = !granted
            await refreshPermission()
            isRequesting = false
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    /// Bridges a minutes-after-midnight setting to a DatePicker's Date.
    private func minuteBinding(_ keyPath: ReferenceWritableKeyPath<AppSettingsModel, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = settingsStore.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settingsStore.settings[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                settingsStore.save()
            }
        )
    }
}
