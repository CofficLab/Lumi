import Foundation
import KitAgentTool
import Testing

@testable import PluginServerManager

@Suite
struct ServerMetricsParserTests {
    static let linuxOutput = """
    ===OS===
    Linux 6.8.0
    ===HOST===
    web-01
    ===UPTIME===
     10:00:00 up 5 days,  2:13,  1 user,  load average: 0.52, 0.58, 0.59
    ===LOAD===
    0.52 0.58 0.59 1/234 5678
    ===CORES===
    8
    ===MEM===
    16000000000 6000000000
    ===DISK===
    /dev/sda1 100000000 40000000 60000000 40% /
    ===CPU===
    cpu  100 0 100 800 0 0 0 0
    cpu  200 0 200 1600 0 0 0 0
    ===END===
    """

    @Test
    func parsesLinuxMetrics() {
        let metrics = ServerMetricsParser.parseMetrics(Self.linuxOutput)
        #expect(metrics.os == "Linux 6.8.0")
        #expect(metrics.hostname == "web-01")
        #expect(metrics.uptime?.contains("up 5 days") == true)
        #expect(metrics.load1 == 0.52)
        #expect(metrics.load5 == 0.58)
        #expect(metrics.load15 == 0.59)
        #expect(metrics.cores == 8)
        #expect(metrics.memTotalBytes == 16_000_000_000)
        #expect(metrics.memUsedBytes == 10_000_000_000)
        #expect(metrics.memPercent == 62.5)
        #expect(metrics.diskTotalBytes == Int64(100_000_000) * 1024)
        #expect(metrics.diskUsedBytes == Int64(40_000_000) * 1024)
        #expect(metrics.diskPercent == 40)
        #expect(metrics.cpuPercent == 20)
    }

    @Test
    func parsesMacOSLoadAndMissingSections() {
        let output = """
        ===OS===
        Darwin 25.0.0
        ===LOAD===
        { 1.23 1.45 1.67 }
        ===CORES===
        10
        ===MEM===
        ===DISK===
        ===CPU===
        ===END===
        """
        let metrics = ServerMetricsParser.parseMetrics(output)
        #expect(metrics.load1 == 1.23)
        #expect(metrics.load15 == 1.67)
        #expect(metrics.cores == 10)
        #expect(metrics.memTotalBytes == nil)
        #expect(metrics.memPercent == nil)
        #expect(metrics.diskPercent == nil)
        #expect(metrics.cpuPercent == nil)
    }

    @Test
    func emptyOutputYieldsEmptyMetrics() {
        let metrics = ServerMetricsParser.parseMetrics("")
        #expect(metrics == ServerMetrics())
    }

    @Test
    func cpuNeedsTwoSamplesAndPositiveDelta() {
        let oneSample = """
        ===CPU===
        cpu  100 0 100 800 0 0 0 0
        ===END===
        """
        #expect(ServerMetricsParser.parseMetrics(oneSample).cpuPercent == nil)

        let sameSample = """
        ===CPU===
        cpu  100 0 100 800 0 0 0 0
        cpu  100 0 100 800 0 0 0 0
        ===END===
        """
        #expect(ServerMetricsParser.parseMetrics(sameSample).cpuPercent == nil)
    }

    @Test
    func parsesProcessesWithSpacesInCommand() {
        let output = """
          PID USER     %CPU %MEM COMMAND
          101 root      9.5  1.2 /usr/bin/python3 app.py
            7 deploy    0.0  0.1 sshd: deploy@pts/0
        """
        let processes = ServerMetricsParser.parseProcesses(output)
        #expect(processes.count == 2)
        #expect(processes[0].pid == 101)
        #expect(processes[0].cpu == 9.5)
        #expect(processes[0].command == "/usr/bin/python3 app.py")
        #expect(processes[1].user == "deploy")
    }

    @Test
    func processesCapAt20AndSkipGarbage() {
        var lines = ["PID USER %CPU %MEM COMMAND"]
        for i in 1...30 {
            lines.append("\(i) root 0.0 0.0 proc\(i)")
        }
        lines.append("not-a-process-line")
        let processes = ServerMetricsParser.parseProcesses(lines.joined(separator: "\n"))
        #expect(processes.count == 20)
        #expect(processes.last?.pid == 20)
    }

    @Test
    func parsesContainers() {
        let output = "web\tnginx:latest\trunning\tUp 2 hours\ndb\tpostgres:16\texited\tExited (0) 3 minutes ago\nodd\timg\tweird-state\tstatus"
        let containers = ServerMetricsParser.parseContainers(output)
        #expect(containers.count == 3)
        #expect(containers[0].name == "web")
        #expect(containers[0].state == .running)
        #expect(containers[1].state == .exited)
        #expect(containers[2].state == .unknown)
    }

