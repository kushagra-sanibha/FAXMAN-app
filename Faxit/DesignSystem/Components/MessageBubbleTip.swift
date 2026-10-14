import SwiftUI

/// iMessage-style speech bubble: a rounded body with the curved tail
/// hanging off the bottom edge at `tailX`, so it can point at whatever sits
/// beneath it (here, a tab bar item).
struct MessageBubbleShape: Shape {
    /// Horizontal centre of the tail, in the shape's own coordinates.
    var tailX: CGFloat
    var cornerRadius: CGFloat = 20
    var tailHeight: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        // Keep the tail clear of the rounded corners.
        let x = min(max(tailX, body.minX + cornerRadius + 10), body.maxX - cornerRadius - 10)

        let bubble = Path(roundedRect: body, cornerRadius: cornerRadius, style: .continuous)
        // The swooping tail: leaves the body to the left of the point,
        // curls down to a sharp tip, and returns to the right. It starts
        // well inside the body and is *unioned* in — simply appending it
        // made the overlap cancel out under the winding rule, leaving a
        // visible gap between body and tail.
        var tail = Path()
        tail.move(to: CGPoint(x: x - 14, y: body.maxY - 8))
        tail.addLine(to: CGPoint(x: x - 14, y: body.maxY - 1))
        tail.addQuadCurve(to: CGPoint(x: x + 2, y: rect.maxY), control: CGPoint(x: x - 4, y: body.maxY + 3))
        tail.addQuadCurve(to: CGPoint(x: x + 12, y: body.maxY - 1), control: CGPoint(x: x + 4, y: body.maxY + 5))
        tail.addLine(to: CGPoint(x: x + 12, y: body.maxY - 8))
        tail.closeSubpath()
        return bubble.union(tail)
    }
}

/// The one-time tip shown over the Receive tab after the first delivered fax.
struct ReceiveTipBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let hasOwnNumber: Bool
    /// Where the tail should point, in this view's coordinate space.
    let tailX: CGFloat
    let onOpen: () -> Void
    let onDismiss: () -> Void

    private var title: String {
        hasOwnNumber ? "Replies come in here" : "Need faxes sent back?"
    }

    private var message: String {
        hasOwnNumber
            ? "Faxes sent to your number arrive in Inbox."
            : "Get your own fax number in Receive — replies land right in the app."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitAccent)
                .frame(width: 36, height: 36)
                .background(.white, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.faxitBodySemibold)
                Text(message)
                    .font(.faxitCaption)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.faxitCaptionBold)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12 + 12) // room for the tail
        .background {
            MessageBubbleShape(tailX: tailX)
                .fill(Color.faxitAccent)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
        .contentShape(MessageBubbleShape(tailX: tailX))
        .onTapGesture(perform: onOpen)
        // Gentle bob so the eye catches it, toward the tab it points at.
        // A phase animator scopes the animation to this offset alone — a
        // repeatForever `withAnimation` in onAppear also captured the
        // bubble's first layout pass, leaving the icon endlessly sliding
        // between its initial and final positions.
        .phaseAnimator(reduceMotion ? [0] : [0, -5]) { content, offset in
            content.offset(y: offset)
        } animation: { _ in
            .easeInOut(duration: 1.1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint("Opens Receive")
        .accessibilityAction(named: "Open Receive", onOpen)
    }
}

#Preview {
    VStack {
        Spacer()
        ReceiveTipBubble(hasOwnNumber: false, tailX: 140, onOpen: {}, onDismiss: {})
            .padding(.horizontal, 16)
    }
    .background(Color.faxitMintBackground)
}
