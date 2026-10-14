import SwiftUI

/// The page outline over the camera or a still image: a solid translucent
/// fill with a thin border hugging the page (Genius Scan style), animating
/// toward each new position. Points are in this view's own coordinate
/// space; the caller converts and decides when to show it.
struct DocumentOverlayView: View {
    let points: [CGPoint]?

    var body: some View {
        ZStack {
            if let points, points.count == 4 {
                let shape = QuadShape(points: points)
                shape.fill(Color.faxitAccent.opacity(0.45))
                shape.stroke(Color.faxitAccent, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
        }
        .animation(.easeOut(duration: 0.12), value: points)
        .transition(.opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A four-corner outline whose corners animate.
private struct QuadShape: Shape {
    var points: [CGPoint]

    var animatableData: AnimatablePair<AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>, AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>> {
        get {
            AnimatablePair(
                AnimatablePair(points[0].animatableData, points[1].animatableData),
                AnimatablePair(points[2].animatableData, points[3].animatableData)
            )
        }
        set {
            points[0].animatableData = newValue.first.first
            points[1].animatableData = newValue.first.second
            points[2].animatableData = newValue.second.first
            points[3].animatableData = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
