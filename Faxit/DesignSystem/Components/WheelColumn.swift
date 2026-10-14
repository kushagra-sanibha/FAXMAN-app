import SwiftUI

/// One column of a multi-column "slot machine" wheel picker. Rows curve
/// away and fade above/below the centre like the system wheel, but with no
/// selection band of its own — the parent draws a single shared band across
/// every column, so several columns read as one picker.
///
/// Position is computed from `selection` (not held by a scroll view), so
/// the selected row is always the one in the band — even when the parent
/// swaps `items` and `selection` in the same update, which a ScrollView's
/// scroll position couldn't follow reliably.
struct WheelColumn<Item: Hashable, RowLabel: View>: View {
    let items: [Item]
    @Binding var selection: Item?
    var rowHeight: CGFloat = 48
    var visibleRows: Int = 5
    var accessibilityName: String
    var accessibilityValue: (Item) -> String
    @ViewBuilder let label: (Item, _ isSelected: Bool) -> RowLabel

    @GestureState private var dragOffset: CGFloat = 0

    private var height: CGFloat { rowHeight * CGFloat(visibleRows) }
    private var selectedIndex: Int { selection.flatMap { items.firstIndex(of: $0) } ?? 0 }

    var body: some View {
        let selectedIndex = selectedIndex
        let halfHeight = height / 2
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                // Distance of this row's centre from the band, in points.
                let y = CGFloat(index - selectedIndex) * rowHeight + dragOffset
                // Skip rows well outside the window — cheap even for long lists.
                if abs(y) < halfHeight + rowHeight {
                    let progress = max(-1, min(1, y / halfHeight))
                    label(item, index == selectedIndex && dragOffset == 0)
                        .frame(height: rowHeight)
                        .frame(maxWidth: .infinity)
                        .rotation3DEffect(.degrees(Double(-progress) * 55), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                        .scaleEffect(1 - abs(progress) * 0.18)
                        .opacity(1 - abs(progress) * 0.75)
                        .offset(y: y)
                        .onTapGesture {
                            withAnimation(.snappy) { selection = item }
                        }
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.45), value: selectedIndex)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    guard !items.isEmpty else { return }
                    // Flick momentum: land where the predicted end lands.
                    let rows = Int((value.predictedEndTranslation.height / rowHeight).rounded())
                    let target = min(max(selectedIndex - rows, 0), items.count - 1)
                    withAnimation(.snappy(duration: 0.45)) { selection = items[target] }
                }
        )
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(selection.map(accessibilityValue) ?? "None")
        .accessibilityAdjustableAction { direction in
            guard !items.isEmpty else { return }
            switch direction {
            case .increment: selection = items[min(selectedIndex + 1, items.count - 1)]
            case .decrement: selection = items[max(selectedIndex - 1, 0)]
            @unknown default: break
            }
        }
    }
}
