import LumiUI
import SwiftUI

// MARK: - Illustration Router

/// 根据 app 和步骤索引返回对应的界面示意图。
/// 将来加入新 app 时，在此 switch 中追加对应 case 即可。
@MainActor
struct ACPGuideIllustration: View {
    let appId: String
    let stepIndex: Int

    var body: some View {
        switch (appId, stepIndex) {
        case ("xcode", 0): XcodeSettingsIllustration()
        case ("xcode", 1): XcodeAgentsIllustration()
        case ("xcode", 2): XcodeAddAgentIllustration()
        case ("xcode", 3): XcodeAgentPickerIllustration()
        case ("zed", 0): ZedCommandPaletteIllustration()
        case ("zed", 1): ZedAddAgentIllustration()
        case ("zed", 2): ZedSettingsJsonIllustration()
        case ("zed", 3): ZedAgentPanelIllustration()
        default:
            EmptyView()
        }
    }
}

// MARK: - Shared Mock Primitives

@MainActor
private struct MockWindow<Content: View>: View {
    @LumiTheme private var theme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                Spacer()
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Spacer().frame(width: 52)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surface)
            content
        }
        .background(theme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 1)
        }
    }
}

@MainActor
private struct HighlightBox<Content: View>: View {
    @LumiTheme private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(theme.primary.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(theme.primary, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

@MainActor
private struct MockButton: View {
    @LumiTheme private var theme
    let title: String
    let highlighted: Bool

    init(_ title: String, highlighted: Bool = false) {
        self.title = title
        self.highlighted = highlighted
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(highlighted ? .white : theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(highlighted ? theme.primary : theme.surface)
            )
            .overlay {
                if highlighted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(theme.primary, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
            }
    }
}

@MainActor
private struct MockTextField: View {
    @LumiTheme private var theme
    let placeholder: String
    let value: String
    let highlighted: Bool

    init(placeholder: String, value: String = "", highlighted: Bool = false) {
        self.placeholder = placeholder
        self.value = value
        self.highlighted = highlighted
    }

    var body: some View {
        HStack {
            if value.isEmpty {
                Text(placeholder)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            } else {
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(highlighted ? theme.primary.opacity(0.10) : theme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(highlighted ? theme.primary : theme.divider, lineWidth: highlighted ? 1.5 : 0.5)
        }
    }
}

// MARK: - Xcode Illustrations

@MainActor
private struct XcodeSettingsIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Xcode Settings") {
            HStack(spacing: 0) {
                // 图标侧边栏
                VStack(spacing: 10) {
                    ForEach(0..<8, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(i == 3 ? theme.primary.opacity(0.25) : Color.clear)
                                .frame(width: 28, height: 28)
                            Image(systemName: xcodeIconName(i))
                                .font(.system(size: 13))
                                .foregroundStyle(i == 3 ? theme.primary : theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(width: 44)
                .background(theme.surface.opacity(0.5))

                Rectangle().fill(theme.divider).frame(width: 0.5)

                // 内容区
                VStack(alignment: .leading, spacing: 8) {
                    Text("Intelligence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure coding agents and chat providers.")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 160)
    }

    private func xcodeIconName(_ i: Int) -> String {
        ["gearshape", "person", "bell", "lightbulb.fill", "network", "lock.shield", "textformat.size", "questionmark.circle"][i]
    }
}

@MainActor
private struct XcodeAgentsIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Intelligence") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Agents")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                // 已有 agent 行
                HStack {
                    Circle().fill(theme.textSecondary.opacity(0.3)).frame(width: 16, height: 16)
                    Text("Codex")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 4)

                HighlightBox {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.primary)
                        Text("Add an Agent…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 150)
    }
}

@MainActor
private struct XcodeAddAgentIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Add an Agent") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Executable")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    MockTextField(
                        placeholder: "/path/to/executable",
                        value: "/Applications/Lumi.app/Contents/MacOS/lumi-acp",
                        highlighted: true
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    MockTextField(placeholder: "None")
                }

                Spacer()

                HStack {
                    Spacer()
                    MockButton("Cancel")
                    MockButton("Add", highlighted: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 170)
    }
}

@MainActor
private struct XcodeAgentPickerIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "MyProject — Xcode") {
            VStack(spacing: 0) {
                // 工具栏
                HStack {
                    MockButton("▶")
                    MockButton("▶︎")
                    Spacer()
                    Text("MyProject")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    MockButton("Lumi ▾", highlighted: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surface.opacity(0.5))

                Rectangle().fill(theme.divider).frame(height: 0.5)

                // 编辑器 + 助手面板
                HStack(spacing: 0) {
                    // 代码区
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text("\(i + 1)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.4))
                                    .frame(width: 14, alignment: .trailing)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.textSecondary.opacity(0.15 + Double(i % 3) * 0.05))
                                    .frame(width: CGFloat(80 + i * 20), height: 6)
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(theme.divider).frame(width: 0.5)

                    // Agent 面板
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(theme.primary).frame(width: 8, height: 8)
                            Text("Lumi")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.primary)
                            Spacer()
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primary.opacity(0.1))
                            .frame(height: 30)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.textSecondary.opacity(0.1))
                            .frame(height: 20)
                        Spacer()
                    }
                    .padding(8)
                    .frame(width: 130)
                }
            }
        }
        .frame(height: 170)
    }
}

