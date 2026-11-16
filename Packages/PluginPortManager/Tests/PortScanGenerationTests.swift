import Foundation
import Testing

@testable import PortManagerPlugin

/// 端口扫描的**回合身份隔离**回归测试（#247）。
///
/// ## 复现的缺陷
///
/// 原 `PortManagerView.refresh()` 在 `await PortScanner.shared.scanPorts()`
/// 之后无条件写 `ports`，`defer` 无条件清 `isLoading`；kill 成功后等 500ms
/// 再刷新，期间不作废仍在途的 kill 前扫描。旧扫描晚到时：
///
/// - 旧快照覆盖 kill 后的新列表，被杀进程「复活」；
/// - 旧请求的收尾把仍在加载的新请求的 loading 清掉；
/// - 旧扫描失败还会把新结果清空并弹错误。
///
/// 修复：刷新/kill 编排移入 `PortManagerViewModel`，每次 refresh 递增
/// `scanGeneration` 并在写回前比对；kill 成功立即递增代次作废在途旧扫描。
///
/// ## 观测手段
///
/// 经 `PortScanning` 注入门闩 stub：每次 scanPorts 停在 continuation，
/// 测试显式控制各回合的完成顺序，构造确定性的「旧请求晚到」。
@Suite("PortManager 扫描回合身份隔离")
@MainActor
struct PortScanGenerationTests {

    // MARK: - kill 后晚到的旧扫描不得让被杀进程复活

    @Test("kill 成功后在途旧扫描被作废，晚到快照不得复活被杀进程或清 loading（回归 #247）")
    func latePreKillScanDoesNotResurrectKilledProcess() async throws {
        let stub = StubPortScanner()
        let viewModel = PortManagerViewModel(scanner: stub)
        let killedPort = makePort(pid: "12345", port: "3000")
        let postKillPorts = [makePort(pid: "23456", port: "8080")]

        let refreshTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 1 }

        let killTask = Task { await viewModel.killProcess(killedPort) }
        await waitUntil { stub.killCalls.count == 1 }
        await settle() // kill 已返回，代次已作废，kill 任务进入 500ms 等待

        // 旧扫描（kill 前快照）在 post-kill 刷新开始之前晚到。
        stub.completeScan(1, ports: [killedPort])
        await refreshTask.value
        await settle()
        #expect(viewModel.ports.isEmpty, "kill 已作废在途旧扫描，旧快照不得写入列表")
        #expect(viewModel.isLoading, "旧回合不得替新回合清掉 loading")

