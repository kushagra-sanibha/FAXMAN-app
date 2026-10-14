import SwiftUI
import UIKit

/// The fax number fields use the phone pad, which has no Return/Done key —
/// without help, once it's up there is no way to put it away. These close
/// whatever field is active, including fields owned by child components
/// (FaxNumberField, CoverPageFormView) that a screen can't bind focus to.
enum Keyboard {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Adds a "Done" button above the keyboard for every text field in this
    /// view's hierarchy.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { Keyboard.dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }
}
