import SwiftUI

/// A number the user has hearted in Recent faxes, offered as a one-tap pick.
struct FavoriteFaxNumber: Identifiable, Hashable {
    /// Digits only, so "(555) 123-4567" and "5551234567" are one favorite.
    let id: String
    let rawNumber: String
    let lastSentAt: Date
}

/// Country chip is locked to "+1" (Faxit sends to US/Canada numbers only in v1);
/// validation is format-only and never claims to verify who owns the number.
struct FaxNumberField: View {
    @Binding var number: String
    var onInvalidCountryTapped: (() -> Void)? = nil
    /// When non-nil, a heart button opens a sheet listing these numbers.
    var favorites: [FavoriteFaxNumber]? = nil
    /// Swipe-to-remove in the favorites sheet; hidden when nil.
    var onRemoveFavorite: ((FavoriteFaxNumber) -> Void)? = nil
    /// Shown in red under the field, which also gets a red outline.
    var errorMessage: String? = nil

    @State private var showFavorites = false

    private var isCurrentNumberFavorite: Bool {
        // Same digits-only key as FavoriteFaxNumber.id, so punctuation and a
        // leading 1 don't matter.
        let digits = String(number.filter(\.isNumber).suffix(10))
        return digits.count == 10 && favorites?.contains { $0.id == digits } == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            field
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitStatusRed)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: errorMessage)
        .sheet(isPresented: $showFavorites) {
            FavoriteNumbersSheet(
                favorites: favorites ?? [],
                selectedDigits: String(number.filter(\.isNumber).suffix(10)),
                onSelect: { number = $0.rawNumber },
                onRemove: onRemoveFavorite
            )
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Button {
                onInvalidCountryTapped?()
            } label: {
                Text("🇺🇸 +1")
                    .font(.faxitBodySemibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.faxitAccent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .foregroundStyle(Color.faxitInkPrimary)

            TextField(CopyDeck.Compose.numberFieldPlaceholder, text: $number)
                .keyboardType(.phonePad)
                .font(.faxitBody)

            if let favorites {
                favoritesButton(favorites)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.faxitStatusRed, lineWidth: 1.5)
                .opacity(errorMessage == nil ? 0 : 1)
        )
    }

    private func favoritesButton(_ favorites: [FavoriteFaxNumber]) -> some View {
        Button {
            Keyboard.dismiss()
            showFavorites = true
        } label: {
            Image(systemName: isCurrentNumberFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isCurrentNumberFavorite || !favorites.isEmpty ? Color.faxitStatusRed : Color.faxitInkSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Favorite numbers")
        .accessibilityValue(favorites.isEmpty ? "None saved" : "\(favorites.count) saved")
    }
}

/// Scrollable sheet of favorite numbers: search, tap to use, swipe to remove.
private struct FavoriteNumbersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let favorites: [FavoriteFaxNumber]
    let selectedDigits: String
    let onSelect: (FavoriteFaxNumber) -> Void
    let onRemove: ((FavoriteFaxNumber) -> Void)?

    @State private var query = ""
    /// Local copy so swipe-to-remove animates out immediately.
    @State private var removedIDs: Set<String> = []
    @State private var pendingDeletion: PendingDeletion?

    private var visible: [FavoriteFaxNumber] {
        let queryDigits = query.filter(\.isNumber)
        return favorites.filter { favorite in
            !removedIDs.contains(favorite.id) &&
            (queryDigits.isEmpty || favorite.id.contains(queryDigits))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty || visible.isEmpty && query.isEmpty {
                    ContentUnavailableView {
                        Label("No favorites yet", systemImage: "heart")
                    } description: {
                        Text("Tap ♡ on a fax in Recent faxes to save its number here.")
                    }
                } else if visible.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(visible) { favorite in
                            row(favorite)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if let onRemove {
                                        Button {
                                            pendingDeletion = PendingDeletion(
                                                title: "Remove from favorites?",
                                                message: "\(PhoneNumberFormatter.displayString(favorite.rawNumber)) won't appear here anymore. Your sent faxes aren't affected.",
                                                confirmLabel: "Remove"
                                            ) {
                                                _ = removedIDs.insert(favorite.id)
                                                onRemove(favorite)
                                            }
                                        } label: {
                                            Label("Remove", systemImage: "heart.slash")
                                        }
                                        // Not `role: .destructive`: that removes the row before the
                                        // user confirms. Keep the red look explicitly instead.
                                        .tint(.red)
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.faxitMintBackground)
            .navigationTitle("Favorite numbers")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search numbers")
            .keyboardType(.numberPad)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .deleteConfirmation($pendingDeletion)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ favorite: FavoriteFaxNumber) -> some View {
        let isSelected = favorite.id == selectedDigits
        return Button {
            onSelect(favorite)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.faxitStatusRed)
                    .frame(width: 36, height: 36)
                    .background(Color.faxitStatusRed.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(PhoneNumberFormatter.displayString(favorite.rawNumber))
                        .font(.faxitBodySemibold)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .monospacedDigit()
                    Text("Last sent \(favorite.lastSentAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.faxitBodySemibold)
                        .foregroundStyle(Color.faxitAccent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Uses this number")
    }
}

extension FavoriteFaxNumber {
    /// Unique favorite numbers from sent faxes, most recently sent first.
    static func from(_ faxes: [SentFax]) -> [FavoriteFaxNumber] {
        var byNumber: [String: FavoriteFaxNumber] = [:]
        for fax in faxes where fax.isFavorite {
            let digits = String(fax.recipientNumber.filter(\.isNumber).suffix(10))
            guard !digits.isEmpty else { continue }
            if let existing = byNumber[digits], existing.lastSentAt >= fax.createdAt { continue }
            byNumber[digits] = FavoriteFaxNumber(id: digits, rawNumber: fax.recipientNumber, lastSentAt: fax.createdAt)
        }
        return byNumber.values.sorted { $0.lastSentAt > $1.lastSentAt }
    }
}

#Preview("Favorites sheet") {
    let favorites = (0..<12).map { i in
        FavoriteFaxNumber(id: "55512340\(String(format: "%02d", i))", rawNumber: "55512340\(String(format: "%02d", i))", lastSentAt: .now.addingTimeInterval(Double(-i) * 86_400))
    }
    FavoriteNumbersSheet(favorites: favorites, selectedDigits: "5551234001", onSelect: { _ in }, onRemove: { _ in })
}
