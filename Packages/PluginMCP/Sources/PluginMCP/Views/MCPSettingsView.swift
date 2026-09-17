import Combine
import KitAgentTool
import KitMCP
import LumiUI
import SwiftUI

/// Cursor 式"MCP 服务器"设置页。
///
/// - 服务器列表：卡片式，状态 / 工具数 / 启停 / 编辑 / 删除；
/// - 添加/编辑表单：传输、命令、参数、环境变量、自动启动，"保存并连接"；
/// - 内置模板区：Xcode (native) 一键添加；
/// - 工具清单：按服务器分组，风险徽标 + 单工具覆盖；
/// - 全局设置与安全提示。
@MainActor
struct MCPSettingsView: View {
    @ObservedObject var registry: MCPServerRegistry
    @ObservedObject var manager: MCPConnectionManager
    @LumiTheme private var theme
    @State private var showingAddSheet = false
    @State private var editingServerID: String?
    @State private var revision = 0

    var body: some View {
        PluginSettingsScaffold(
            title: MCPText.string("MCP Servers"),
            subtitle: MCPText.string("Connect any Model Context Protocol server and let the agent use its tools."),
            showHeader: false,
            scrollsContent: true
        ) {
            VStack(alignment: .leading, spacing: 14) {
                globalSection
                templatesSection
                serversSection
                toolsSection
                securityNotice
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .id(revision)
        .sheet(isPresented: $showingAddSheet) {
            MCPServerEditSheet(
                registry: registry,
                manager: manager,
                server: nil
            ) { _ in revision += 1 }
        }
        .sheet(item: Binding(
            get: { editingServerID.flatMap { id in registry.server(id: id) } },
            set: { editingServerID = $0?.id }
        )) { server in
            MCPServerEditSheet(
                registry: registry,
                manager: manager,
                server: server
            ) { _ in revision += 1 }
        }
    }

    // MARK: - Sections

    private var globalSection: some View {
        AppSettingsSection(
            title: MCPText.string("General"),
            subtitle: MCPText.string("Global switches for all MCP servers.")
        ) {
            AppToggleRow(
                title: LocalizedStringKey(MCPText.string("Enable MCP")),
                systemImage: "link",
                description: LocalizedStringKey(MCPText.string("When off, no server connects and no MCP tool is available.")),
                isOn: Binding(
                    get: { registry.globalEnabled },
                    set: { value in
                        registry.globalEnabled = value
                        revision += 1
                    }
                )
            )
            AppDivider()
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(theme.warning)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(MCPText.string("Unknown tool risk"))
                        .font(.appBody)
                    Text(MCPText.string("Risk applied to tools not covered by any rule. High means approval required."))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                riskPicker(
                    selection: Binding(
                        get: { registry.unknownToolDefaultLevel },
                        set: { registry.unknownToolDefaultLevel = $0 ?? .high }
                    ),
                    compact: false
                )
            }
            .padding(.vertical, 6)
        }
    }

    private var templatesSection: some View {
        AppSettingsSection(
            title: MCPText.string("Built-in Templates"),
            subtitle: MCPText.string("One-click add common servers.")
        ) {
            templateCard(
                title: "Xcode (native)",
                detail: "xcrun mcpbridge · requires a running Xcode with Intelligence → Model Context Protocol enabled.",
                systemImage: "hammer",
                add: {
                    addTemplate(MCPServerTemplate.xcodeNative)
                }
            )
        }
    }

    private var serversSection: some View {
        AppSettingsSection(
            title: MCPText.string("Servers"),
            subtitle: MCPText.string("Configured MCP servers. Only trusted sources — each server runs programs on this machine.")
        ) {
            if !registry.servers.isEmpty {
                ForEach(registry.servers) { server in
                    serverCard(server)
                }
            } else {
                Text(MCPText.string("No servers yet. Add one below."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            HStack(spacing: 10) {
                AppButton(MCPText.string("Add Server"), systemImage: "plus", size: .small) {
                    showingAddSheet = true
                }
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private var toolsSection: some View {
        AppSettingsSection(
            title: MCPText.string("Tools"),
            subtitle: MCPText.string("Discovered tools, grouped by server. Risk can be overridden per tool.")
        ) {
            let tools = manager.registeredTools
            if tools.isEmpty {
                Text(MCPText.string("Connect a server to discover its tools."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(tools.keys.sorted(), id: \.self) { serverID in
                    if let config = registry.server(id: serverID), let adapters = tools[serverID] {
                        toolGroup(config: config, adapters: adapters)
                    }
                }
            }
        }
    }

    private var securityNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warning)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(MCPText.string("Security notice"))
                    .font(.appBodyEmphasized)
                Text(MCPText.string("An MCP server runs programs on this machine with Lumi's permissions — equivalent to executing arbitrary local commands. Only add servers you trust. Unknown tools default to high risk and require approval."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 0.5)
        }
    }

    // MARK: - Subviews

    private func serverCard(_ server: MCPServerConfig) -> some View {
        let state = manager.state(for: server.id)
        return HStack(spacing: 10) {
            Image(systemName: state == .connected ? "link.circle.fill" : "link.circle")
                .foregroundStyle(state == .connected ? theme.success : theme.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.appBodyEmphasized)
                        .lineLimit(1)
                    statusBadge(state)
                }
                Text(server.command + (server.arguments.isEmpty ? "" : " " + server.arguments.joined(separator: " ")))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text(String(format: MCPText.string("tools-count"), manager.connectedToolCount(serverID: server.id)))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            AppToggleRow(
                title: "",
                isOn: Binding(
                    get: { server.enabled },
                    set: { enabled in
                        var updated = server
                        updated.enabled = enabled
                        registry.updateServer(updated)
                        Task { @MainActor in
                            if enabled {
                                await manager.connect(serverID: server.id)
                            } else {
                                await manager.disconnect(serverID: server.id)
                            }
                        }
                        revision += 1
                    }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            AppButton("", systemImage: "pencil", size: .small) {
                editingServerID = server.id
            }
            .help(MCPText.string("Edit"))
            AppButton("", systemImage: "trash", size: .small) {
                Task { @MainActor in
                    await manager.disconnect(serverID: server.id)
                }
                registry.removeServer(id: server.id)
                revision += 1
            }
            .help(MCPText.string("Delete"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 0.5)
        }
    }

    private func statusBadge(_ state: MCPServerConnectionState) -> some View {
        let color: Color
        switch state {
        case .connected: color = theme.success
        case .connecting: color = theme.warning
        case .error: color = .red
        case .disconnected: color = theme.textSecondary
        }
        return Text(MCPText.string(state.displayName))
            .font(.appCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func templateCard(title: String, detail: String, systemImage: String, add: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appBodyEmphasized)
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 4)
            AppButton(MCPText.string("Add"), size: .small, action: add)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 0.5)
        }
    }

    private func toolGroup(config: MCPServerConfig, adapters: [MCPToolAdapter]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(config.name)
                .font(.appBodyEmphasized)
                .padding(.top, 4)
            ForEach(adapters, id: \.name) { adapter in
                toolRow(config: config, adapter: adapter)
            }
        }
    }

    private func toolRow(config: MCPServerConfig, adapter: MCPToolAdapter) -> some View {
        let level = adapter.policy.level(
            for: adapter.descriptor,
            override: adapter.riskOverride
        )
        return HStack(spacing: 8) {
            Text(adapter.descriptor.name)
                .font(.appBody)
                .lineLimit(1)
            if let description = adapter.descriptor.description {
                Text(description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            riskBadge(level)
            riskPicker(
                selection: Binding(
                    get: { registry.riskOverride(serverID: config.id, toolName: adapter.descriptor.name) },
                    set: { registry.setRiskOverride(serverID: config.id, toolName: adapter.descriptor.name, level: $0) }
                ),
                compact: true
            )
        }
        .padding(.vertical, 4)
    }

    private func riskBadge(_ level: CommandRiskLevel) -> some View {
        let color: Color
        switch level {
        case .safe: color = theme.success
        case .low: color = theme.success.opacity(0.8)
        case .medium: color = theme.warning
        case .high: color = .red
        }
        return Text(level.displayName)
            .font(.appCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func riskPicker(selection: Binding<CommandRiskLevel?>, compact: Bool) -> some View {
        Picker("", selection: selection) {
            Text(MCPText.string("Auto")).tag(CommandRiskLevel?.none)
            Text(MCPText.string("Safe")).tag(CommandRiskLevel?.some(.safe))
            Text(MCPText.string("Low")).tag(CommandRiskLevel?.some(.low))
            Text(MCPText.string("Medium")).tag(CommandRiskLevel?.some(.medium))
            Text(MCPText.string("High")).tag(CommandRiskLevel?.some(.high))
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: compact ? 90 : 110)
        .controlSize(.small)
    }

    // MARK: - Actions

    private func addTemplate(_ template: MCPServerConfig) {
        if registry.servers.contains(where: { $0.command == template.command && $0.arguments == template.arguments }) {
            return
        }
        var config = template
        config.enabled = true
        let saved = registry.addServer(config)
        Task { @MainActor in
            await manager.connect(serverID: saved.id)
        }
        revision += 1
    }
}

// MARK: - Add / Edit Sheet

/// 添加 / 编辑服务器的表单。
@MainActor
struct MCPServerEditSheet: View {
    @ObservedObject var registry: MCPServerRegistry
    @ObservedObject var manager: MCPConnectionManager
    let server: MCPServerConfig?
    let onSaved: (MCPServerConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @LumiTheme private var theme

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var argumentsText: String = ""
    @State private var transport: MCPTransport = .stdio
    @State private var url: String = ""
    @State private var environmentText: String = ""
    @State private var autoStart = false
    @State private var enabled = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var isEditing: Bool { server != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(MCPText.string(isEditing ? "Edit Server" : "Add Server"))
                    .font(.appTitle)
                Spacer()
                AppButton("", systemImage: "xmark", size: .small) { dismiss() }
            }

            VStack(alignment: .leading, spacing: 10) {
                formField(MCPText.string("Name")) {
                    TextField(MCPText.string("e.g. Xcode (native)"), text: $name)
                }
                formField(MCPText.string("Transport")) {
                    Picker("", selection: $transport) {
                        Text("stdio").tag(MCPTransport.stdio)
                        Text("Streamable HTTP").tag(MCPTransport.streamableHTTP)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                formField(MCPText.string("Command")) {
                    TextField("xcrun", text: $command)
                }
                if transport == .stdio {
                    formField(MCPText.string("Arguments (space-separated)")) {
                        TextField("mcpbridge", text: $argumentsText)
                    }
                } else {
                    formField(MCPText.string("URL")) {
                        TextField("https://example.com/mcp", text: $url)
                    }
                }
                formField(MCPText.string("Environment (KEY=VALUE, one per line)")) {
                    TextEditor(text: $environmentText)
                        .font(.appBody)
                        .frame(height: 60)
                        .padding(4)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.divider, lineWidth: 0.5)
                        }
                }
                AppToggleRow(
                    title: LocalizedStringKey(MCPText.string("Auto-start")),
                    description: LocalizedStringKey(MCPText.string("Connect automatically when Lumi starts.")),
                    isOn: $autoStart
                )
                AppToggleRow(
                    title: LocalizedStringKey(MCPText.string("Enabled")),
                    description: LocalizedStringKey(MCPText.string("Disabled servers never spawn or register tools.")),
                    isOn: $enabled
                )
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Text(MCPText.string("This server runs programs with Lumi's permissions. Only add trusted sources."))
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
                Spacer()
                AppButton(MCPText.string("Cancel"), size: .small) { dismiss() }
                AppButton(MCPText.string("Save & Connect"), size: .small) {
                    saveAndConnect()
                }
                .disabled(isSaving)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let server else { return }
        name = server.name
        command = server.command
        argumentsText = server.arguments.joined(separator: " ")
        transport = server.transport
        url = server.url ?? ""
        environmentText = server.environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        autoStart = server.autoStart
        enabled = server.enabled
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func saveAndConnect() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = MCPText.string("Name is required.")
            return
        }
        guard !trimmedCommand.isEmpty else {
            errorMessage = MCPText.string("Command is required.")
            return
        }
        if transport == .streamableHTTP, trimmedURL.isEmpty {
            errorMessage = MCPText.string("URL is required for HTTP transport.")
            return
        }

        var arguments: [String] = []
        if transport == .stdio {
            arguments = argumentsText
                .split(whereSeparator: { $0 == " " || $0 == "\n" })
                .map(String.init)
        }

        var environment: [String: String] = [:]
        for line in environmentText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...])
            if !key.isEmpty {
                environment[key] = value
            }
        }

        let config = MCPServerConfig(
            id: server?.id ?? "",
            name: trimmedName,
            command: trimmedCommand,
            arguments: arguments,
            environment: environment,
            transport: transport,
            url: transport == .streamableHTTP ? trimmedURL : nil,
            autoStart: autoStart,
            enabled: enabled
        )

        isSaving = true
        errorMessage = nil
        let saved = registry.addServer(config)
        Task { @MainActor in
            if saved.enabled {
                await manager.reconnectIfActive(serverID: saved.id)
            }
            isSaving = false
            onSaved(saved)
            dismiss()
        }
    }
}