    @Test
    func containerNameValidation() {
        #expect(ServerContainer.isValidName("web-01.prod_2"))
        #expect(!ServerContainer.isValidName(""))
        #expect(!ServerContainer.isValidName("a b"))
        #expect(!ServerContainer.isValidName("x; rm -rf /"))
        #expect(!ServerContainer.isValidName("$(reboot)"))
        #expect(!ServerContainer.isValidName(String(repeating: "a", count: 129)))
    }
}

@Suite
struct ServerExecRiskTests {
    @Test
    func readOnlyCommandsAreMedium() {
        for command in ["ls -la", "uptime", "df -h", "cat /etc/hostname", "docker ps", "systemctl status nginx", "git log --oneline"] {
            #expect(ServerExecRisk.level(for: command) == .medium, "\(command)")
        }
    }

    @Test
    func mutatingCommandsAreHigh() {
        for command in ["reboot", "rm -rf /data", "docker stop web", "systemctl restart nginx", "sudo ls", "apt upgrade", ""] {
            #expect(ServerExecRisk.level(for: command) == .high, "\(command)")
        }
    }

    @Test
    func shellMetacharactersEscalateToHigh() {
        for command in ["ls; rm x", "cat a && rm b", "cat a | tee b", "echo hi > file", "ls `reboot`", "echo $(reboot)", "ls\nreboot"] {
            #expect(ServerExecRisk.level(for: command) == .high, "\(command)")
        }
    }
}

@Suite
struct ServerFeatureToolTests {
    private func makeBackend() -> ServerBackend {
        ServerBackend(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("server-manager-feature-\(UUID().uuidString)", isDirectory: true))
    }

    @Test
    func processesToolFailureBranches() async throws {
        let tool = ServerProcessesTool(backend: makeBackend())
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("nope")])
        }
    }

    @Test
    func containerToolRiskAndApproval() {
        let tool = ServerContainerTool(backend: makeBackend())
        let list: [String: ToolArgument] = ["server": ToolArgument("web")]
        #expect(tool.permissionRiskLevel(arguments: list) == .low)
        #expect(tool.requiresExplicitApproval(arguments: list) == false)

        let stop: [String: ToolArgument] = ["server": ToolArgument("web"), "action": ToolArgument("stop"), "name": ToolArgument("db")]
        #expect(tool.permissionRiskLevel(arguments: stop) == .high)
        #expect(tool.requiresExplicitApproval(arguments: stop) == true)
    }

    @Test
    func containerToolFailureBranches() async throws {
        let backend = makeBackend()
        try await backend.add(ServerConfig(name: "web", host: "10.0.0.1", user: "root"))
        let tool = ServerContainerTool(backend: backend)

        // 未知服务器
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("nope")])
        }
        // 写操作缺 name
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("web"), "action": ToolArgument("stop")])
        }
        // 非法 action
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("web"), "action": ToolArgument("destroy"), "name": ToolArgument("db")])
        }
        // 非法容器名（注入字符）在后端校验处抛错
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("web"), "action": ToolArgument("stop"), "name": ToolArgument("x; reboot")])
        }
    }

    @Test
    func execToolRiskAndApproval() {
        let tool = ServerExecTool(backend: makeBackend())
        let readOnly: [String: ToolArgument] = ["server": ToolArgument("web"), "command": ToolArgument("uptime")]
        #expect(tool.permissionRiskLevel(arguments: readOnly) == .medium)
        #expect(tool.requiresExplicitApproval(arguments: readOnly) == false)

        let mutating: [String: ToolArgument] = ["server": ToolArgument("web"), "command": ToolArgument("reboot")]
        #expect(tool.permissionRiskLevel(arguments: mutating) == .high)
        #expect(tool.requiresExplicitApproval(arguments: mutating) == true)

        #expect(tool.permissionRiskLevel(arguments: [:]) == .high)
    }

    @Test
    func execToolFailureBranches() async throws {
        let tool = ServerExecTool(backend: makeBackend())
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("web")])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("web"), "command": ToolArgument("   ")])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool.execute(arguments: ["server": ToolArgument("nope"), "command": ToolArgument("ls")])
        }
    }
}

@Suite
struct ServerBackendValidationTests {
    private func makeBackend() -> ServerBackend {
        ServerBackend(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("server-manager-validation-\(UUID().uuidString)", isDirectory: true))
    }