// MARK: - Zed Illustrations

@MainActor
private struct ZedCommandPaletteIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "main.swift — Zed") {
            VStack(spacing: 0) {
                // 代码区
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textSecondary.opacity(0.12 + Double(i % 2) * 0.06))
                                .frame(width: CGFloat(100 + i * 30), height: 6)
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .opacity(0.5)

                // 命令面板
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary)
                        HighlightBox {
                            Text("agent: open settings")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                        }
                        Spacer()
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.primary)
                        Text("Agent: Open Settings")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                }
                .padding(10)
                .background(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
                .padding(10)

                Spacer()
            }
        }
        .frame(height: 160)
    }
}

@MainActor
private struct ZedAddAgentIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Agent Settings — Zed") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Agent Servers")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                HStack {
                    Circle().fill(theme.textSecondary.opacity(0.3)).frame(width: 14, height: 14)
                    Text("Zed Agent")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }

                HighlightBox {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.primary)
                        Text("Add Agent")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                // 下拉选项
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Custom Agent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Install from Registry…")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 8)
                    }
                    .padding(6)
                    .background(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(theme.divider, lineWidth: 0.5)
                    }
                    .padding(.trailing, 8)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 170)
    }
}

@MainActor
private struct ZedSettingsJsonIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "settings.json — Zed") {
            VStack(alignment: .leading, spacing: 2) {
                jsonLine("{", 0)
                jsonLine("\"agent_servers\": {", 1, highlighted: true)
                jsonLine("\"Lumi\": {", 2, highlighted: true)
                jsonLine("\"type\": \"custom\",", 3, highlighted: true)
                jsonLine("\"command\": \"/Applications/Lumi.app/…/lumi-acp\",", 3, highlighted: true)
                jsonLine("\"args\": [],", 3, highlighted: true)
                jsonLine("\"env\": {}", 3, highlighted: true)
                jsonLine("}", 2, highlighted: true)
                jsonLine("}", 1, highlighted: true)
                jsonLine("}", 0)
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 170)
    }

    private func jsonLine(_ text: String, _ indent: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: CGFloat(indent * 12))
            Text(text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(highlighted ? theme.textPrimary : theme.textSecondary.opacity(0.5))
            Spacer()
        }
        .padding(.vertical, 1)
        .background(highlighted ? theme.primary.opacity(0.08) : Color.clear)
    }
}

@MainActor
private struct ZedAgentPanelIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "main.swift — Zed") {
            HStack(spacing: 0) {
                // 编辑器
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<6, id: \.self) { i in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textSecondary.opacity(0.12 + Double(i % 3) * 0.04))
                                .frame(width: CGFloat(70 + i * 18), height: 5)
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity)

                Rectangle().fill(theme.divider).frame(width: 0.5)

                // Agent Panel
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Agent Panel")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                    }

                    // agent 选择器
                    HighlightBox {
                        HStack {
                            Circle().fill(theme.primary).frame(width: 8, height: 8)
                            Text("Lumi")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                    }

                    // 对话气泡
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.primary.opacity(0.12))
                        .frame(height: 24)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.textSecondary.opacity(0.1))
                        .frame(height: 18)

                    // 输入框
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.surface)
                            .frame(height: 16)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.primary)
                    }

                    Spacer()
                }
                .padding(10)
                .frame(width: 150)
                .background(theme.surface.opacity(0.4))
            }
        }
        .frame(height: 170)
    }
}
