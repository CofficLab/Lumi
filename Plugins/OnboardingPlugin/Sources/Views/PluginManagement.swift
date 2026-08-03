import LumiUI
import SwiftUI

/// Animated guide for opening Settings and managing plugins.
public struct PluginManagementPage: View {
    @LumiTheme private var theme

    private enum PlaybackStep: Int, CaseIterable {
        case app
        case settingsClick
        case settings
        case pluginsClick
        case pluginManager
        case pluginClick
        case enabled
    }

    @State private var step: PlaybackStep = .app
    @State private var playbackID = UUID()
    @State private var targetPositions: [OnboardingTargetID: CGPoint] = [:]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            guidePreview
            stepCaption
        }
        .task(id: playbackID) {
            await playAnimation()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(text("Manage your plugins"))
                    .font(.appTitle)
                Text(text("Open Settings from the Activity Bar, then enable or disable plugins whenever you need."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            AppButton(
                text("Replay"),
                systemImage: "arrow.clockwise",
                style: .ghost,
                size: .small,
                action: replay
            )
            .help(text("Replay animation"))
        }
    }

    private var guidePreview: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(theme.textPrimary.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                            .strokeBorder(theme.textPrimary.opacity(0.10))
                    }

                Group {
                    if showsSettings {
                        OnboardingSettingsWindow(
                            showsPluginManager: showsPluginManager,
                            showsEnabled: showsEnabled,
                            isPluginClick: isPluginClick
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                    } else {
                        OnboardingAppWindow(isSettingsHighlighted: isSettingsClick)
                            .transition(.opacity)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                OnboardingCursor(position: cursorPosition, isClicking: isClicking)
            }
            .coordinateSpace(name: "onboardingCanvas")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(OnboardingTargetPreferenceKey.self) { positions in
                targetPositions = positions
            }
        }
        .frame(height: 300)
    }

    private var stepCaption: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Circle()
                .fill(theme.primary)
                .frame(width: 6, height: 6)
            Text(completionDescription)
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textSecondary)
                .id(step)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            Spacer()
        }
    }

    private var cursorPosition: CGPoint {
        switch step {
        case .app, .settingsClick:
            targetPositions[.settings] ?? CGPoint(x: 36, y: 278)
        case .settings, .pluginsClick:
            targetPositions[.plugins] ?? CGPoint(x: 80, y: 95)
        case .pluginManager, .pluginClick, .enabled:
            targetPositions[.pluginToggle] ?? CGPoint(x: 465, y: 100)
        }
    }

    private var showsSettings: Bool { step.rawValue >= PlaybackStep.settings.rawValue }
    private var showsPluginManager: Bool { step.rawValue >= PlaybackStep.pluginsClick.rawValue }
    private var showsEnabled: Bool { step.rawValue >= PlaybackStep.enabled.rawValue }
    private var isSettingsClick: Bool { step == .settingsClick }
    private var isPluginClick: Bool { step == .pluginClick }
    private var isClicking: Bool { isSettingsClick || isPluginClick }

    private var completionDescription: String {
        switch step {
        case .app, .settingsClick:
            text("1. Click the Settings button in the Activity Bar")
        case .settings, .pluginsClick, .pluginManager:
            text("2. Select Plugins in the Settings sidebar")
        case .pluginClick:
            text("3. Turn plugins on or off with the switches")
        case .enabled:
            text("You're ready to customize Lumi")
        }
    }

    private func replay() {
        step = .app
        playbackID = UUID()
    }

    private func playAnimation() async {
        for nextStep in PlaybackStep.allCases {
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                step = nextStep
            }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
        }
    }

    private func text(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview("Plugin Management") {
    PluginManagementPage()
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 576)
}
