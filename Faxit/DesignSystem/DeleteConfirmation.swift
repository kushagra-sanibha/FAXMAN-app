import SwiftUI

/// A destructive action waiting for the user to confirm it. Every delete or
/// remove in the app goes through this, so nothing disappears on one stray
/// tap and every confirmation reads the same way.
struct PendingDeletion: Identifiable {
    let id = UUID()
    let title: String
    var message: String? = nil
    var confirmLabel: String = "Delete"
    let perform: () -> Void
}

extension View {
    /// Shows "Are you sure?" for `pending`; the action only runs on confirm.
    func deleteConfirmation(_ pending: Binding<PendingDeletion?>) -> some View {
        alert(
            pending.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            presenting: pending.wrappedValue
        ) { deletion in
            Button(deletion.confirmLabel, role: .destructive) {
                withAnimation { deletion.perform() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { deletion in
            if let message = deletion.message {
                Text(message)
            }
        }
    }
}
