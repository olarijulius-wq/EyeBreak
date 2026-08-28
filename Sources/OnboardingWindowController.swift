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

    @State private var page = 0

    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                ForEach(0..<Self.pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.accentColor : .secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(page + 1) of \(Self.pageCount)")
            .padding(.bottom, 22)

            Divider()

            HStack {
                if page > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            page -= 1
                        }
                    }
                }

                Spacer()

                Button(page == Self.pageCount - 1 ? "Get started" : "Continue") {
                    if page == Self.pageCount - 1 {
                        onGetStarted()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            page += 1
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(
            width: OnboardingWindowController.contentSize.width,
            height: OnboardingWindowController.contentSize.height
        )
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)

                Text("What it does")
                    .font(.title2.weight(.semibold))

                VStack(spacing: 12) {
                    Text("EyeBreak follows the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.")
                    Text("Those short pauses give your eyes a chance to relax without pulling you out of your work.")
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 410)
            }
            .padding(32)

        case 1:
            onboardingPage(
                symbol: "menubar.rectangle",
                title: "How it works",
                paragraphs: [
                    "When it’s time for a break, a small card appears at the top of your screen.",
                    "Click the card to dismiss it at any time. Everything is configurable in Settings."
                ]
            )

        default:
            onboardingPage(
                symbol: "hand.raised.fill",
                title: "Permissions",
                paragraphs: [
                    "Camera attention, meeting detection, and the Escape shortcut each need a separate macOS permission. All three are off by default, and nothing is requested during setup.",
                    "If you enable one later, its work stays on your Mac. No data leaves your machine."
                ]
            )
        }
    }

    private func onboardingPage(
        symbol: String,
        title: String,
        paragraphs: [String]
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))

            VStack(spacing: 14) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 430)
        }
        .padding(40)
    }
}
