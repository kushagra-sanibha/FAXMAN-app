import SwiftUI

/// The three legs of a fax's journey, shown as a live route after "Send".
enum FaxTransitStep: Int, CaseIterable, Identifiable {
    case inTransit
    case received
    case delivered

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .inTransit: "In transit"
        case .received: "Received by the other party"
        case .delivered: "Delivered"
        }
    }

    var symbol: String {
        switch self {
        case .inTransit: "paperplane.fill"
        case .received: "faxmachine"
        case .delivered: "checkmark.seal.fill"
        }
    }
}

enum FaxTransitStepState: Equatable {
    case pending, active, complete, warning, failed
}

/// Pure mapping from the persisted `FaxStatus` to the state and caption of
/// each step — the timeline never invents progress the provider hasn't
/// reported.
struct FaxTransitProgress: Equatable {
    let states: [FaxTransitStep: FaxTransitStepState]
    let details: [FaxTransitStep: String]

    init(status: FaxStatus) {
        var states: [FaxTransitStep: FaxTransitStepState] = [.inTransit: .pending, .received: .pending, .delivered: .pending]
        var details: [FaxTransitStep: String] = [:]

        switch status {
        case .preparing:
            states[.inTransit] = .active
            details[.inTransit] = "Preparing your pages"
        case .uploading:
            states[.inTransit] = .active
            details[.inTransit] = "Uploading securely to our fax service"
        case .retrying(let attempt, let max):
            states[.inTransit] = .active
            details[.inTransit] = "Their line was busy — trying again (\(attempt) of \(max))"
        case .sending:
            states[.inTransit] = .complete
            states[.received] = .active
            details[.received] = "Their fax machine answered and is receiving pages"
        case .delivered:
            states = [.inTransit: .complete, .received: .complete, .delivered: .complete]
            details[.delivered] = "Every page was accepted by their fax line"
        case .partiallyDelivered(let delivered, let total):
            states = [.inTransit: .complete, .received: .complete, .delivered: .warning]
            details[.delivered] = "\(delivered) of \(total) pages went through"
        case .notDelivered(let reason):
            switch reason {
            case .busy, .noAnswer, .notAFaxLine, .disconnected, .invalidNumber:
                // Left our service fine; their end never took the pages.
                states[.inTransit] = .complete
                states[.received] = .failed
                details[.received] = "Their fax machine didn't receive it"
            case .uploadFailed, .insufficientStorage, .unknown:
                states[.inTransit] = .failed
                details[.inTransit] = "It didn't leave our fax service"
            }
        case .providerUnavailable:
            states[.inTransit] = .failed
            details[.inTransit] = "We couldn't reach our fax service"
        case .cancelled:
            states[.inTransit] = .failed
            details[.inTransit] = "Cancelled"
        }

        self.states = states
        self.details = details
    }

    func state(for step: FaxTransitStep) -> FaxTransitStepState { states[step] ?? .pending }
}

/// Vertical route: each step has an icon, the connector between steps
/// fills in as a leg completes, and a "page" dot travels along the leg
/// that's currently in progress.
struct FaxTransitTimeline: View {
    let status: FaxStatus

    private var progress: FaxTransitProgress { FaxTransitProgress(status: status) }

    var body: some View {
        let progress = progress
        VStack(alignment: .leading, spacing: 0) {
            ForEach(FaxTransitStep.allCases) { step in
                TransitStepRow(
                    step: step,
                    state: progress.state(for: step),
                    detail: progress.details[step],
                    isLast: step == FaxTransitStep.allCases.last
                )
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.3), value: progress)
        .sensoryFeedback(trigger: status) { _, new in
            switch new {
            case .delivered: .success
            case .partiallyDelivered: .warning
            case .notDelivered, .providerUnavailable: .error
            case .sending: .impact(weight: .light)
            default: nil
            }
        }
    }
}

