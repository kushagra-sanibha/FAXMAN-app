import SwiftUI

/// Third-party licenses, generated from the dependency list — never typed by hand.
///
/// Faxit has no Swift packages today (no `XCRemoteSwiftPackageReference` in the
/// project), so this shows a plain statement. When packages are added, add a
/// Run Script build phase that reads `Package.resolved` plus each checkout's
/// LICENSE file (from `$BUILD_DIR/../../SourcePackages/checkouts`) and writes
/// `ThirdPartyLicenses.json` — `[{"name": "...", "license": "..."}]` — into the
/// app bundle (`$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH`). This view
/// reads that file when present.
struct LicensesView: View {
    private let licenses = ThirdPartyLicense.loadFromBundle()

    var body: some View {
        Group {
            if licenses.isEmpty {
                ScrollView {
                    Text(CopyDeck.About.noThirdPartyCode)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                List(licenses) { item in
                    NavigationLink(item.name) {
                        ScrollView {
                            Text(item.license)
                                .font(.faxitCaption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle(item.name)
                    }
                }
            }
        }
        .background(Color.faxitMintBackground)
        .navigationTitle(CopyDeck.About.licensesTitle)
    }
}

nonisolated struct ThirdPartyLicense: Decodable, Identifiable, Sendable {
    let name: String
    let license: String
    var id: String { name }

    static func loadFromBundle(_ bundle: Bundle = .main) -> [ThirdPartyLicense] {
        guard let url = bundle.url(forResource: "ThirdPartyLicenses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ThirdPartyLicense].self, from: data)
        else { return [] }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