    @Test
    func killRejectsInvalidPID() async throws {
        let backend = makeBackend()
        let config = ServerConfig(name: "web", host: "10.0.0.1", user: "root")
        try await backend.add(config)
        for pid in [0, -1, 5_000_000] {
            await #expect(throws: ServerBackendError.self) {
                try await backend.killProcess(id: config.id, pid: pid, force: false)
            }
        }
    }

    @Test
    func containerActionRejectsInvalidName() async throws {
        let backend = makeBackend()
        let config = ServerConfig(name: "web", host: "10.0.0.1", user: "root")
        try await backend.add(config)
        await #expect(throws: ServerBackendError.self) {
            try await backend.containerAction(id: config.id, name: "x; reboot", action: .stop)
        }
    }

    @Test
    func execRejectsEmptyCommand() async throws {
        let backend = makeBackend()
        let config = ServerConfig(name: "web", host: "10.0.0.1", user: "root")
        try await backend.add(config)
        await #expect(throws: ServerBackendError.self) {
            _ = try await backend.exec(id: config.id, command: "  \n ")
        }
    }
}

@Suite
@MainActor
struct ServerViewModelIdentityTests {
    private func makeViewModel() -> ServerManagerViewModel {
        ServerManagerViewModel(backend: ServerBackend(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("server-manager-vm-\(UUID().uuidString)", isDirectory: true)))
    }

    @Test
    func failedLoadForRemovedServerDoesNotWriteState() async {
        let viewModel = makeViewModel()
        // servers 为空：加载必然失败，但身份校验必须丢弃失败写回。
        await viewModel.loadMetrics(id: UUID())
        #expect(viewModel.metricsStates.isEmpty)
        await viewModel.loadProcesses(id: UUID())
        #expect(viewModel.processStates.isEmpty)
        await viewModel.loadContainers(id: UUID())
        #expect(viewModel.containerStates.isEmpty)
    }

    @Test
    func commandForRemovedServerDoesNotAppendHistory() async {
        let viewModel = makeViewModel()
        await viewModel.runCommand(id: UUID(), command: "ls")
        #expect(viewModel.consoleEntries.isEmpty)
        #expect(viewModel.consoleRunning.isEmpty)
    }

    @Test
    func removeServerClearsAllPerServerState() async throws {
        let backend = ServerBackend(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("server-manager-vm-\(UUID().uuidString)", isDirectory: true),
            runner: { _, _ in "ok" }
        )
        let viewModel = ServerManagerViewModel(backend: backend)
        try await viewModel.addServer(name: "web", host: "10.0.0.1", port: 22, user: "root", group: "")
        let id = try #require(viewModel.selectedID)
        await viewModel.runCommand(id: id, command: "ls")
        #expect(viewModel.consoleEntries[id]?.count == 1)
        try await viewModel.removeServer(id: id)
        #expect(viewModel.consoleEntries[id] == nil)
        #expect(viewModel.metricsStates[id] == nil)
        #expect(viewModel.probeStates[id] == nil)
        #expect(viewModel.servers.isEmpty)
    }

    @Test
    func staleLoadDoesNotOverwriteNewerResult() async throws {
        let gate = SSHGate()
        let backend = ServerBackend(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("server-manager-stale-\(UUID().uuidString)", isDirectory: true),
            runner: { _, _ in try await gate.wait() }
        )
        let viewModel = ServerManagerViewModel(backend: backend)
        try await viewModel.addServer(name: "web", host: "10.0.0.1", port: 22, user: "root", group: "")
        let id = try #require(viewModel.selectedID)

        // 第一轮加载先挂起在 SSH 门闩上。
        let first = Task { await viewModel.loadMetrics(id: id) }
        while await gate.pendingCount < 1 { await Task.yield() }
        // 第二轮加载随后挂起；此时代次已前进。
        let second = Task { await viewModel.loadMetrics(id: id) }
        while await gate.pendingCount < 2 { await Task.yield() }

        // 新请求先返回，旧请求晚到 —— 旧结果必须被丢弃。
        await gate.resume(at: 1, with: "===HOST===\nnew-host\n===END===")
        await second.value
        await gate.resume(at: 0, with: "===HOST===\nold-host\n===END===")
        await first.value

        guard case .loaded(let metrics) = viewModel.metricsStates[id] else {
            Issue.record("expected loaded state")
            return
        }
        #expect(metrics.hostname == "new-host")
    }
}

/// 测试用 SSH 门闩：按索引精确恢复挂起的请求，构造「旧请求晚到」。
private actor SSHGate {
    private var waiters: [CheckedContinuation<String, Error>] = []

    var pendingCount: Int { waiters.count }

    func wait() async throws -> String {
        try await withCheckedThrowingContinuation { waiters.append($0) }
    }

    func resume(at index: Int, with value: String) {
        guard waiters.indices.contains(index) else { return }
        let continuation = waiters.remove(at: index)
        continuation.resume(returning: value)
    }
}