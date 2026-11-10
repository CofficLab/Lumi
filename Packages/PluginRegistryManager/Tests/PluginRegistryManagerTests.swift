import Foundation
import Testing
@testable import RegistryManagerPlugin

@MainActor
@Test func v2PluginMetadataIsStable() {
    let plugin = RegistryManagerPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.registry-manager")
    #expect(plugin.metadata.name == "Registry Manager")
    #expect(plugin.metadata.policy == .disabled)
}

@MainActor
@Test
func staleRefreshDoesNotOverwriteNewerRegistryResult() async throws {
    let service = FakeRegistryManagerService(
        getResults: [
            .npm: [
                (delay: 200_000_000, result: "https://stale.example/"),
                (delay: 20_000_000, result: "https://fresh.example/"),
            ]
        ]
    )
    let viewModel = RegistryManagerViewModel(service: service, autoRefresh: false)

    let firstRefresh = Task {
        await viewModel.refresh(.npm)
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    await viewModel.refresh(.npm)
    await firstRefresh.value

    #expect(viewModel.registries[.npm] == "https://fresh.example/")
    #expect(viewModel.isLoading[.npm] == false)
}

@MainActor
@Test
func staleSetDoesNotOverwriteNewerRegistryChoice() async throws {
    let staleSource = RegistrySource(name: "Stale", url: "https://stale.example/", type: .npm)
    let freshSource = RegistrySource(name: "Fresh", url: "https://fresh.example/", type: .npm)
    let service = FakeRegistryManagerService(setDelays: [
        staleSource.url: 200_000_000,
        freshSource.url: 20_000_000,
    ])
    let viewModel = RegistryManagerViewModel(service: service, autoRefresh: false)

    let firstSet = Task {
        await viewModel.setRegistry(.npm, source: staleSource)
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    await viewModel.setRegistry(.npm, source: freshSource)
    await firstSet.value

    #expect(viewModel.registries[.npm] == freshSource.url)
    #expect(viewModel.isLoading[.npm] == false)
    #expect(viewModel.toastMessage.contains("Fresh"))
    let appliedURLs = await service.appliedURLs
    #expect(appliedURLs == [staleSource.url, freshSource.url])
}

private actor FakeRegistryManagerService: RegistryManagerServicing {
    private var getResults: [RegistryType: [(delay: UInt64, result: String)]]
    private let setDelays: [String: UInt64]
    private var appliedSetURLs: [String] = []

    var appliedURLs: [String] {
        appliedSetURLs
    }

    init(
        getResults: [RegistryType: [(delay: UInt64, result: String)]] = [:],
        setDelays: [String: UInt64] = [:]
    ) {
        self.getResults = getResults
        self.setDelays = setDelays
    }

    func getCurrentRegistry(for type: RegistryType) async throws -> String {
        let next = nextGetResult(for: type)
        try? await Task.sleep(nanoseconds: next.delay)
        return next.result
    }

    func setRegistry(for type: RegistryType, url: String) async throws {
        if let delay = setDelays[url] {
            try? await Task.sleep(nanoseconds: delay)
        }
        appliedSetURLs.append(url)
    }

    private func nextGetResult(for type: RegistryType) -> (delay: UInt64, result: String) {
        var queue = getResults[type] ?? []
        guard !queue.isEmpty else {
            return (0, "Default")
        }
        let next = queue.removeFirst()
        getResults[type] = queue
        return next
    }
}

// MARK: - Docker daemon.json 合并（回归 #736）

@Test("现有 daemon.json 的关键配置在切换镜像源后保留")
func dockerDaemonMergePreservesExistingKeys() throws {
    let existing = Data(#"{"debug": true, "storage-driver": "overlay2", "registry-mirrors": ["https://old.example/"]}"#.utf8)

    let merged = try DockerDaemonConfig.mergedData(existing: existing, mirrorURL: "https://new.example/")
    let json = try #require(try JSONSerialization.jsonObject(with: merged) as? [String: Any])

    #expect(json["debug"] as? Bool == true)
    #expect(json["storage-driver"] as? String == "overlay2")
    #expect(json["registry-mirrors"] as? [String] == ["https://new.example/"])
}

@Test("daemon.json 无法解析时中止并抛错，绝不返回可写数据")
func dockerDaemonMergeRejectsUnparsableConfig() throws {
    // 未闭合的对象：任何标准 JSON 解析器都读不出来（与用户手写注释/尾逗号同类）。
    let broken = Data(#"{"debug": true, "registry-mirrors": ["https://old.example/"]"#.utf8)

    do {
        _ = try DockerDaemonConfig.mergedData(existing: broken, mirrorURL: "https://new.example/")
        Issue.record("解析失败时不应返回新配置")
    } catch let error as RegistryServiceError {
        #expect(error.errorDescription?.contains("daemon.json") == true)
    }
}

@Test("daemon.json 根节点不是对象时同样中止")
func dockerDaemonMergeRejectsNonObjectRoot() {
    #expect(throws: RegistryServiceError.self) {
        try DockerDaemonConfig.mergedData(existing: Data("[]".utf8), mirrorURL: "https://new.example/")
    }
}

@Test("daemon.json 不存在时只写入镜像源")
func dockerDaemonMergeCreatesConfigWhenMissing() throws {
    let merged = try DockerDaemonConfig.mergedData(existing: nil, mirrorURL: "https://new.example/")
    let json = try #require(try JSONSerialization.jsonObject(with: merged) as? [String: Any])

    #expect(json.count == 1)
    #expect(json["registry-mirrors"] as? [String] == ["https://new.example/"])
}

// MARK: - 命令退出状态（回归 #660）

@Test("命令非零退出时即使有 stdout 也抛错")
func executeThrowsOnNonZeroExitEvenWithStdout() async {
    do {
        _ = try await RegistryService.shared.execute("printf 'startup-noise\\n'; exit 7")
        Issue.record("非零退出应当抛错")
    } catch let error as RegistryServiceError {
        guard case .commandFailed(let command, let status, let output) = error else {
            Issue.record("意外的错误类型: \(error)")
            return
        }
        #expect(status == 7)
        #expect(command.contains("exit 7"))
        #expect(output.contains("startup-noise"))
    } catch {
        Issue.record("意外的错误: \(error)")
    }
}

@Test("命令成功时返回 stdout")
func executeReturnsStdoutOnSuccess() async throws {
    let output = try await RegistryService.shared.execute("printf 'https://registry.example/\\n'")

    #expect(output.contains("https://registry.example/"))
}

@Test("profile 启动噪音不会被当成 registry 值")
func configValueKeepsOnlyTheLastLine() {
    #expect(RegistryService.configValue("startup-noise\n\nhttps://registry.example/  \n") == "https://registry.example/")
    #expect(RegistryService.configValue("   \n  ") == "")
}

// MARK: - Pip 入口探测（回归 #662）

@Test("只装了 pip3 时改用 pip3，而不是报告未安装")
func pipCommandFallsBackToPip3WhenPipIsMissing() {
    #expect(PipCommand.firstAvailable(among: ["pip3", "python3 -m pip"]) == "pip3")
    #expect(PipCommand.firstAvailable(among: ["pip", "pip3"]) == "pip")
}

@Test("所有 Pip 入口都不可用时才返回 nil，模块入口用 --version 探测")
func pipCommandReturnsNilOnlyWhenEveryEntryIsUnavailable() {
    #expect(PipCommand.probeCommand(for: "python3 -m pip") == "python3 -m pip --version")
    #expect(PipCommand.probeCommand(for: "pip3") == "command -v pip3")

    #expect(PipCommand.firstAvailable(among: []) == nil)
}
