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
                Circle().fill(Color.red.opacity(0.8)).frame(width: 9, height: 9)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 9, height: 9)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 9, height: 9)
                Spacer()
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Spacer().frame(width: 46)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.surface)
            content
        }
        .background(theme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 1)
        }
        .clipped()
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
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(highlighted ? .white : theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(highlighted ? theme.primary : theme.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(highlighted ? theme.primary : theme.divider, lineWidth: highlighted ? 1 : 0.5)
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
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            } else {
                Text(value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
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
    private let icons = ["gearshape", "person", "bell", "lightbulb.fill", "network", "lock.shield"]

    var body: some View {
        MockWindow(title: "Xcode Settings") {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    ForEach(Array(icons.enumerated()), id: \.offset) { i, name in
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(i == 3 ? theme.primary.opacity(0.25) : Color.clear)
                                .frame(width: 22, height: 22)
                            Image(systemName: name)
                                .font(.system(size: 11))
                                .foregroundStyle(i == 3 ? theme.primary : theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(width: 36)
                .background(theme.surface.opacity(0.5))

                Rectangle().fill(theme.divider).frame(width: 0.5)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Intelligence")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure coding agents and chat providers.")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 140)
    }
}

@MainActor
private struct XcodeAgentsIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Intelligence") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Agents")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                HStack {
                    Circle().fill(theme.textSecondary.opacity(0.3)).frame(width: 14, height: 14)
                    Text("Codex")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 2)

                HighlightBox {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.primary)
                        Text("Add an Agent…")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                }

                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 130)
    }
}

@MainActor
private struct XcodeAddAgentIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Add an Agent") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Executable")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    MockTextField(
                        placeholder: "/path/to/executable",
                        value: "/Applications/Lumi.app/Contents/MacOS/lumi-acp",
                        highlighted: true
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Arguments")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    MockTextField(placeholder: "None")
                }

                Spacer()

                HStack {
                    Spacer()
                    MockButton("Cancel")
                    Spacer().frame(width: 6)
                    MockButton("Add", highlighted: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
    }
}

@MainActor
private struct XcodeAgentPickerIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "MyProject — Xcode") {
            VStack(spacing: 0) {
                HStack {
                    MockButton("▶")
                    Spacer().frame(width: 6)
                    MockButton("▶︎")
                    Spacer()
                    Text("MyProject")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    MockButton("Lumi ▾", highlighted: true)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.surface.opacity(0.5))

                Rectangle().fill(theme.divider).frame(height: 0.5)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            HStack(spacing: 4) {
                                Text("\(i + 1)")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.4))
                                    .frame(width: 12, alignment: .trailing)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.textSecondary.opacity(0.15 + Double(i % 3) * 0.05))
                                    .frame(width: CGFloat(50 + i * 15), height: 5)
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(theme.divider).frame(width: 0.5)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Circle().fill(theme.primary).frame(width: 7, height: 7)
                            Text("Lumi")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.primary)
                            Spacer()
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.primary.opacity(0.1))
                            .frame(height: 22)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.textSecondary.opacity(0.1))
                            .frame(height: 14)
                        Spacer()
                    }
                    .padding(7)
                    .frame(width: 110)
                }
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Zed Illustrations

@MainActor
private struct ZedCommandPaletteIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "main.swift — Zed") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textSecondary.opacity(0.12 + Double(i % 2) * 0.06))
                                .frame(width: CGFloat(70 + i * 20), height: 5)
                            Spacer()
                        }
                    }
                }
                .padding(8)
                .opacity(0.5)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                        Spacer().frame(width: 4)
                        HighlightBox {
                            Text("agent: open settings")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                        }
                        Spacer()
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "terminal")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.primary)
                        Text("Agent: Open Settings")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                }
                .padding(8)
                .background(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
                .padding(8)

                Spacer()
            }
        }
        .frame(height: 140)
    }
}

@MainActor
private struct ZedAddAgentIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "Agent Settings — Zed") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Agent Servers")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                HStack {
                    Circle().fill(theme.textSecondary.opacity(0.3)).frame(width: 12, height: 12)
                    Text("Zed Agent")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }

                HighlightBox {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.primary)
                        Text("Add Agent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                }

                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add Custom Agent")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("Install from Registry…")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6)
                    }
                    .padding(5)
                    .background(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(theme.divider, lineWidth: 0.5)
                    }
                    .padding(.trailing, 6)
                }

                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 155)
    }
}

@MainActor
private struct ZedSettingsJsonIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "settings.json — Zed") {
            VStack(alignment: .leading, spacing: 1) {
                jsonLine("{", 0)
                jsonLine("\"agent_servers\": {", 1, highlighted: true)
                jsonLine("\"Lumi\": {", 2, highlighted: true)
                jsonLine("\"type\": \"custom\",", 3, highlighted: true)
                jsonLine("\"command\": \"…/lumi-acp\",", 3, highlighted: true)
                jsonLine("\"args\": [],", 3, highlighted: true)
                jsonLine("\"env\": {}", 3, highlighted: true)
                jsonLine("}", 2, highlighted: true)
                jsonLine("}", 1, highlighted: true)
                jsonLine("}", 0)
                Spacer()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 155)
    }

    private func jsonLine(_ text: String, _ indent: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: CGFloat(indent * 10))
            Text(text)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(highlighted ? theme.textPrimary : theme.textSecondary.opacity(0.5))
            Spacer()
        }
        .padding(.vertical, 0.5)
        .background(highlighted ? theme.primary.opacity(0.08) : Color.clear)
    }
}

@MainActor
private struct ZedAgentPanelIllustration: View {
    @LumiTheme private var theme

    var body: some View {
        MockWindow(title: "main.swift — Zed") {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textSecondary.opacity(0.12 + Double(i % 3) * 0.04))
                                .frame(width: CGFloat(50 + i * 14), height: 4)
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: .infinity)

                Rectangle().fill(theme.divider).frame(width: 0.5)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Agent Panel")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textSecondary)
                    }

                    HighlightBox {
                        HStack {
                            Circle().fill(theme.primary).frame(width: 6, height: 6)
                            Text("Lumi")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primary.opacity(0.12))
                        .frame(height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.textSecondary.opacity(0.1))
                        .frame(height: 12)

                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.surface)
                            .frame(height: 12)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.primary)
                    }

                    Spacer()
                }
                .padding(8)
                .frame(width: 130)
                .background(theme.surface.opacity(0.4))
            }
        }
        .frame(height: 150)
    }
}
