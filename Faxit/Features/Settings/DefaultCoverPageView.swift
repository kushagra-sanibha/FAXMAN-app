import SwiftUI

struct DefaultCoverPageView: View {
    @Environment(AppSettingsStore.self) private var settingsStore

    var body: some View {
        CoverPageTemplatePickerView(
            selection: Binding(
                get: { settingsStore.settings.defaultCoverPage },
                set: { settingsStore.settings.defaultCoverPage = $0; settingsStore.save() }
            ),
            title: CopyDeck.Settings.defaultCoverPage,
            caption: CopyDeck.Settings.defaultCoverPageCaption
        )
    }
}
