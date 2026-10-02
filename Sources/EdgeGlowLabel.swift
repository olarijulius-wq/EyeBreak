import SwiftUI

enum EdgeGlowHoldReason {
    case stillness
    case camera
    case stillnessAndCamera
}

// A value snapshot keeps the small hosting view independent of the existing
// 30 Hz countdown publisher. Its text changes only at a second/phase boundary.
struct EdgeGlowLabelContent: Equatable {
    let microLabel: String
    let instruction: String

    init(state: HUDViewState, holdReason: EdgeGlowHoldReason?) {
        let seconds = state.displayedSeconds
        if state.isHeld {
            switch holdReason {
            case .camera:
                microLabel = "Waiting for your gaze"
                instruction = "LOOK AWAY FROM THE SCREEN · \(seconds)"
            case .stillnessAndCamera:
                microLabel = "Waiting for stillness and gaze"
                instruction = "HANDS OFF & LOOK AWAY · \(seconds)"
            case .stillness, .none:
                microLabel = "Waiting for stillness"
                instruction = "REST YOUR HANDS · \(seconds)"
            }
        } else if state.isPaused {
            microLabel = "Paused while hovering"
            instruction = "MOVE AWAY TO CONTINUE · \(seconds)"
        } else {
            microLabel = state.showsFocusExercise ? "Focus exercise" : "Eye break"
            let guidance: String
            switch state.focusExercisePhase {
            case .initialFar: guidance = "LOOK FAR AWAY"
            case .near: guidance = "FOCUS ON YOUR FINGERTIP AT ARM’S LENGTH"
            case .finalFar: guidance = "LOOK FAR AWAY AGAIN"
            case .none: guidance = state.message.subtitle.uppercased()
            }
            instruction = "\(guidance) · \(seconds)"
        }
    }
}

struct EdgeGlowLabel: View {
    let content: EdgeGlowLabelContent
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        Button(action: onDismiss) {
            VStack(spacing: EyeBreakDesign.Spacing.xxs) {
                MicroLabel(content.microLabel)
                Text(content.instruction)
                    .font(EyeBreakDesign.Typography.metadata)
                    .tracking(EyeBreakDesign.Typography.metadataTracking)
                    .monospacedDigit()
                    .foregroundStyle(EyeBreakDesign.textPrimary)
            }
            .fixedSize()
            // Text-only shadows preserve legibility over light applications
            // without introducing a card, material, or full-window scrim.
            .shadow(color: .black.opacity(0.95), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.75), radius: 5)
            .padding(EyeBreakDesign.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover(perform: onHoverChanged)
        .help("Click to dismiss. Right-click to snooze for 30 minutes.")
        .accessibilityLabel("\(content.microLabel). \(content.instruction)")
        .accessibilityHint("Click to dismiss. Right-click to snooze breaks for 30 minutes.")
        .environment(\.colorScheme, .dark)
    }
}
