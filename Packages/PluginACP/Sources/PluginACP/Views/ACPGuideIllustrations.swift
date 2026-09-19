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
        case ("xcode", 0): XcodeSettingsIllustrationReal()
        case ("xcode", 1): XcodeAgentsIllustrationReal()
        case ("xcode", 2): XcodeAddAgentIllustrationReal()
        case ("xcode", 3): XcodeAgentPickerIllustrationReal()
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

// MARK: - Xcode-accurate Illustrations

/// These illustrations mirror Xcode's actual Intelligence hierarchy instead
/// of using generic macOS mock windows. Keep the four steps visually related:
/// Settings → Intelligence → Add an ACP Agent → Coding Assistant.
@MainActor
private struct XcodeRealWindow<Content: View>: View {
    @LumiTheme private var theme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 8, height: 8)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 8, height: 8)
                Spacer()
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .frame(height: 25)
            .background(theme.surface)
            content
        }
        .background(theme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 1)
        }
        .clipped()
    }
}

@MainActor
private struct XcodeRealSidebar: View {
    @LumiTheme private var theme

    private let items = [
        ("General", "gearshape"),
        ("Accounts", "person.crop.circle"),
        ("Behaviors", "bolt"),
        ("Navigation", "arrow.left.arrow.right"),
        ("Text Editing", "textformat"),
        ("Key Bindings", "keyboard"),
        ("Fonts & Colors", "textformat.size"),
        ("Source Control", "arrow.triangle.branch"),
        ("Components", "square.stack.3d.up"),
        ("Locations", "folder"),
        ("Intelligence", "sparkles")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.0) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.1)
                        .font(.system(size: 8))
                        .frame(width: 12)
                    Text(item.0)
                        .font(.system(size: 8.5))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(item.0 == "Intelligence" ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 6)
                .frame(height: 18)
                .background(
                    item.0 == "Intelligence" ? theme.primary.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(width: 126)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.surface.opacity(0.55))
    }
}

@MainActor
private struct XcodeRealButton: View {
    @LumiTheme private var theme
    let title: String
    let filled: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(filled ? Color.white : theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? theme.primary : theme.surface, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(filled ? theme.primary : theme.divider, lineWidth: 0.5)
            }
    }
}

@MainActor
private struct XcodeRealAgentRow: View {
    @LumiTheme private var theme
    let name: String
    let vendor: String

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(theme.primary.opacity(0.16))
                Image(systemName: "sparkles")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.primary)
            }
            .frame(width: 21, height: 21)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Text(vendor)
                    .font(.system(size: 7.5))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 4)
            XcodeRealButton(title: "Get", filled: false)
        }
        .padding(.vertical, 2)
    }
}

@MainActor
private struct XcodeRealIntelligencePane: View {
    @LumiTheme private var theme
    let highlightAddAgent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coding Intelligence")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text("Use built-in and third-party intelligence to work with your project files and code.")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("About Intelligence in Xcode and privacy…")
                .font(.system(size: 8))
                .foregroundStyle(theme.primary)

            Text("Agents")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 4)
            XcodeRealAgentRow(name: "Claude Agent", vendor: "Anthropic")
            XcodeRealAgentRow(name: "Codex", vendor: "OpenAI")
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10))
                Text("Add an Agent…")
                    .font(.system(size: 8.5, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                highlightAddAgent ? theme.primary.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .overlay {
                if highlightAddAgent {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(theme.primary, lineWidth: 1.2)
                }
            }

            Text("Model Context Protocol")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 4)
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Xcode Tools")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Text("Allow external agents to use Xcode tools")
                        .font(.system(size: 7.5))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
                Capsule()
                    .fill(theme.primary)
                    .frame(width: 25, height: 14)
                    .overlay(alignment: .trailing) {
                        Circle().fill(Color.white).frame(width: 11, height: 11).padding(1.5)
                    }
            }

            Text("Chat")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 4)
            HStack {
                Text("ChatGPT in Xcode")
                    .font(.system(size: 8.5))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                XcodeRealButton(title: "Turn On", filled: false)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private struct XcodeSettingsIllustrationReal: View {
    var body: some View {
        XcodeRealWindow(title: "Xcode Settings") {
            HStack(spacing: 0) {
                XcodeRealSidebar()
                Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 0.5)
                XcodeRealIntelligencePane(highlightAddAgent: false)
            }
        }
        .frame(height: 235)
    }
}

