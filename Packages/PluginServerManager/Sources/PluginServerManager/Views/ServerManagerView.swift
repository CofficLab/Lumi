import SwiftUI

/// 主内容区：概览 / 进程 / 容器 / 控制台四个分页。
struct ServerManagerView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case overview, processes, containers, console
        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return ServerManagerLocalization.string("Overview")
            case .processes: return ServerManagerLocalization.string("Processes")
            case .containers: return ServerManagerLocalization.string("Containers")
            case .console: return ServerManagerLocalization.string("Console")
            }
        }
    }

    @ObservedObject var viewModel: ServerManagerViewModel
    @State private var tab: Tab = .overview
    @State private var isConfirmingRemove = false
    @State private var pendingKill: ServerProcess?
    @State private var pendingContainerAction: (name: String, action: ServerContainerAction)?
    @State private var pendingCommand: String?
    @State private var commandDraft = ""
    @State private var actionError: String?

    var body: some View {
        if let server = viewModel.selectedServer {
            detail(for: server)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(ServerManagerLocalization.string("Select a server to see its status."))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detail(for server: ServerConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: server)
            Divider()
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                switch tab {
                case .overview: OverviewTab(viewModel: viewModel, server: server)
                case .processes: ProcessesTab(
                    viewModel: viewModel, server: server,
                    pendingKill: $pendingKill
                )
                case .containers: ContainersTab(
                    viewModel: viewModel, server: server,
                    pendingAction: $pendingContainerAction
                )
                case .console: ConsoleTab(
                    viewModel: viewModel, server: server,
                    draft: $commandDraft, pendingCommand: $pendingCommand
                )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog(
            ServerManagerLocalization.string("Remove Server"),
            isPresented: $isConfirmingRemove,
            titleVisibility: .visible
        ) {
            Button(ServerManagerLocalization.string("Remove"), role: .destructive) {
                Task { try? await viewModel.removeServer(id: server.id) }
            }
        } message: {
            Text("\(server.name) (\(server.destination))")
        }
        .confirmationDialog(
            ServerManagerLocalization.string("Kill Process"),
            isPresented: Binding(
                get: { pendingKill != nil },
                set: { if !$0 { pendingKill = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(ServerManagerLocalization.string("Terminate (SIGTERM)")) {
                killPending(force: false)
            }
            Button(ServerManagerLocalization.string("Force Kill (SIGKILL)"), role: .destructive) {
                killPending(force: true)
            }
        } message: {
            if let process = pendingKill {
                Text("PID \(process.pid) · \(process.command)")
            }
        }
        .confirmationDialog(
            ServerManagerLocalization.string("Confirm Container Action"),
            isPresented: Binding(
                get: { pendingContainerAction != nil },
                set: { if !$0 { pendingContainerAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(ServerManagerLocalization.string("Confirm"), role: .destructive) {
                runPendingContainerAction()
            }
        } message: {
            if let pending = pendingContainerAction {
                Text("\(pending.action.rawValue) · \(pending.name)")
            }
        }
        .confirmationDialog(
            ServerManagerLocalization.string("High risk command"),
            isPresented: Binding(
                get: { pendingCommand != nil },
                set: { if !$0 { pendingCommand = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(ServerManagerLocalization.string("Run Anyway"), role: .destructive) {
                if let command = pendingCommand {
                    pendingCommand = nil
                    Task { await viewModel.runCommand(id: server.id, command: command) }
                }
            }
        } message: {
            Text(ServerManagerLocalization.string("This command may modify the server. Run it anyway?"))
        }
        .alert(
            ServerManagerLocalization.string("Action failed"),
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button(ServerManagerLocalization.string("OK"), role: .cancel) {}
        } message: {
            if let actionError { Text(actionError) }
        }
    }

    private func header(for server: ServerConfig) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(server.name)
                    .font(.title3.weight(.semibold))
                Text("ssh \(server.destination) -p \(server.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            Spacer()
            Button(role: .destructive) {
                isConfirmingRemove = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(16)
    }

    private func killPending(force: Bool) {
        guard let process = pendingKill, let server = viewModel.selectedServer else { return }
        pendingKill = nil
        Task {
            do {
                try await viewModel.killProcess(id: server.id, pid: process.pid, force: force)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func runPendingContainerAction() {
        guard let pending = pendingContainerAction, let server = viewModel.selectedServer else { return }
        pendingContainerAction = nil
        Task {
            do {
                try await viewModel.containerAction(id: server.id, name: pending.name, action: pending.action)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

// MARK: - 概览

private struct OverviewTab: View {
    @ObservedObject var viewModel: ServerManagerViewModel
    let server: ServerConfig

    var body: some View {
        let state = viewModel.metricsStates[server.id] ?? .idle
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(ServerManagerLocalization.string("Refresh")) {
                    Task { await viewModel.loadMetrics(id: server.id) }
                }
                .disabled(state == .loading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch state {
            case .idle:
                ContentUnavailableView(
                    ServerManagerLocalization.string("No metrics yet"),
                    systemImage: "gauge.with.dots.needle.67percent",
                    description: Text(ServerManagerLocalization.string("Click Refresh to collect metrics over SSH."))
                )
            case .loading:
                VStack(spacing: 10) {
                    ProgressView()
                    Text(ServerManagerLocalization.string("Loading…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView(
                    ServerManagerLocalization.string("Load failed"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let metrics):
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            MetricCard(title: ServerManagerLocalization.string("CPU"), percent: metrics.cpuPercent)
                            MetricCard(title: ServerManagerLocalization.string("Memory"), percent: metrics.memPercent)
                            MetricCard(title: ServerManagerLocalization.string("Disk"), percent: metrics.diskPercent)
                        }
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                infoRow(ServerManagerLocalization.string("OS"), metrics.os)
                                infoRow(ServerManagerLocalization.string("Hostname"), metrics.hostname)
                                infoRow(ServerManagerLocalization.string("Uptime"), metrics.uptime)
                                infoRow(ServerManagerLocalization.string("Cores"), metrics.cores.map(String.init))
                                infoRow(ServerManagerLocalization.string("Load Average"), loadText(metrics))
                                infoRow(
                                    ServerManagerLocalization.string("Memory"),
                                    byteText(used: metrics.memUsedBytes, total: metrics.memTotalBytes)
                                )
                                infoRow(
                                    ServerManagerLocalization.string("Disk"),
                                    byteText(used: metrics.diskUsedBytes, total: metrics.diskTotalBytes)
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .task(id: server.id) {
            if viewModel.metricsStates[server.id] == nil {
                await viewModel.loadMetrics(id: server.id)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value ?? "—")
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private func loadText(_ metrics: ServerMetrics) -> String? {
        guard let load1 = metrics.load1, let load5 = metrics.load5, let load15 = metrics.load15 else { return nil }
        return String(format: "%.2f  %.2f  %.2f", load1, load5, load15)
    }

    private func byteText(used: Int64?, total: Int64?) -> String? {
        guard let used, let total else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return "\(formatter.string(fromByteCount: used)) / \(formatter.string(fromByteCount: total))"
    }
}

private struct MetricCard: View {
    let title: String
    let percent: Double?

    var body: some View {
        GroupBox {
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let percent {
                    Text(String(format: "%.0f%%", percent))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    ProgressView(value: min(100, max(0, percent)), total: 100)
                        .tint(color(for: percent))
                } else {
                    Text("—")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(6)
        }
    }

    private func color(for percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .accentColor
    }
}

// MARK: - 进程

private struct ProcessesTab: View {
    @ObservedObject var viewModel: ServerManagerViewModel
    let server: ServerConfig
    @Binding var pendingKill: ServerProcess?

    var body: some View {
        let state = viewModel.processStates[server.id] ?? .idle
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(ServerManagerLocalization.string("Refresh")) {
                    Task { await viewModel.loadProcesses(id: server.id) }
                }
                .disabled(state == .loading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch state {
            case .idle, .loading:
                VStack(spacing: 10) {
                    ProgressView()
                    Text(ServerManagerLocalization.string("Loading…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView(
                    ServerManagerLocalization.string("Load failed"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let processes):
                if processes.isEmpty {
                    ContentUnavailableView(
                        ServerManagerLocalization.string("No processes found."),
                        systemImage: "list.bullet.rectangle"
                    )
                } else {
                    List(processes) { process in
                        ProcessRow(process: process) { pendingKill = process }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .task(id: server.id) {
            if viewModel.processStates[server.id] == nil {
                await viewModel.loadProcesses(id: server.id)
            }
        }
    }
}

private struct ProcessRow: View {
    let process: ServerProcess
    let onKill: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(process.pid)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(process.command)
                    .font(.callout)
                    .lineLimit(1)
                Text(process.user)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%.1f%%", process.cpu))
                .font(.callout.monospacedDigit())
                .frame(width: 56, alignment: .trailing)
            Text(String(format: "%.1f%%", process.mem))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Button(action: onKill) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help(ServerManagerLocalization.string("Kill Process"))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 容器

private struct ContainersTab: View {
    @ObservedObject var viewModel: ServerManagerViewModel
    let server: ServerConfig
    @Binding var pendingAction: (name: String, action: ServerContainerAction)?

    var body: some View {
        let state = viewModel.containerStates[server.id] ?? .idle
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(ServerManagerLocalization.string("Refresh")) {
                    Task { await viewModel.loadContainers(id: server.id) }
                }
                .disabled(state == .loading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch state {
            case .idle, .loading:
                VStack(spacing: 10) {
                    ProgressView()
                    Text(ServerManagerLocalization.string("Loading…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView(
                    ServerManagerLocalization.string("Load failed"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let containers):
                if containers.isEmpty {
                    ContentUnavailableView(
                        ServerManagerLocalization.string("No containers found."),
                        systemImage: "shippingbox"
                    )
                } else {
                    List(containers) { container in
                        ContainerRow(container: container) { action in
                            pendingAction = (container.name, action)
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .task(id: server.id) {
            if viewModel.containerStates[server.id] == nil {
                await viewModel.loadContainers(id: server.id)
            }
        }
    }
}

private struct ContainerRow: View {
    let container: ServerContainer
    let onAction: (ServerContainerAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(container.state == .running ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(container.image) · \(container.status)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if container.state != .running {
                Button(ServerManagerLocalization.string("Start")) { onAction(.start) }
                    .buttonStyle(.borderless)
            }
            if container.state == .running {
                Button(ServerManagerLocalization.string("Restart")) { onAction(.restart) }
                    .buttonStyle(.borderless)
                Button(ServerManagerLocalization.string("Stop")) { onAction(.stop) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 控制台

private struct ConsoleTab: View {
    @ObservedObject var viewModel: ServerManagerViewModel
    let server: ServerConfig
    @Binding var draft: String
    @Binding var pendingCommand: String?

    var body: some View {
        let entries = viewModel.consoleEntries[server.id] ?? []
        let isRunning = viewModel.consoleRunning.contains(server.id)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if entries.isEmpty {
                        Text(ServerManagerLocalization.string("Run a command on this server…"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(entries) { entry in
                        ConsoleEntryView(entry: entry)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack(spacing: 8) {
                TextField(ServerManagerLocalization.string("Run a command on this server…"), text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .fontDesign(.monospaced)
                    .onSubmit(run)
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(ServerManagerLocalization.string("Run"), action: run)
                    .disabled(isRunning || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                Button(ServerManagerLocalization.string("Clear")) {
                    viewModel.clearConsole(id: server.id)
                }
                .disabled(entries.isEmpty)
            }
            .padding(12)
            if ServerExecRisk.level(for: draft) == .high,
               !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Label(
                    ServerManagerLocalization.string("This command may modify the server. Run it anyway?"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func run() {
        let command = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        draft = ""
        if ServerExecRisk.level(for: command) == .high {
            pendingCommand = command
        } else {
            Task { await viewModel.runCommand(id: server.id, command: command) }
        }
    }
}

private struct ConsoleEntryView: View {
    let entry: ConsoleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("$ \(entry.command)")
                .font(.callout.weight(.semibold))
                .fontDesign(.monospaced)
            Text(entry.output)
                .font(.callout)
                .fontDesign(.monospaced)
                .foregroundStyle(entry.isError ? Color.red : Color.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}