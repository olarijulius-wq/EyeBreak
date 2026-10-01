import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static let contentSize = NSSize(width: 560, height: 420)

    private let onGetStarted: () -> Void
    private var didComplete = false

    init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted

        let onboardingWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow.title = "Welcome to EyeBreak"
        onboardingWindow.isReleasedWhenClosed = false
        onboardingWindow.isExcludedFromWindowsMenu = false
        onboardingWindow.contentMinSize = Self.contentSize
        onboardingWindow.contentMaxSize = Self.contentSize
        onboardingWindow.tabbingMode = .disallowed
        onboardingWindow.animationBehavior = .documentWindow
        onboardingWindow.appearance = NSAppearance(named: .darkAqua)
        onboardingWindow.backgroundColor = NSColor(EyeBreakDesign.base)

        super.init(window: onboardingWindow)
        shouldCascadeWindows = false
        onboardingWindow.delegate = self
        onboardingWindow.contentViewController = NSHostingController(
            rootView: OnboardingView { [weak self] in
                self?.completeOnboarding()
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func completeOnboarding() {
        finishOnboarding()
        close()
    }

    func windowWillClose(_ notification: Notification) {
        finishOnboarding()
    }

    private func finishOnboarding() {
        guard !didComplete else {
            return
        }

        didComplete = true
        onGetStarted()
    }
}

private struct OnboardingView: View {
    private static let pageCount = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    let onGetStarted: () -> Void

    var body: some View {
        ZStack {
            AtmosphereBackground(palette: .ember)

            VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.lg) {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(page)
                    .transition(.opacity)

                HStack(spacing: EyeBreakDesign.Spacing.lg) {
                    HStack(spacing: EyeBreakDesign.Spacing.md) {
                        ForEach(0..<Self.pageCount, id: \.self) { index in
                            VStack(spacing: EyeBreakDesign.Spacing.xs) {
                                Text("\(index + 1)")
                                    .font(EyeBreakDesign.Typography.micro)
                                    .foregroundStyle(index == page ? EyeBreakDesign.textPrimary : EyeBreakDesign.textSecondary)

                                Capsule()
                                    .fill(index == page ? EyeBreakDesign.textPrimary : .clear)
                                    .frame(width: 14, height: 1)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(page + 1) of \(Self.pageCount)")

                    Spacer()

                    if page > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) {
                                page -= 1
                            }
                        }
                        .buttonStyle(.plain)
                        .font(EyeBreakDesign.Typography.metadata)
                        .foregroundStyle(EyeBreakDesign.textSecondary)
                    }

                    Button {
                        if page == Self.pageCount - 1 {
                            onGetStarted()
                        } else {
                            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) {
                                page += 1
                            }
                        }
                    } label: {
                        HStack(spacing: EyeBreakDesign.Spacing.md) {
                            Text(page == Self.pageCount - 1 ? "Get started" : "Continue")
                                .font(EyeBreakDesign.Typography.metadata)

                            GlowRing(diameter: 52) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 19, weight: .light))
                            }
                        }
                        .foregroundStyle(EyeBreakDesign.textPrimary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(page == Self.pageCount - 1 ? "Get started" : "Continue")
                }
            }
            .padding(EyeBreakDesign.Spacing.xl)
        }
        .frame(
            width: OnboardingWindowController.contentSize.width,
            height: OnboardingWindowController.contentSize.height
        )
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            onboardingPage(
                symbol: "eye",
                metadata: "EyeBreak · The 20-20-20 rule",
                title: "LOOK FAR\nAWAY",
                paragraphs: [
                    "EyeBreak follows the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.",
                    "Those short pauses give your eyes a chance to relax without pulling you out of your work."
                ]
            )

        case 1:
            onboardingPage(
                symbol: "menubar.rectangle",
                metadata: "A small pause, right on time",
                title: "A MOMENT\nTO RESET",
                paragraphs: [
                    "When it’s time for a break, a small card appears at the top of your screen.",
                    "Click the card to dismiss it at any time. Everything is configurable in Settings."
                ]
            )

        default:
            onboardingPage(
                symbol: "hand.raised",
                metadata: "Permissions · Always your choice",
                title: "YOUR MAC.\nYOUR CHOICE.",
                paragraphs: [
                    "Camera attention, meeting detection, and the Escape shortcut each need a separate macOS permission. All three are off by default, and nothing is requested during setup.",
                    "If you enable one later, its work stays on your Mac. No data leaves your machine."
                ]
            )
        }
    }

    private func onboardingPage(
        symbol: String,
        metadata: String,
        title: String,
        paragraphs: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.md) {
            HStack(spacing: EyeBreakDesign.Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .ultraLight))
                    .accessibilityHidden(true)

                Text(metadata)
                    .font(EyeBreakDesign.Typography.metadata)
            }
            .foregroundStyle(EyeBreakDesign.textSecondary)

            Text(title)
                .font(EyeBreakDesign.Typography.display)
                .tracking(EyeBreakDesign.Typography.displayTracking)
                .lineSpacing(-5)
                .foregroundStyle(EyeBreakDesign.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.xs) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(EyeBreakDesign.textSecondary)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 440, alignment: .leading)
        }
    }
}