@MainActor
private struct XcodeAgentsIllustrationReal: View {
    var body: some View {
        XcodeRealWindow(title: "Xcode Settings") {
            HStack(spacing: 0) {
                XcodeRealSidebar()
                Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 0.5)
                XcodeRealIntelligencePane(highlightAddAgent: true)
            }
        }
        .frame(height: 235)
    }
}

@MainActor
private struct XcodeRealFormField: View {
    @LumiTheme private var theme
    let label: String
    let value: String
    let placeholder: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(placeholder ? theme.textSecondary.opacity(0.55) : theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
        }
    }
}

@MainActor
private struct XcodeAddAgentIllustrationReal: View {
    @LumiTheme private var theme

    var body: some View {
        ZStack {
            XcodeRealWindow(title: "Xcode Settings") {
                HStack(spacing: 0) {
                    XcodeRealSidebar()
                    Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 0.5)
                    XcodeRealIntelligencePane(highlightAddAgent: true)
                }
            }
            Color.black.opacity(0.20)
            VStack(alignment: .leading, spacing: 6) {
                Text("Add an ACP Agent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Add an agent that supports the Agent Client Protocol (ACP).")
                    .font(.system(size: 7.5))
                    .foregroundStyle(theme.textSecondary)
                Text("Learn more about ACP agents…")
                    .font(.system(size: 7.5))
                    .foregroundStyle(theme.primary)
                XcodeRealFormField(label: "Name", value: "Lumi", placeholder: false)
                XcodeRealFormField(label: "Executable", value: "/Applications/Lumi.app/Contents/MacOS/lumi-acp", placeholder: false)
                XcodeRealFormField(label: "Interpreter", value: "Optional", placeholder: true)
                XcodeRealFormField(label: "Arguments", value: "Optional", placeholder: true)
                HStack {
                    Text("Environment Variables")
                        .font(.system(size: 8.5))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.primary)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    XcodeRealButton(title: "Cancel", filled: false)
                    XcodeRealButton(title: "Add", filled: true)
                }
            }
            .padding(13)
            .frame(width: 330, height: 222)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.divider, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 5)
        }
        .frame(height: 245)
    }
}

@MainActor
private struct XcodeAgentPickerIllustrationReal: View {
    @LumiTheme private var theme

    var body: some View {
        XcodeRealWindow(title: "MyProject — Xcode") {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "sidebar.leading")
                    Text("MyProject")
                        .font(.system(size: 8.5, weight: .medium))
                    Spacer()
                    Text("My Mac")
                        .font(.system(size: 7.5))
                        .foregroundStyle(theme.textSecondary)
                    XcodeRealButton(title: "▶", filled: false)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.primary)
                }
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(theme.surface)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PROJECT NAVIGATOR")
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                            Image(systemName: "folder.fill")
                                .foregroundStyle(theme.primary)
                            Text("MyProject")
                                .font(.system(size: 8.5, weight: .medium))
                        }
                        HStack(spacing: 4) {
                            Spacer().frame(width: 9)
                            Image(systemName: "swift")
                                .foregroundStyle(.orange)
                            Text("ContentView.swift")
                                .font(.system(size: 7.5))
                        }
                        Spacer()
                    }
                    .font(.system(size: 7))
                    .padding(8)
                    .frame(width: 104)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(theme.surface.opacity(0.38))
                    Rectangle().fill(theme.divider).frame(width: 0.5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ContentView.swift")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        ForEach(Array(["struct ContentView: View {", "    var body: some View {", "        Text(\"Hello, world!\")", "    }", "}"].enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 5) {
                                Text("\(index + 1)")
                                    .font(.system(size: 6.5, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.45))
                                    .frame(width: 13, alignment: .trailing)
                                Text(line)
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(index == 2 ? theme.primary : theme.textSecondary)
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Rectangle().fill(theme.divider).frame(width: 0.5)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Coding Assistant")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: 8))
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                            Text("New Conversation")
                                .font(.system(size: 7.5, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundStyle(theme.primary)
                        .padding(6)
                        .background(theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Agents")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                            HStack(spacing: 5) {
                                Circle().fill(theme.primary).frame(width: 9, height: 9)
                                Text("Lumi")
                                    .font(.system(size: 8, weight: .medium))
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.primary)
                            }
                            .padding(6)
                            .background(theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                            HStack(spacing: 5) {
                                Circle().fill(theme.textSecondary.opacity(0.35)).frame(width: 9, height: 9)
                                Text("Codex")
                                    .font(.system(size: 8))
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                        }
                        .padding(6)
                        .background(theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(theme.divider, lineWidth: 0.5)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(width: 154)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(theme.surface.opacity(0.45))
                }
            }
        }
        .frame(height: 235)
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
