import SwiftUI

private enum MarketingPalette {
    static let window = Color(red: 0.078, green: 0.083, blue: 0.098)
    static let sidebar = Color(red: 0.105, green: 0.111, blue: 0.132)
    static let rail = Color(red: 0.128, green: 0.135, blue: 0.160)
    static let panel = Color(red: 0.092, green: 0.098, blue: 0.116)
    static let panelRaised = Color(red: 0.150, green: 0.158, blue: 0.188)
    static let line = Color.white.opacity(0.10)
    static let text = Color(red: 0.925, green: 0.929, blue: 0.949)
    static let secondary = Color(red: 0.655, green: 0.675, blue: 0.735)
    static let muted = Color(red: 0.450, green: 0.470, blue: 0.535)
    static let accent = Color(red: 0.486, green: 0.435, blue: 1.000)
    static let green = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let orange = Color(red: 1.000, green: 0.624, blue: 0.040)
    static let red = Color(red: 1.000, green: 0.270, blue: 0.230)
    static let blue = Color(red: 0.039, green: 0.518, blue: 1.000)
}

struct MarketingMacWindow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String = "Lumi", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(MarketingPalette.red).frame(width: 12, height: 12)
                Circle().fill(MarketingPalette.orange).frame(width: 12, height: 12)
                Circle().fill(MarketingPalette.green).frame(width: 12, height: 12)
                Spacer()
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MarketingPalette.secondary)
                Spacer()
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MarketingPalette.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(.black.opacity(0.22))

            content
        }
        .background(MarketingPalette.window)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 34, x: 0, y: 22)
    }
}

struct MarketingScreenshotStage<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MarketingPalette.accent)

                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(MarketingPalette.secondary)
            }
            .padding(.horizontal, 6)

            content
        }
        .padding(44)
        .frame(width: 1440, height: 900)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.050, green: 0.055, blue: 0.070),
                    Color(red: 0.105, green: 0.095, blue: 0.145),
                    Color(red: 0.055, green: 0.080, blue: 0.090)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct MarketingActivityBar: View {
    let selected: String

    private let items: [(String, String)] = [
        ("chevron.left.forwardslash.chevron.right", "Editor"),
        ("terminal", "Terminal"),
        ("server.rack", "Database"),
        ("internaldrive", "Disk"),
        ("macbook.and.iphone", "Device"),
        ("message.fill", "Chats")
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(items, id: \.0) { item in
                ZStack(alignment: .leading) {
                    if item.0 == selected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MarketingPalette.accent)
                            .frame(width: 3, height: 22)
                    }

                    Image(systemName: item.0)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(item.0 == selected ? MarketingPalette.text : MarketingPalette.muted)
                        .frame(width: 48, height: 42)
                }
            }

            Spacer()

            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MarketingPalette.muted)
                .frame(width: 48, height: 42)
                .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .frame(width: 48)
        .background(MarketingPalette.sidebar)
    }
}

struct MarketingRail: View {
    let mode: Mode

    enum Mode {
        case files
        case search
        case conversations
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(MarketingPalette.secondary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(.white.opacity(0.035))

            Divider().overlay(MarketingPalette.line)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    switch mode {
                    case .files:
                        fileTree
                    case .search:
                        searchResults
                    case .conversations:
                        conversations
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 246)
        .background(MarketingPalette.rail)
    }

    private var icon: String {
        switch mode {
        case .files: "folder"
        case .search: "magnifyingglass"
        case .conversations: "message"
        }
    }

    private var title: String {
        switch mode {
        case .files: "Explorer"
        case .search: "Search"
        case .conversations: "Conversations"
        }
    }