private struct TransitStepRow: View {
    let step: FaxTransitStep
    let state: FaxTransitStepState
    let detail: String?
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                StepIcon(step: step, state: state)
                if !isLast {
                    TransitConnector(isFilled: state == .complete, isTraveling: state == .active)
                        .frame(width: 4, height: 48)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(state == .pending ? .faxitBody : .faxitBodySemibold)
                    .foregroundStyle(state == .pending ? Color.faxitInkSecondary : Color.faxitInkPrimary)
                if let detail {
                    Text(detail)
                        .font(.faxitCaption)
                        .foregroundStyle(detailColor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title), \(accessibilityState)\(detail.map { ". \($0)" } ?? "")")
    }

    private var detailColor: Color {
        switch state {
        case .failed: .faxitStatusRed
        case .warning: .faxitStatusAmber
        default: .faxitInkSecondary
        }
    }

    private var accessibilityState: String {
        switch state {
        case .pending: "not started"
        case .active: "in progress"
        case .complete: "done"
        case .warning: "partly done"
        case .failed: "failed"
        }
    }
}

private struct StepIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let step: FaxTransitStep
    let state: FaxTransitStepState

    private let size: CGFloat = 44

    private var tint: Color {
        switch state {
        case .pending: .faxitInkSecondary.opacity(0.35)
        case .active: .faxitAccent
        case .complete: step == .delivered ? .faxitStatusGreen : .faxitAccent
        case .warning: .faxitStatusAmber
        case .failed: .faxitStatusRed
        }
    }

    private var symbol: String {
        switch state {
        case .pending, .active: step.symbol
        case .complete: step == .delivered ? step.symbol : "checkmark"
        case .warning: "exclamationmark"
        case .failed: "xmark"
        }
    }

    var body: some View {
        ZStack {
            if state == .active && !reduceMotion {
                PulsingHalo(color: tint, size: size)
            }

            Circle()
                .fill(state == .pending ? Color.faxitCardBackground : tint)
                .overlay(Circle().stroke(tint, lineWidth: state == .pending ? 2 : 0))
                .frame(width: size, height: size)
                .scaleEffect(state == .pending ? 0.86 : 1)

            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(state == .pending ? tint : .white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, options: .repeating, isActive: state == .active && !reduceMotion)
                .symbolEffect(.bounce, value: state == .complete || state == .failed)
        }
        .frame(width: size, height: size)
    }
}

/// Expanding, fading ring behind the step that's currently happening.
private struct PulsingHalo: View {
    let color: Color
    let size: CGFloat
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(expanded ? 1.6 : 1)
            .opacity(expanded ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
    }
}

/// The leg between two steps: a track that fills top-to-bottom once the leg
/// completes, with a dot travelling down it while the leg is in progress.
private struct TransitConnector: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isFilled: Bool
    let isTraveling: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Capsule().fill(Color.faxitInkSecondary.opacity(0.2))
                Capsule()
                    .fill(Color.faxitAccent)
                    .frame(height: isFilled ? geo.size.height : 0)
                    .frame(maxHeight: .infinity, alignment: .top)

                if isTraveling {
                    if reduceMotion {
                        Capsule()
                            .fill(Color.faxitAccent.opacity(0.5))
                            .frame(height: geo.size.height / 2)
                    } else {
                        TimelineView(.animation) { context in
                            let period = 1.2
                            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                            Circle()
                                .fill(Color.faxitAccent)
                                .frame(width: 10, height: 10)
                                .shadow(color: Color.faxitAccent.opacity(0.6), radius: 4)
                                .offset(y: phase * (geo.size.height - 10))
                                .opacity(phase < 0.85 ? 1 : (1 - phase) / 0.15)
                        }
                        .frame(width: 10)
                        .transition(.opacity)
                    }
                }
            }
            .frame(width: geo.size.width)
        }
    }
}

#Preview {
    @Previewable @State var status: FaxStatus = .preparing
    VStack(alignment: .leading, spacing: 24) {
        FaxTransitTimeline(status: status)
        Button("Advance") {
            switch status {
            case .preparing: status = .uploading
            case .uploading: status = .sending
            case .sending: status = .delivered
            default: status = .preparing
            }
        }
    }
    .padding()
    .background(Color.faxitMintBackground)
}