        // 500ms 后的 post-kill 刷新开始并完成。
        await waitUntil(timeout: .seconds(5)) { stub.scanCallCount == 2 }
        stub.completeScan(2, ports: postKillPorts)
        await killTask.value
        await waitUntil { !viewModel.isLoading }
        #expect(viewModel.ports == postKillPorts)
        #expect(!viewModel.showError)
    }

    // MARK: - 晚到的旧扫描失败不得清空新结果

    @Test("旧扫描晚到失败不得清空新回合结果或弹错误（回归 #247）")
    func staleScanFailureDoesNotClearNewerResults() async throws {
        let stub = StubPortScanner()
        let viewModel = PortManagerViewModel(scanner: stub)
        let newPorts = [makePort(pid: "23456", port: "8080")]

        let oldTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 1 }
        let newTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 2 }

        stub.completeScan(2, ports: newPorts)
        await newTask.value
        await waitUntil { !viewModel.isLoading }

        stub.failScan(1, error: PortScannerError.scanFailed("stale lsof failure"))
        await oldTask.value
        await settle()

        #expect(viewModel.ports == newPorts, "旧回合失败不得清空新回合的列表")
        #expect(!viewModel.showError, "旧回合失败不得对新上下文弹错误")
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    // MARK: - 晚到的旧扫描成功不得覆盖/提前收尾新回合

    @Test("新扫描仍在途时旧扫描晚到成功不得写列表或清 loading（回归 #247）")
    func staleScanCompletionDoesNotClearLoadingOfNewerScan() async throws {
        let stub = StubPortScanner()
        let viewModel = PortManagerViewModel(scanner: stub)
        let oldPorts = [makePort(pid: "12345", port: "3000")]
        let newPorts = [makePort(pid: "23456", port: "8080")]

        let oldTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 1 }
        let newTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 2 }

        stub.completeScan(1, ports: oldPorts)
        await oldTask.value
        await settle()
        #expect(viewModel.ports.isEmpty, "旧快照不得覆盖仍在加载的新回合")
        #expect(viewModel.isLoading, "旧回合的收尾不得清掉新回合的 loading")

        stub.completeScan(2, ports: newPorts)
        await newTask.value
        #expect(viewModel.ports == newPorts)
        #expect(!viewModel.isLoading)
    }

    // MARK: - kill 被拒绝仍报错并刷新（保留 #246 行为）

    @Test("kill 被拒绝时报错并刷新列表，刷新结果正常落地（回归 #246/#247）")
    func killFailureStillReportsErrorAndRefreshes() async throws {
        let stub = StubPortScanner()
        stub.killError = PortScannerError.killTargetExited
        let viewModel = PortManagerViewModel(scanner: stub)
        let port = makePort(pid: "12345", port: "3000")

        let refreshTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 1 }
        stub.completeScan(1, ports: [port])
        await refreshTask.value

        let killTask = Task { await viewModel.killProcess(port) }
        await waitUntil { stub.scanCallCount == 2 }
        // 拒绝后的刷新仍在途：错误必须已经报出（刷新成功会按既有语义收起弹窗）。
        #expect(viewModel.showError, "kill 被拒绝必须向用户报错")
        #expect(viewModel.errorMessage?.isEmpty == false)
        stub.completeScan(2, ports: [])
        await killTask.value
        await waitUntil { !viewModel.isLoading }

        #expect(viewModel.ports.isEmpty, "拒绝后的刷新必须正常落地")
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    // MARK: - 晚到的 kill 失败不得污染已刷新的新上下文

    @Test("kill 挂起期间列表已刷新，晚到的 kill 失败不得再写错误状态（回归 #247）")
    func lateKillErrorDoesNotPolluteAfterNewerRefresh() async throws {
        let stub = StubPortScanner()
        let viewModel = PortManagerViewModel(scanner: stub)
        let port = makePort(pid: "12345", port: "3000")
        let newPorts = [makePort(pid: "23456", port: "8080")]

        let firstTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 1 }
        stub.completeScan(1, ports: [port])
        await firstTask.value

        stub.holdKill = true
        let killTask = Task { await viewModel.killProcess(port) }
        await waitUntil { stub.isWaitingAtKill }

        // kill 仍挂起时用户手动刷新，列表进入新回合。
        let refreshTask = Task { await viewModel.refresh() }
        await waitUntil { stub.scanCallCount == 2 }
        stub.completeScan(2, ports: newPorts)
        await refreshTask.value
        await waitUntil { !viewModel.isLoading }

        stub.releaseKill(error: PortScannerError.killTargetExited)
        // 拒绝分支仍会刷新列表（#246），但错误文案不得写入新上下文。
        await waitUntil { stub.scanCallCount == 3 }
        stub.completeScan(3, ports: newPorts)
        await killTask.value
        await waitUntil { !viewModel.isLoading }

        #expect(viewModel.errorMessage == nil, "旧回合的 kill 失败不得污染已刷新的上下文")
        #expect(!viewModel.showError)
        #expect(viewModel.ports == newPorts)
    }
}

// MARK: - 门闩 stub

/// 每次 `scanPorts` 停在 continuation，由测试显式决定各回合的完成顺序；
/// kill 可配置为立即成功/失败，或挂起等待放行。
@MainActor
private final class StubPortScanner: PortScanning {
    private var scanGates: [Int: CheckedContinuation<[PortInfo], Error>] = [:]
    private(set) var scanCallCount = 0
    private(set) var killCalls: [PortInfo] = []
    var killError: Error?
    var holdKill = false
    private var killGate: CheckedContinuation<Void, Error>?
    private(set) var isWaitingAtKill = false

    func scanPorts() async throws -> [PortInfo] {
        scanCallCount += 1
        let call = scanCallCount
        return try await withCheckedThrowingContinuation { continuation in
            scanGates[call] = continuation
        }
    }

    func completeScan(_ call: Int, ports: [PortInfo]) {
        scanGates.removeValue(forKey: call)?.resume(returning: ports)
    }

    func failScan(_ call: Int, error: Error) {
        scanGates.removeValue(forKey: call)?.resume(throwing: error)
    }

    func killProcess(_ port: PortInfo) async throws {
        killCalls.append(port)
        if holdKill {
            holdKill = false
            try await withCheckedThrowingContinuation { continuation in
                isWaitingAtKill = true
                killGate = continuation
            }
            return
        }
        if let killError {
            throw killError
        }
    }

    func releaseKill(error: Error? = nil) {
        isWaitingAtKill = false
        if let error {
            killGate?.resume(throwing: error)
        } else {
            killGate?.resume()
        }
        killGate = nil
    }
}

// MARK: - 辅助

private func makePort(pid: String, port: String) -> PortInfo {
    PortInfo(
        command: "node",
        pid: pid,
        user: "user",
        protocolName: "TCP",
        port: port,
        address: "*:\(port)"
    )
}

@MainActor
private func settle(_ iterations: Int = 24) async {
    for _ in 0..<iterations {
        await Task.yield()
    }
}

@MainActor
private func waitUntil(timeout: Duration = .seconds(3), _ condition: () async -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !(await condition()) {
        if ContinuousClock.now >= deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        await Task.yield()
    }
}