    private var fileTree: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarketingTreeRow(icon: "folder.fill", name: "LumiApp", depth: 0, expanded: true)
            MarketingTreeRow(icon: "folder.fill", name: "Core", depth: 1, expanded: true)
            MarketingTreeRow(icon: "folder.fill", name: "Views", depth: 2, expanded: true)
            MarketingTreeRow(icon: "swift", name: "ContentView.swift", depth: 3, selected: true)
            MarketingTreeRow(icon: "swift", name: "StatusBar.swift", depth: 3)
            MarketingTreeRow(icon: "folder.fill", name: "Plugins", depth: 1, expanded: true)
            MarketingTreeRow(icon: "folder.fill", name: "AgentChatPlugin", depth: 2, expanded: true)
            MarketingTreeRow(icon: "swift", name: "InputAreaView.swift", depth: 3)
            MarketingTreeRow(icon: "swift", name: "MessageListView.swift", depth: 3)
            MarketingTreeRow(icon: "doc.text", name: "README.md", depth: 1)
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarketingSearchField(text: "ToolCallExecutor")
            MarketingResultRow(file: "ToolCallExecutor.swift", line: "42", text: "execute pending tool calls")
            MarketingResultRow(file: "AgentTurnService.swift", line: "118", text: "await toolCallExecutor.run")
            MarketingResultRow(file: "PermissionRequest.swift", line: "9", text: "riskLevel: CommandRiskLevel")
            MarketingResultRow(file: "ToolExecutionService.swift", line: "76", text: "authorizationState")
        }
    }

    private var conversations: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarketingConversationRow(title: "Refactor editor layout", detail: "Modified 5 files", selected: true)
            MarketingConversationRow(title: "Add database query view", detail: "SQLite result table")
            MarketingConversationRow(title: "Fix terminal tab restore", detail: "Session persistence")
            MarketingConversationRow(title: "Review plugin settings", detail: "Remote model config")
            MarketingConversationRow(title: "Prepare release notes", detail: "v1.4.0")
        }
    }
}

struct MarketingEditorPanel: View {
    let showBottomPanel: Bool
    let fileName: String

    init(fileName: String = "ContentView.swift", showBottomPanel: Bool = false) {
        self.fileName = fileName
        self.showBottomPanel = showBottomPanel
    }

    var body: some View {
        VStack(spacing: 0) {
            MarketingTabStrip(fileName: fileName)
            MarketingBreadcrumb(items: ["LumiApp", "Core", "Views", fileName])
            MarketingCodeEditor()

            if showBottomPanel {
                Divider().overlay(MarketingPalette.line)
                MarketingBottomPanel()
                    .frame(height: 184)
            }
        }
        .background(MarketingPalette.panel)
    }
}

struct MarketingTabStrip: View {
    let fileName: String

    var body: some View {
        HStack(spacing: 0) {
            tab("ContentView.swift", selected: fileName == "ContentView.swift")
            tab("AgentTurnService.swift", selected: fileName == "AgentTurnService.swift")
            tab("RemoteProviderSettingsView.swift", selected: fileName == "RemoteProviderSettingsView.swift")
            Spacer()
        }
        .frame(height: 40)
        .background(MarketingPalette.panel)
    }

    private func tab(_ title: String, selected: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "swift")
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.22))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? MarketingPalette.text : MarketingPalette.secondary)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(MarketingPalette.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(selected ? MarketingPalette.panelRaised.opacity(0.65) : .clear)
        .overlay(alignment: .top) {
            if selected {
                Rectangle().fill(MarketingPalette.accent).frame(height: 2)
            }
        }
    }
}

struct MarketingBreadcrumb: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(item)
                    .font(.system(size: 12))
                    .foregroundStyle(index == items.count - 1 ? MarketingPalette.text : MarketingPalette.secondary)
                if index < items.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MarketingPalette.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) {
            Rectangle().fill(MarketingPalette.line).frame(height: 1)
        }
    }
}

