import SwiftUI

/// Enforces Settings → "Lock with Face ID". The toggle used to be saved
/// but never checked anywhere, so the app was never actually locked.
/// Covers the content on launch and whenever the app returns from the
/// background (also hiding fax pages in the app switcher snapshot).
struct AppLockGate<Content: View>: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder let content: Content

    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    private var isLockEnabled: Bool { settingsStore.settings.pinLockEnabled }
    private var showsLock: Bool { isLockEnabled && !isUnlocked }

    var body: some View {
        content
            .overlay {
                if showsLock {
                    lockScreen
                }
            }
            .task { unlockIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    isUnlocked = false
                case .active:
                    unlockIfNeeded()
                default:
                    break
                }
            }
            .onChange(of: isLockEnabled) { _, enabled in
                // Turning the lock on from Settings already authenticated.
                if enabled { isUnlocked = true }
            }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.faxitAccent)
            Text("Faxit is locked")
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
            Button("Unlock") { unlockIfNeeded() }
                .buttonStyle(.faxitPrimary)
                .frame(maxWidth: 240)
                .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.faxitMintBackground)
    }

    private func unlockIfNeeded() {
        guard showsLock, !isAuthenticating, scenePhase == .active else { return }
        guard FaceIDLockManager.canUseBiometricsOrPasscode() else {
            // Passcode removed since the lock was turned on — nothing to
            // authenticate against, so don't strand the user outside.
            isUnlocked = true
            return
        }
        isAuthenticating = true
        FaceIDLockManager.authenticate(reason: "Unlock Faxit") { success in
            isAuthenticating = false
            isUnlocked = success
        }
    }
}
