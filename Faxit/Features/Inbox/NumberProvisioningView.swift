import SwiftUI
import SwiftData
import StoreKit

/// "Select your fax number." A rented number is its own standalone
/// subscription, independent of any send plan or one-time pass. No
/// NavigationStack of its own: callers push it or wrap it in one (the
/// Receive tab).
///
/// Four linked wheels — State/Province | Area code | Exchange | Line — over
/// the provider's live inventory, so every combination you can land on is a
/// number that's actually available. Defaults to "Give me any number": the
/// wheels spin to a random available number on open, and the dice re-rolls.
struct NumberProvisioningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(StoreManager.self) private var storeManager
    let provider: FaxProvider
    /// Off when it's the root of the Receive tab — there's nothing to close.
    var showsCloseButton = true

    @State private var country: FaxNumberCountry = .unitedStates
    @State private var regionID: String?
    @State private var areaCode: String?
    @State private var exchange: String?
    @State private var lineNumber: String?

    /// Available numbers per region, fetched when a region is first shown.
    @State private var inventory: [String: [AvailableFaxNumber]] = [:]
    @State private var loadFailedRegionID: String?
    /// Set by "any number": once the region's stock arrives, land on a
    /// random number in it instead of the first one.
    @State private var pendingRandomPick = false
    @State private var hasAppliedDefault = false

    @State private var showCountryPicker = false
    @State private var isProvisioning = false
    @State private var errorMessage: String?

    private let rowHeight: CGFloat = 48

    // MARK: - Derived selection

    private var hasNumber: Bool {
        settingsStore.settings.ownFaxNumber != nil && storeManager.hasActiveNumberRental
    }

    private var regions: [AreaCodeRegion] { AreaCodeDirectory.regions(in: country) }
    private var selectedRegion: AreaCodeRegion? { regions.first { $0.id == regionID } }
    private var regionNumbers: [AvailableFaxNumber]? { regionID.flatMap { inventory[$0] } }

    private var areaCodes: [String] {
        guard let region = selectedRegion else { return [] }
        guard let numbers = regionNumbers else { return region.areaCodes }
        // Only codes that actually have stock.
        let stocked = Set(numbers.map(\.areaCode))
        return region.areaCodes.filter(stocked.contains)
    }

    private var exchanges: [String] {
        guard let numbers = regionNumbers, let areaCode else { return [] }
        return Array(Set(numbers.filter { $0.areaCode == areaCode }.map(\.exchange))).sorted()
    }

    private var lineNumbers: [String] {
        guard let numbers = regionNumbers, let areaCode, let exchange else { return [] }
        return numbers.filter { $0.areaCode == areaCode && $0.exchange == exchange }.map(\.lineNumber).sorted()
    }

    private var selectedNumber: AvailableFaxNumber? {
        regionNumbers?.first { $0.areaCode == areaCode && $0.exchange == exchange && $0.lineNumber == lineNumber }
    }

    private var priceText: String {
        storeManager.numberRentalProduct?.displayPrice ?? CurrencyFormatter.string(fromCents: 499)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if hasNumber, let number = settingsStore.settings.ownFaxNumber {
                assignedNumberView(number)
            } else {
                chooser
            }
        }
        .background(Color.faxitMintBackground)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selection: $country)
        }
        .alert("Couldn't get your number", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var chooser: some View {
        VStack(spacing: 24) {
            Text("Select your fax number.")
                .font(.faxit(size: 34, weight: .bold))
                .foregroundStyle(Color.faxitInkPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            pickerCard

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    Task { await getNumber() }
                } label: {
                    HStack(spacing: 10) {
                        if isProvisioning {
                            ProgressView().tint(.white)
                        } else if let selectedNumber {
                            Text("Continue with \(PhoneNumberFormatter.localDisplayString(selectedNumber.e164))")
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Image(systemName: "arrow.right")
                        } else {
                            Text("Finding available numbers…")
                        }
                    }
                    .animation(.snappy, value: selectedNumber)
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: selectedNumber == nil || isProvisioning))
                .disabled(selectedNumber == nil || isProvisioning || (!storeManager.hasActiveNumberRental && storeManager.numberRentalProduct == nil))

                Text(storeManager.hasActiveNumberRental
                     ? "Your number subscription is already active — no extra charge."
                     : "\(priceText)/month, billed separately from sending. Cancel anytime.")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onAppear(perform: applyDefaultIfNeeded)
        .onChange(of: country) {
            inventory = [:]
            regionID = nil
            giveMeAnyNumber()
        }
        .onChange(of: areaCode) { normalizeSelection() }
        .onChange(of: exchange) { normalizeSelection() }
        .task(id: regionID) { await loadInventory() }
    }

    private var pickerCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    giveMeAnyNumber()
                } label: {
                    Label("Any number", systemImage: "dice.fill")
                        .font(.faxitCaptionSemibold)
                        .foregroundStyle(Color.faxitAccent)
                }
                .accessibilityHint("Picks a random available number")

                Spacer()

                Button {
                    showCountryPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Text(country.flag).font(.faxitTitle3)
                        Text(country.rawValue)
                            .font(.faxitBodyMedium)
                            .foregroundStyle(Color.faxitInkPrimary)
                        Image(systemName: "chevron.right")
                            .font(.faxitCaptionSemibold)
                            .foregroundStyle(Color.faxitInkSecondary)
                    }
                }
                .accessibilityLabel("Country, \(country.name)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 20)

            wheels
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
        }
        .background(Color.faxitCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.faxitInkSecondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }

    private var wheels: some View {
        ZStack {
            // One shared selection band across all four columns.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.faxitMintBackground)
                .frame(height: rowHeight + 4)

            HStack(spacing: 0) {
                WheelColumn(
                    items: regions.map(\.id),
                    selection: $regionID,
                    rowHeight: rowHeight,
                    accessibilityName: country.regionNoun.capitalized,
                    accessibilityValue: { id in regions.first { $0.id == id }?.name ?? id }
                ) { id, isSelected in
                    wheelText(regions.first { $0.id == id }?.name ?? id, isSelected: isSelected, monospaced: false)
                }
                .frame(maxWidth: .infinity)

                WheelColumn(items: areaCodes, selection: $areaCode, rowHeight: rowHeight, accessibilityName: "Area code", accessibilityValue: { $0 }) { code, isSelected in
                    wheelText(code, isSelected: isSelected)
                }
                .frame(width: 62)

                Group {
                    if regionNumbers == nil {
                        stockPlaceholder
                    } else {
                        HStack(spacing: 0) {
                            WheelColumn(items: exchanges, selection: $exchange, rowHeight: rowHeight, accessibilityName: "Exchange", accessibilityValue: { $0 }) { value, isSelected in
                                wheelText(value, isSelected: isSelected)
                            }
                            .frame(width: 62)

                            WheelColumn(items: lineNumbers, selection: $lineNumber, rowHeight: rowHeight, accessibilityName: "Line number", accessibilityValue: { $0 }) { value, isSelected in
                                wheelText(value, isSelected: isSelected)
                            }
                            .frame(width: 76)
                        }
                    }
                }
                .frame(width: 138)
            }
        }
        .frame(height: rowHeight * 5)
    }

    @ViewBuilder
    private var stockPlaceholder: some View {
        if loadFailedRegionID != nil, loadFailedRegionID == regionID {
            Button("Retry") {
                loadFailedRegionID = nil
                Task { await loadInventory() }
            }
            .font(.faxitCaptionSemibold)
        } else {
            ProgressView()
        }
    }

    private func wheelText(_ text: String, isSelected: Bool, monospaced: Bool = true) -> some View {
        Text(text)
            .font(.faxit(size: isSelected ? 20 : 18, weight: isSelected ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(isSelected ? Color.faxitInkPrimary : Color.faxitInkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    // MARK: - Assigned

    private func assignedNumberView(_ number: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.faxitStatusGreen)
                .symbolEffect(.bounce, value: number)
            Text("Your fax number")
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkSecondary)
            Text(number)
                .font(.faxitHero)
                .foregroundStyle(Color.faxitInkPrimary)
                .monospacedDigit()
                .textSelection(.enabled)
            Text("Share it with anyone who needs to fax you. Received faxes appear in your Inbox.")
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                ShareLink(item: number) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.faxitSecondary)
                Button("Done") { dismiss() }
                    .buttonStyle(.faxitPrimary)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Selection logic

    private func applyDefaultIfNeeded() {
        guard !hasAppliedDefault else { return }
        hasAppliedDefault = true
        giveMeAnyNumber()
    }

    /// "Give me any number": spin to a random region, then (once its stock
    /// is loaded) a random available number in it.
    private func giveMeAnyNumber() {
        pendingRandomPick = true
        let current = regionID
        let next = regions.filter { $0.id != current }.randomElement() ?? regions.first
        withAnimation(.snappy) { regionID = next?.id }
        // Same region re-picked (only possible with one region): the
        // regionID task won't re-run, so resolve right away.
        if next?.id == current { resolveSelection() }
    }

    private func loadInventory() async {
        guard let region = selectedRegion else { return }
        if inventory[region.id] == nil {
            do {
                let numbers = try await provider.searchAvailableNumbers(
                    FaxNumberSearch(country: country, areaCodes: region.areaCodes, regionName: region.name)
                )
                guard !Task.isCancelled else { return }
                inventory[region.id] = numbers
            } catch {
                guard !Task.isCancelled else { return }
                loadFailedRegionID = region.id
                return
            }
        }
        resolveSelection()
    }

    private func resolveSelection() {
        guard let numbers = regionNumbers else { return }
        if pendingRandomPick, let pick = numbers.randomElement() {
            pendingRandomPick = false
            withAnimation(.snappy) {
                areaCode = pick.areaCode
                exchange = pick.exchange
                lineNumber = pick.lineNumber
            }
        } else {
            pendingRandomPick = false
            normalizeSelection()
        }
    }

    /// Keeps each wheel on a value that exists for the wheels to its left —
    /// changing the area code moves exchange/line to available ones, but a
    /// still-valid choice is never disturbed.
    private func normalizeSelection() {
        guard regionNumbers != nil else { return }
        if areaCode.map(areaCodes.contains) != true { areaCode = areaCodes.first }
        if exchange.map(exchanges.contains) != true { exchange = exchanges.first }
        if lineNumber.map(lineNumbers.contains) != true { lineNumber = lineNumbers.first }
    }

    // MARK: - Purchase

    private func getNumber() async {
        guard let selectedNumber, let selectedRegion else { return }
        isProvisioning = true
        defer { isProvisioning = false }

        if !storeManager.hasActiveNumberRental {
            guard let product = storeManager.numberRentalProduct else {
                errorMessage = CopyDeck.Review.pricingUnavailableMessage
                return
            }
            do {
                guard try await storeManager.purchase(product) == .purchased else { return }
            } catch {
                errorMessage = CopyDeck.Review.purchaseFailedMessage
                return
            }
        }

        // Paid from here on. If the chosen number was taken meanwhile, the
        // provider falls back to another in the same area code.
        do {
            let assigned = try await provider.provisionNumber(
                preferred: selectedNumber,
                matching: FaxNumberSearch(country: country, areaCodes: [selectedNumber.areaCode], regionName: selectedRegion.name)
            )
            settingsStore.settings.ownFaxNumber = assigned.displayString
            settingsStore.save()
        } catch {
            errorMessage = "Your subscription is active, but we couldn't assign a number just now. Tap Continue again to retry — you won't be charged again."
        }
    }
}

/// "Select Country": alphabetical sections, search, checkmark on the current one.
private struct CountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: FaxNumberCountry
    @State private var query = ""

    private var sections: [(letter: String, countries: [FaxNumberCountry])] {
        let matches = FaxNumberCountry.allCases
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
        return Dictionary(grouping: matches) { String($0.name.prefix(1)) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.countries) { country in
                            Button {
                                selection = country
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text(country.flag).font(.faxitTitle2)
                                    Text(country.name)
                                        .font(.faxitBodyMedium)
                                        .foregroundStyle(Color.faxitInkPrimary)
                                    Text("(+1)")
                                        .font(.faxitBody)
                                        .foregroundStyle(Color.faxitInkSecondary)
                                    Spacer()
                                    if country == selection {
                                        Image(systemName: "checkmark")
                                            .font(.faxitBodySemibold)
                                            .foregroundStyle(Color.faxitAccent)
                                    }
                                }
                            }
                            .accessibilityAddTraits(country == selection ? .isSelected : [])
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let container = try! ModelContainer(for: AppSettingsModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    NavigationStack {
        NumberProvisioningView(provider: MockFaxProvider())
    }
    .environment(AppSettingsStore(modelContext: container.mainContext))
    .environment(StoreManager())
    .modelContainer(container)
}