struct MarketingCodeEditor: View {
    private let lines: [(String, Color)] = [
        ("struct ContentView: View {", MarketingPalette.text),
        ("    @EnvironmentObject var pluginProvider: PluginVM", Color(red: 0.66, green: 0.84, blue: 1.00)),
        ("    @EnvironmentObject var themeVM: ThemeVM", Color(red: 0.66, green: 0.84, blue: 1.00)),
        ("", MarketingPalette.text),
        ("    var body: some View {", MarketingPalette.text),
        ("        HSplitView {", Color(red: 0.86, green: 0.72, blue: 1.00)),
        ("            ActivityBar()", Color(red: 0.68, green: 0.91, blue: 0.74)),
        ("            RailView()", Color(red: 0.68, green: 0.91, blue: 0.74)),
        ("            PanelContentView()", Color(red: 0.68, green: 0.91, blue: 0.74)),
        ("            RightSidebarContainerView()", Color(red: 0.68, green: 0.91, blue: 0.74)),
        ("        }", Color(red: 0.86, green: 0.72, blue: 1.00)),
        ("        .background(themeVM.activeAppTheme.makeGlobalBackground())", Color(red: 1.00, green: 0.78, blue: 0.55)),
        ("    }", MarketingPalette.text),
        ("}", MarketingPalette.text),
        ("", MarketingPalette.text),
        ("// Plugins contribute panels, rails, toolbars and sidebars.", MarketingPalette.muted),
        ("// Lumi keeps each workspace window independent.", MarketingPalette.muted)
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 7) {
                ForEach(1...lines.count, id: \.self) { line in
                    Text("\(line)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(MarketingPalette.muted)
                        .frame(width: 38, alignment: .trailing)
                }
            }
            .padding(.vertical, 18)
            .padding(.trailing, 14)
            .background(.black.opacity(0.12))

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line.0.isEmpty ? " " : line.0)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(line.1)
                }
                Spacer()
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct MarketingAgentSidebar: View {
    let focused: Bool

    init(focused: Bool = false) {
        self.focused = focused
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Agent Chat", systemImage: "text.bubble.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MarketingPalette.text)
                Spacer()
                Image(systemName: "plus")
                    .foregroundStyle(MarketingPalette.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(.white.opacity(0.035))

            Divider().overlay(MarketingPalette.line)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingMessageBubble(role: "You", text: "Refactor the editor layout so the bottom panel stays attached to the active workspace.")
                    MarketingMessageBubble(role: "Lumi", text: "I found the split layout and panel registration points. I will update the panel behavior and keep the plugin contributions intact.", accent: true)
                    MarketingToolCard(icon: "doc.text.magnifyingglass", title: "Read files", detail: "ContentView.swift, PanelContentView.swift")
                    MarketingToolCard(icon: "wrench.and.screwdriver", title: "Edit applied", detail: "Updated bottom panel sizing")
                    MarketingMessageBubble(role: "Lumi", text: "Done. The panel now preserves height per workspace and keeps terminal tabs mounted during layout changes.", accent: true)
                }
                .padding(14)
            }

            Divider().overlay(MarketingPalette.line)

            VStack(spacing: 10) {
                HStack {
                    Text(focused ? "Explain the active selection and suggest tests" : "Ask Lumi to inspect, edit, or run tools")
                        .font(.system(size: 12))
                        .foregroundStyle(focused ? MarketingPalette.text : MarketingPalette.muted)
                    Spacer()
                }
                .padding(12)
                .frame(height: 58, alignment: .topLeading)
                .background(MarketingPalette.panelRaised.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Image(systemName: "paperclip")
                    Image(systemName: "wand.and.stars")
                    Text("GPT-5.5")
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MarketingPalette.accent)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MarketingPalette.secondary)
            }
            .padding(12)
            .background(MarketingPalette.panel)
        }
        .frame(width: 370)
        .background(MarketingPalette.panel)
    }
}

struct MarketingStatusBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Label("main", systemImage: "point.3.connected.trianglepath.dotted")
            Text("LumiApp/Core/Views")
            Spacer()
            Text("Swift")
            Text("Line 42, Col 18")
            Label("Ready", systemImage: "checkmark.circle.fill")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.90))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(MarketingPalette.accent)
    }
}

