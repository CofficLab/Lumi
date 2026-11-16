import Combine
import Foundation

/// 通用加载态。
public enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

/// 控制台历史条目。
public struct ConsoleEntry: Equatable, Identifiable {
    public let id: UUID
    public let command: String
    public let output: String
    public let isError: Bool
    public let at: Date

    public init(command: String, output: String, isError: Bool, at: Date) {
        self.id = UUID()
        self.command = command
        self.output = output
        self.isError = isError
        self.at = at
    }
}

/// 服务器管理主 ViewModel。
///
/// 所有异步写回都带身份校验：await 之后确认目标服务器仍在列表中，
/// 且本轮加载仍是最新一代（重复刷新时旧结果不得覆盖新结果），
/// 避免删除/切换后旧探测结果覆盖新状态。
@MainActor
public final class ServerManagerViewModel: ObservableObject {
    public enum ProbeState: Equatable {
        case idle
        case probing
        case online(output: String, at: Date)
        case failed(message: String)
    }

    let backend: ServerBackend

    @Published private(set) var servers: [ServerConfig] = []
    @Published var selectedID: UUID?
    @Published private(set) var probeStates: [UUID: ProbeState] = [:]
    @Published var isAddSheetPresented = false

    @Published private(set) var metricsStates: [UUID: LoadState<ServerMetrics>] = [:]
    @Published private(set) var processStates: [UUID: LoadState<[ServerProcess]>] = [:]
    @Published private(set) var containerStates: [UUID: LoadState<[ServerContainer]>] = [:]
    @Published private(set) var consoleEntries: [UUID: [ConsoleEntry]] = [:]
    @Published private(set) var consoleRunning: Set<UUID> = []

    /// 每个「服务器 + 数据类型」的加载代次，用于丢弃晚到的旧结果。
    private var loadGenerations: [String: Int] = [:]

    public init(backend: ServerBackend) {
        self.backend = backend
    }

    var selectedServer: ServerConfig? {
        servers.first { $0.id == selectedID }
    }

    func refresh() async {
        servers = await backend.allServers()
        if let selectedID, !servers.contains(where: { $0.id == selectedID }) {
            self.selectedID = servers.first?.id
        }
    }

    func addServer(name: String, host: String, port: Int, user: String, group: String) async throws {
        let config = ServerConfig(
            name: name.isEmpty ? host : name,
            host: host,
            port: max(1, min(65535, port)),
            user: user,
            group: group.isEmpty ? "Default" : group
        )
        try await backend.add(config)
        await refresh()
        selectedID = config.id
    }

    func removeServer(id: UUID) async throws {
        try await backend.remove(id: id)
        probeStates[id] = nil
        metricsStates[id] = nil
        processStates[id] = nil
        containerStates[id] = nil
        consoleEntries[id] = nil
        consoleRunning.remove(id)
        await refresh()
    }

    func probe(id: UUID) async {
        probeStates[id] = .probing
        do {
            let output = try await backend.probe(id: id)
            guard servers.contains(where: { $0.id == id }) else { return }
            probeStates[id] = .online(output: output, at: Date())
        } catch {
            guard servers.contains(where: { $0.id == id }) else { return }
            probeStates[id] = .failed(message: error.localizedDescription)
        }
    }

    func probeState(for id: UUID) -> ProbeState {
        probeStates[id] ?? .idle
    }

    // MARK: - 指标 / 进程 / 容器

    func loadMetrics(id: UUID) async {
        guard servers.contains(where: { $0.id == id }) else { return }
        let generation = beginLoad(id, kind: "metrics")
        metricsStates[id] = .loading
        do {
            let value = try await backend.metrics(id: id)
            guard isCurrent(id, kind: "metrics", generation: generation) else { return }
            metricsStates[id] = .loaded(value)
        } catch {
            guard isCurrent(id, kind: "metrics", generation: generation) else { return }
            metricsStates[id] = .failed(error.localizedDescription)
        }
    }

    func loadProcesses(id: UUID) async {
        guard servers.contains(where: { $0.id == id }) else { return }
        let generation = beginLoad(id, kind: "processes")
        processStates[id] = .loading
        do {
            let value = try await backend.processes(id: id)
            guard isCurrent(id, kind: "processes", generation: generation) else { return }
            processStates[id] = .loaded(value)
        } catch {
            guard isCurrent(id, kind: "processes", generation: generation) else { return }
            processStates[id] = .failed(error.localizedDescription)
        }
    }

    func loadContainers(id: UUID) async {
        guard servers.contains(where: { $0.id == id }) else { return }
        let generation = beginLoad(id, kind: "containers")
        containerStates[id] = .loading
        do {
            let value = try await backend.containers(id: id)
            guard isCurrent(id, kind: "containers", generation: generation) else { return }
            containerStates[id] = .loaded(value)
        } catch {
            guard isCurrent(id, kind: "containers", generation: generation) else { return }
            containerStates[id] = .failed(error.localizedDescription)
        }
    }

    func killProcess(id: UUID, pid: Int, force: Bool) async throws {
        try await backend.killProcess(id: id, pid: pid, force: force)
        guard servers.contains(where: { $0.id == id }) else { return }
        await loadProcesses(id: id)
    }

    func containerAction(id: UUID, name: String, action: ServerContainerAction) async throws {
        try await backend.containerAction(id: id, name: name, action: action)
        guard servers.contains(where: { $0.id == id }) else { return }
        await loadContainers(id: id)
    }

    // MARK: - 控制台

    func runCommand(id: UUID, command: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, servers.contains(where: { $0.id == id }), !consoleRunning.contains(id) else { return }
        consoleRunning.insert(id)
        do {
            let output = try await backend.exec(id: id, command: trimmed)
            consoleRunning.remove(id)
            guard servers.contains(where: { $0.id == id }) else { return }
            appendEntry(ConsoleEntry(command: trimmed, output: output, isError: false, at: Date()), for: id)
        } catch {
            consoleRunning.remove(id)
            guard servers.contains(where: { $0.id == id }) else { return }
            appendEntry(ConsoleEntry(command: trimmed, output: error.localizedDescription, isError: true, at: Date()), for: id)
        }
    }

    func clearConsole(id: UUID) {
        consoleEntries[id] = nil
    }

    private func appendEntry(_ entry: ConsoleEntry, for id: UUID) {
        var entries = consoleEntries[id] ?? []
        entries.append(entry)
        if entries.count > 50 { entries.removeFirst(entries.count - 50) }
        consoleEntries[id] = entries
    }

    // MARK: - 代次校验

    private func beginLoad(_ id: UUID, kind: String) -> Int {
        let key = generationKey(id, kind: kind)
        let next = (loadGenerations[key] ?? 0) + 1
        loadGenerations[key] = next
        return next
    }

    private func isCurrent(_ id: UUID, kind: String, generation: Int) -> Bool {
        servers.contains { $0.id == id } && loadGenerations[generationKey(id, kind: kind)] == generation
    }

    private func generationKey(_ id: UUID, kind: String) -> String {
        "\(id.uuidString)/\(kind)"
    }
}