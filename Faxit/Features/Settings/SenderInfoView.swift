import SwiftUI
import SwiftData

struct SenderInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [SenderProfile]

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""

    /// Fetch-or-create through the context, not the @Query snapshot: the
    /// query doesn't refresh synchronously after an insert, so reading it
    /// in onAppear and again in save() inserted two profiles.
    private var profile: SenderProfile {
        if let existing = profiles.first { return existing }
        if let existing = try? modelContext.fetch(FetchDescriptor<SenderProfile>()).first { return existing }
        let created = SenderProfile()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        Form {
            Section(CopyDeck.Settings.senderInformation) {
                TextField("Full name", text: $name)
                TextField("Email", text: $email).keyboardType(.emailAddress)
                TextField("Phone number", text: $phone).keyboardType(.phonePad)
                TextField("Company (optional)", text: $company)
            }
            Button(CopyDeck.Settings.saveChanges) {
                save()
            }
            .buttonStyle(.faxitPrimary)
            .listRowBackground(Color.clear)
        }
        .navigationTitle(CopyDeck.Settings.senderInformation)
        .onAppear {
            let p = profile
            name = p.name; email = p.email; phone = p.phone; company = p.company
        }
    }

    private func save() {
        let p = profile
        p.name = name; p.email = email; p.phone = phone; p.company = company
        try? modelContext.save()
    }
}
