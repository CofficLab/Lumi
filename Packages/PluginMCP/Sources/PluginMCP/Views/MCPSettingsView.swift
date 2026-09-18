import Combine
import KitAgentTool
import KitMCP
import LumiUI
import SwiftUI

/// Cursor 式"MCP 服务器"设置页——左侧列表 + 右侧详情。
///
/// - 左侧：全局开关、搜索、服务器列表（点击选中）；
/// - 右侧：选中服务器的状态、启停、工具列表与编辑/删除；
/// - 添加/编辑表单仍走 sheet；
/// - 内置模板区放在左侧列表底部。
@MainActor
struct MCPSettingsView: View {
    @ObservedObject var registry: MCPServerRegistry
    @ObservedObject var manager: MCPConnectionManager
    @LumiTheme private var theme

    @State private var showingAddSheet = false
    @State private var editingServerID: String?
    @State private var selectedServerID: String?
    @State private var searchText = ""
    @State private var revision = 0

    var body: some View {
        PluginSettingsScaffold(
            title: MCPText.string("MCP Servers"),
            subtitle: MCPText.string("Connect any Model Context Protocol server and let the agent use its tools."),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                header
                masterDetail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .id(revision)
        .sheet(isPresented: $showingAddSheet) {
            MCPServerEditSheet(registry: registry, manager: manager, server: nil) { _ in revision += 1 }
        }
        .sheet(item: Binding(
            get: { editingServerID.flatMap { id in registry.server(id: id) } },
            set: { editingServerID = $0?.id }
        )) { server in
            MCPServerEditSheet(registry: registry, manager: manager, server: server) { _ in revision += 1 }
        }
        .onAppear {
            if selectedServerID == nil, let first = registry.servers.first {
                selectedServerID = first.id
            }
        }
        .onChange(of: registry.servers.count) { _, _ in
            if selectedServerID == nil, let first = registry.servers.first {
                selectedServerID = first.id
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(
                MCPText.string("MCP Servers"),
                systemImage: "shippingbox"
            )
            Text(String(format: MCPText.string("%d servers"), registry.servers.count))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            AppButton(MCPText.string("Add Server"), systemImage: "plus", style: .primary, size: .small) {
                showingAddSheet = true
            }
        }
        .font(.appCaption)
    }

    // MARK: - Master–Detail

    private var masterDetail: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 280)
                .frame(maxHeight: .infinity)
            AppDivider(.vertical)
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 460, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(MCPText.string("Search servers")))
                .padding(12)
            AppDivider()
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredServers) { server in
                        serverRow(server)
                    }
                    if filteredServers.isEmpty {
                        Text(MCPText.string("No servers found"))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    // MARK: - Sidebar Rows

    private func serverRow(_ server: MCPServerConfig) -> some View {
        let isSelected = selectedServerID == server.id
        let state = manager.state(for: server.id)
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.15)) { selectedServerID = server.id }
        }) {
            HStack(spacing: 10) {
                Image(systemName: state == .connected ? "link.circle.fill" : "link.circle")
                    .foregroundStyle(state == .connected ? theme.success : theme.textSecondary)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(server.name)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(server.command + (server.arguments.isEmpty ? "" : " " + server.arguments.joined(separator: " ")))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let selectedServerID,
           let server = registry.server(id: selectedServerID) {
            ScrollView {
                serverDetail(server)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "shippingbox",
                title: MCPText.string("Select a server"),
                description: MCPText.string("Choose a server from the list, or add a new one.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    private func serverDetail(_ server: MCPServerConfig) -> some View {
        let state = manager.state(for: server.id)
        return VStack(alignment: .leading, spacing: 18) {
            // 标题行：名称 + 状态 + 启停开关 + 编辑/删除
            HStack(spacing: 12) {
                Image(systemName: state == .connected ? "link.circle.fill" : "link.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(state == .connected ? theme.success : theme.textSecondary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(server.name)
                            .font(.title3.weight(.semibold))
                        statusBadge(state)
                    }
                    Text(server.command + (server.arguments.isEmpty ? "" : " " + server.arguments.joined(separator: " ")))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { server.enabled },
                    set: { enabled in
                        var updated = server
                        updated.enabled = enabled
                        registry.updateServer(updated)
                        Task { @MainActor in
                            if enabled { await manager.connect(serverID: server.id) }
                            else { await manager.disconnect(serverID: server.id) }
                        }
                        revision += 1
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                AppButton("", systemImage: "pencil", size: .small) { editingServerID = server.id }
                    .help(MCPText.string("Edit"))
                AppButton("", systemImage: "trash", size: .small) {
                    Task { @MainActor in await manager.disconnect(serverID: server.id) }
                    registry.removeServer(id: server.id)
                    if selectedServerID == server.id { selectedServerID = nil }
                    revision += 1
                }
                .help(MCPText.string("Delete"))
            }

            AppDivider()

            // 工具数与未知工具风险
            HStack(spacing: 10) {
                Text(String(format: MCPText.string("%d tools"), manager.connectedToolCount(serverID: server.id)))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                riskPicker(
                    selection: Binding(
                        get: { registry.unknownToolDefaultLevel },
                        set: { registry.unknownToolDefaultLevel = $0 ?? .high }
                    ),
                    compact: true
                )
            }

            // 该服务器的工具列表
            let tools = manager.registeredTools
            if let adapters = tools[server.id], !adapters.isEmpty {
                AppDivider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(MCPText.string("Tools"))
                        .font(.appCaptionEmphasized)
                    ForEach(adapters, id: \.name) { adapter in
                        toolRow(server: server, adapter: adapter)
                    }
                }
            }

            AppDivider()
            securityNotice
        }
    }

    private func toolRow(server: MCPServerConfig, adapter: MCPToolAdapter) -> some View {
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
                    get: { registry.riskOverride(serverID: server.id, toolName: adapter.descriptor.name) },
                    set: { registry.setRiskOverride(serverID: server.id, toolName: adapter.descriptor.name, level: $0) }
                ),
                compact: true
            )
        }
        .padding(.vertical, 4)
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

    private var securityNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warning)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(MCPText.string("Security notice"))
                    .font(.appBodyEmphasized)
                Text(MCPText.string("An MCP server runs programs on this machine with Lumi's permissions — equivalent to executing arbitrary local commands. Only add servers you trust."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var filteredServers: [MCPServerConfig] {
        if searchText.isEmpty { return registry.servers }
        return registry.servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.command.localizedCaseInsensitiveContains(searchText)
        }
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
        let saved: MCPServerConfig
        if isEditing {
            registry.updateServer(config)
            saved = config
        } else {
            saved = registry.addServer(config)
        }
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
