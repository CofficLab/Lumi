import LumiKernel
import SwiftUI

// MARK: - PluginManagementOnboardingPage

/// Animated guide for opening Settings and managing plugins.
public struct PluginManagementOnboardingPage: View {
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

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localized("Manage your plugins", "管理你的插件"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(localized("Open Settings from the Activity Bar, then enable or disable plugins whenever you need.", "从活动栏打开设置，随时启用或关闭插件。"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    replay()
                } label: {
                    Label(
                        localized("Replay", "重新播放"),
                        systemImage: "arrow.clockwise"
                    )
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(localized("Replay animation", "重新播放动画"))
            }

            guidePreview

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text(completionDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .id(step)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Spacer()
            }
        }
        .task(id: playbackID) {
            await playAnimation()
        }
    }

    private var guidePreview: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 520, proxy.size.height / 238)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10))
                    }

                Group {
                    if showsSettings {
                        settingsWindow
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                    } else {
                        appWindow
                            .transition(.opacity)
                    }
                }
                .padding(12)
                .frame(width: 520, height: 238, alignment: .topLeading)

                cursor
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 238)
    }

    private var appWindow: some View {
        HStack(spacing: 0) {
            activityBar
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(.red.opacity(0.7)).frame(width: 7, height: 7)
                    Circle().fill(.yellow.opacity(0.7)).frame(width: 7, height: 7)
                    Circle().fill(.green.opacity(0.7)).frame(width: 7, height: 7)
                    Text(localized("Lumi", "Lumi"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 12)
                .frame(height: 30, alignment: .leading)
                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(localized("Welcome to Lumi", "欢迎使用 Lumi"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(localized("Your AI-powered desktop assistant", "你的 AI 驱动个人桌面助手"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)

                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(height: 58)
                    .overlay(alignment: .leading) {
                        Text(localized("Start a conversation or open Settings to customize Lumi", "开始对话，或打开设置自定义 Lumi"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background.opacity(0.92))
        }
        .padding(12)
    }

    private var activityBar: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(.secondary)
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "gearshape.fill")
                .foregroundStyle(isSettingsClick ? Color.accentColor : .secondary)
                .padding(7)
                .background {
                    Circle()
                        .fill(Color.accentColor.opacity(isSettingsClick ? 0.18 : 0))
                        .scaleEffect(isSettingsClick ? 1.18 : 0.8)
                        .animation(.easeInOut(duration: 0.55), value: step)
                }
                .overlay {
                    Circle()
                        .stroke(Color.accentColor.opacity(isSettingsClick ? 0.55 : 0), lineWidth: 2)
                        .scaleEffect(isSettingsClick ? 1.35 : 0.9)
                        .animation(.easeInOut(duration: 0.55), value: step)
                }
        }
        .font(.system(size: 16, weight: .medium))
        .frame(maxHeight: .infinity)
        .padding(.vertical, 10)
    }

    private var settingsWindow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(localized("Settings", "设置"))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.bottom, 5)
                settingsRow("slider.horizontal.3", localized("General", "通用"), false)
                settingsRow("puzzlepiece.extension", localized("Plugins", "插件"), showsPluginManager)
                settingsRow("paintbrush", localized("Appearance", "外观"), false)
                Spacer()
            }
            .padding(14)
            .frame(width: 132, alignment: .leading)
            .background(Color.primary.opacity(0.035))

            VStack(alignment: .leading, spacing: 12) {
                Text(localized("Plugin Manager", "插件管理"))
                    .font(.system(size: 15, weight: .bold))
                Text(localized("Enable the tools you want to use", "启用你需要的工具"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                pluginRow(name: localized("Git", "Git"), icon: "arrow.triangle.branch", enabled: showsEnabled, highlighted: isPluginClick)
                pluginRow(name: localized("Project Files", "项目文件"), icon: "doc.text", enabled: false, highlighted: false)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(.background.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10))
        }
    }

    private func settingsRow(_ icon: String, _ title: String, _ highlighted: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).frame(width: 14)
            Text(title)
        }
        .font(.system(size: 10, weight: highlighted ? .semibold : .regular))
        .foregroundStyle(highlighted ? Color.accentColor : .secondary)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(highlighted ? Color.accentColor.opacity(0.12) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .animation(.easeInOut(duration: 0.35), value: highlighted)
    }

    private func pluginRow(name: String, icon: String, enabled: Bool, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(name)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Capsule()
                .fill(enabled ? Color.accentColor : (highlighted ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.22)))
                .frame(width: 30, height: 17)
                .overlay(alignment: enabled ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(radius: 1)
                        .frame(width: 13, height: 13)
                        .padding(2)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: enabled)
        }
        .padding(9)
        .background(Color.primary.opacity(0.035))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.accentColor.opacity(highlighted ? 0.65 : 0), lineWidth: 2)
                .scaleEffect(highlighted ? 1.03 : 0.98)
                .animation(.easeInOut(duration: 0.45), value: highlighted)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var cursor: some View {
        ZStack {
            if isClicking {
                Circle()
                    .stroke(Color.accentColor.opacity(0.65), lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(isClicking ? 1.35 : 0.7)
                    .opacity(isClicking ? 0 : 0.8)
                    .animation(.easeOut(duration: 0.7).repeatForever(autoreverses: false), value: isClicking)
            }
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.primary)
                .shadow(color: .white.opacity(0.9), radius: 2)
        }
        .position(cursorPosition)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: cursorPosition)
    }

    private var cursorPosition: CGPoint {
        switch step {
        case .app, .settingsClick:
            return CGPoint(x: 34, y: 200)
        case .settings, .pluginsClick:
            return CGPoint(x: 94, y: 83)
        case .pluginManager, .pluginClick, .enabled:
            return CGPoint(x: 453, y: 90)
        }
    }

    private var showsSettings: Bool { step.rawValue >= PlaybackStep.settings.rawValue }
    private var showsPluginManager: Bool { step.rawValue >= PlaybackStep.pluginsClick.rawValue }
    private var showsEnabled: Bool { step.rawValue >= PlaybackStep.enabled.rawValue }
    private var isSettingsClick: Bool { step == .settingsClick }
    private var isPluginClick: Bool { step == .pluginClick }
    private var isClicking: Bool { isSettingsClick || isPluginClick }

    private var stepDescription: String {
        switch step {
        case .app, .settingsClick:
            return localized("1. Click the Settings button in the Activity Bar", "1. 点击活动栏上的设置按钮")
        case .settings, .pluginsClick, .pluginManager:
            return localized("2. Select Plugins in the Settings sidebar", "2. 在设置侧栏中选择插件")
        case .pluginClick, .enabled:
            return localized("3. Turn plugins on or off with the switches", "3. 使用开关启用或关闭插件")
        }
    }

    private var completionDescription: String {
        switch step {
        case .enabled:
            return localized("You're ready to customize Lumi", "现在可以自定义 Lumi 了")
        default:
            return stepDescription
        }
    }

    private func localized(_ english: String, _: String) -> String {
        LumiPluginLocalization.string(english, bundle: .module)
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
            try? await Task.sleep(nanoseconds: 1100000000)
        }
    }
}

// MARK: - Preview

#Preview("Plugin Management") {
    PluginManagementOnboardingPage()
        .padding(32)
        .frame(width: 576)
}