struct MarketingBottomPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MarketingPanelTab(title: "Terminal", icon: "terminal", selected: true)
                MarketingPanelTab(title: "Problems", icon: "exclamationmark.bubble")
                MarketingPanelTab(title: "Search", icon: "magnifyingglass")
                MarketingPanelTab(title: "Symbols", icon: "text.magnifyingglass")
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.white.opacity(0.035))

            VStack(alignment: .leading, spacing: 6) {
                terminalLine("$ swift test --filter EditorPanelTests", color: MarketingPalette.secondary)
                terminalLine("Test Suite 'EditorPanelTests' started", color: MarketingPalette.text)
                terminalLine("Test Case '- testBottomPanelRestoresHeight' passed (0.082 seconds)", color: MarketingPalette.green)
                terminalLine("Test Case '- testTerminalSessionStaysMounted' passed (0.094 seconds)", color: MarketingPalette.green)
                terminalLine("Executed 12 tests, with 0 failures in 1.241 seconds", color: MarketingPalette.green)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.black.opacity(0.20))
        }
    }

    private func terminalLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(color)
    }
}

struct MarketingPanelTab: View {
    let title: String
    let icon: String
    var selected = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(selected ? MarketingPalette.text : MarketingPalette.secondary)
    }
}

struct MarketingCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(MarketingPalette.panelRaised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MarketingPalette.line, lineWidth: 1)
            }
    }
}

struct MarketingToolPageShell<Content: View>: View {
    let selectedIcon: String
    let content: Content

    init(selectedIcon: String, @ViewBuilder content: () -> Content) {
        self.selectedIcon = selectedIcon
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            MarketingActivityBar(selected: selectedIcon)
            content
        }
        .background(MarketingPalette.window)
    }
}

private struct MarketingTreeRow: View {
    let icon: String
    let name: String
    let depth: Int
    var expanded = false
    var selected = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(icon == "doc.text" || icon == "swift" ? .clear : MarketingPalette.muted)
                .frame(width: 10)
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(icon == "swift" ? Color(red: 1.0, green: 0.45, blue: 0.22) : MarketingPalette.secondary)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(selected ? MarketingPalette.text : MarketingPalette.secondary)
            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 12)
        .padding(.horizontal, 7)
        .frame(height: 25)
        .background(selected ? MarketingPalette.accent.opacity(0.28) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct MarketingSearchField: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            Text(text)
            Spacer()
        }
        .font(.system(size: 12))
        .foregroundStyle(MarketingPalette.text)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(MarketingPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct MarketingResultRow: View {
    let file: String
    let line: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "swift")
                Text(file)
                Spacer()
                Text(line)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(MarketingPalette.text)

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MarketingPalette.secondary)
        }
        .padding(10)
        .background(MarketingPalette.panel.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct MarketingConversationRow: View {
    let title: String
    let detail: String
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? MarketingPalette.text : MarketingPalette.secondary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(MarketingPalette.muted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? MarketingPalette.accent.opacity(0.22) : MarketingPalette.panel.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MarketingMessageBubble: View {
    let role: String
    let text: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(role)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent ? MarketingPalette.accent : MarketingPalette.secondary)
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(MarketingPalette.text)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent ? MarketingPalette.accent.opacity(0.13) : MarketingPalette.panelRaised.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MarketingToolCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MarketingPalette.green)
                .frame(width: 24, height: 24)
                .background(MarketingPalette.green.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MarketingPalette.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(MarketingPalette.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MarketingPalette.green)
        }
        .padding(10)
        .background(MarketingPalette.panelRaised.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview("Marketing Components") {
    MarketingScreenshotStage(
        eyebrow: "Preview",
        title: "Component System",
        subtitle: "Static SwiftUI mock components for App Store screenshots."
    ) {
        MarketingMacWindow {
            HStack(spacing: 0) {
                MarketingActivityBar(selected: "chevron.left.forwardslash.chevron.right")
                MarketingRail(mode: .files)
                MarketingEditorPanel(showBottomPanel: true)
                MarketingAgentSidebar()
            }
            MarketingStatusBar()
        }
    }
}
