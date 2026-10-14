import SwiftUI

struct PrivacyPinView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @State private var showUnavailableAlert = false

    var body: some View {
        Form {
            Toggle("Lock with Face ID", isOn: Binding(
                get: { settingsStore.settings.pinLockEnabled },
                set: { newValue in
                    if newValue {
                        if FaceIDLockManager.canUseBiometricsOrPasscode() {
                            FaceIDLockManager.authenticate(reason: "Turn on Faxit lock") { success in
                                settingsStore.settings.pinLockEnabled = success
                                settingsStore.save()
                            }
                        } else {
                            showUnavailableAlert = true
                        }
                    } else {
                        settingsStore.settings.pinLockEnabled = false
                        settingsStore.save()
                    }
                }
            ))
        }
        .tint(.faxitAccent)
        .navigationTitle(CopyDeck.Settings.appLock)
        .alert("Face ID unavailable", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set up Face ID or a passcode in iPhone Settings first.")
        }
    }
}
