import Testing
import Foundation
import KitAgentTool
@testable import PluginDiskManager

/// Deterministic tests for the Disk Manager agent-tool support helpers.
@Suite struct DiskManagerToolSupportTests {

    @Test func formatBytesProducesHumanReadableString() {
        let result = DiskManagerToolSupport.formatBytes(1_500_000) // ~1.5 MB
        #expect(result.contains("MB") || result.contains("KB"))
    }

    @Test func formatBytesHandlesZero() {
        #expect(DiskManagerToolSupport.formatBytes(0).isEmpty == false)
    }

    @Test func formatDateReturnsUnknownForNil() {
        #expect(DiskManagerToolSupport.formatDate(nil) == "unknown")
    }

    @Test func formatDateProducesISO8601ForConcreteDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = DiskManagerToolSupport.formatDate(date)
        // ISO8601DateFormatter with .withFullDate yields a YYYY-MM-DD string.
        #expect(result.count >= 10)
        #expect(result.first == "2")
    }

    @Test func resolveScanPathFallsBackToHomeWhenEmpty() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath(nil) == home)
        #expect(DiskManagerToolSupport.resolveScanPath("") == home)
        #expect(DiskManagerToolSupport.resolveScanPath("   ") == home)
    }

    @Test func resolveScanPathExpandsTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath("~") == home)
        #expect(DiskManagerToolSupport.resolveScanPath("~/Downloads") == "\(home)/Downloads")
    }

    @Test func resolveScanPathAnchorsRelativePathsToHome() {
        let home = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
        let documents = home.appendingPathComponent("Documents").path

        #expect(DiskManagerToolSupport.resolveScanPath("Documents") == documents)
        #expect(DiskManagerToolSupport.resolveScanPath("  Documents  ") == documents)
        #expect(
            DiskManagerToolSupport.resolveScanPath("Documents/Invoices")
                == home.appendingPathComponent("Documents").appendingPathComponent("Invoices").path
        )
        // 绝对路径保持原样。
        #expect(DiskManagerToolSupport.resolveScanPath("/tmp") == "/tmp")
    }

    @Test func pathsPreserveOriginalStringsAndDropBlankEntries() {
        let arguments = ["paths": ToolArgument(["/tmp/a ", "   ", "/tmp/b"])]

        // 末尾空格属于路径本身，必须原样保留；纯空白条目仍应被剔除。
        #expect(DiskManagerToolSupport.paths(arguments, "paths") == ["/tmp/a ", "/tmp/b"])
        #expect(DiskManagerToolSupport.paths([:], "paths") == nil)
    }
}

@Suite(.serialized)
struct DirectoryTreeServiceTests {

    @Test func topLevelScanAggregatesNestedUsageWithoutMaterializingTree() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = root.appendingPathComponent("Applications/Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 11).write(to: nested.appendingPathComponent("one.bin"))
        try Data(repeating: 2, count: 23).write(to: root.appendingPathComponent("Downloads.bin"))
        try Data(repeating: 3, count: 7).write(to: root.appendingPathComponent("root.bin"))

        let progress = ProgressRecorder()
        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
            atPath: root.path,
            maxDuration: 10,
            onProgress: { value in await progress.record(value) }
        )

        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
        #expect(byName["Applications"]?.isDirectory == true)
        #expect(byName["Applications"]?.size == 11)
        #expect(byName["Downloads.bin"]?.size == 23)
        #expect(byName["root.bin"]?.size == 7)
        #expect(await progress.count >= 2)
    }

    @Test func topLevelScanStopsAtEntryBudget() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 1, count: 1).write(to: root.appendingPathComponent("file-a.bin"))
        try Data(repeating: 2, count: 1).write(to: root.appendingPathComponent("file-b.bin"))

        do {
            _ = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
                atPath: root.path,
                maxEntries: 1,
                maxDuration: 10
            )
            Issue.record("Expected the scan to stop at the configured entry budget")
        } catch let error as DirectoryTreeScanError {
            guard case .budgetExceeded = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
        }
    }

    @Test func missingScanRootThrowsRootUnavailable() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tree-\(UUID().uuidString)", isDirectory: true)

        do {
            _ = try await DirectoryTreeService().scanTopLevelDirectoryUsage(atPath: missing.path)
            Issue.record("Expected a missing scan root to throw")
        } catch let error as DiskManagerScanError {
            guard case .rootUnavailable(_, let reason) = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
            #expect(reason == "the path does not exist")
            #expect(error.localizedDescription.contains(missing.lastPathComponent))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func emptyScanRootReturnsEmptyResult() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(atPath: root.path)
        #expect(entries.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-directory-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("并行扫描互不取消：后启动的扫描不得终止先启动的扫描（#226）")
    func parallelScansDoNotCancelEachOther() async throws {
        let service = DirectoryTreeService()
        let gate = ProgressGate()
        let rootA = try makeTemporaryDirectory()
        let rootB = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootA)
            try? FileManager.default.removeItem(at: rootB)
        }

        // 扫描 A 在首次进度发布处被门闩停住，确定性地处于进行中。
        let scanA = Task {
            try await service.scanTopLevelDirectoryUsage(
                atPath: rootA.path,
                onProgress: { _ in await gate.waitOnce() }
            )
        }
        let deadline = Date().addingTimeInterval(5)
        while await !gate.isBlocked, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(await gate.isBlocked, "扫描 A 应已进入首次进度回调并被门闩停住")

        // 后启动的扫描 B 完整跑完；旧实现在这里取消 A 的令牌。
        let entriesB = try await service.scanTopLevelDirectoryUsage(atPath: rootB.path)

        // 放行 A：A 必须正常完成，而不是被误报为用户取消。
        await gate.releaseAll()
        let entriesA = try await scanA.value

        #expect(entriesB.isEmpty)
        #expect(entriesA.isEmpty)
    }

    @Test("cancelScan 终止当前所有扫描")
    func cancelScanStopsAllActiveScans() async throws {
        let service = DirectoryTreeService()
        let gate = ProgressGate(blockingBudget: 2)
        let rootA = try makeTemporaryDirectory()
        let rootB = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootA)
            try? FileManager.default.removeItem(at: rootB)
        }

        let scanA = Task {
            try await service.scanTopLevelDirectoryUsage(
                atPath: rootA.path,
                onProgress: { _ in await gate.waitOnce() }
            )
        }
        let deadline = Date().addingTimeInterval(5)
        while await !gate.isBlocked, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(await gate.isBlocked)

        let scanB = Task {
            try await service.scanTopLevelDirectoryUsage(
                atPath: rootB.path,
                onProgress: { _ in await gate.waitOnce() }
            )
        }
        let deadlineB = Date().addingTimeInterval(5)
        while await !(gate.blockedCount >= 2), Date() < deadlineB {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(await gate.blockedCount >= 2, "两个扫描都应被门闩停住")

        await service.cancelScan()

        // 放行门闩后，两个扫描都应收到取消（用户显式停止 = 停止全部）。
        await gate.releaseAll()
        do {
            _ = try await scanA.value
            Issue.record("扫描 A 应被 cancelScan 终止")
        } catch is CancellationError {
            // 预期
        }
        do {
            _ = try await scanB.value
            Issue.record("扫描 B 应被 cancelScan 终止")
        } catch is CancellationError {
            // 预期
        }
    }
}

private actor ProgressRecorder {
    private(set) var values: [ScanProgress] = []

    func record(_ value: ScanProgress) {
        values.append(value)
    }

    var count: Int { values.count }
}

/// 进度门闩：把前 `blockingBudget` 次进度回调挂起，直到 `releaseAll`；
/// 之后的调用直接放行。用于把扫描确定性地停在进行中状态。
private actor ProgressGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var blockingBudget: Int
    private var armedCalls = 0

    /// 该门闩是否已挂起过调用（用于等待扫描进入回调）。
    var isBlocked: Bool { !waiters.isEmpty }

    var blockedCount: Int { waiters.count }

    init(blockingBudget: Int = 1) {
        self.blockingBudget = blockingBudget
    }

    func waitOnce() async {
        guard armedCalls < blockingBudget else { return }
        armedCalls += 1
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseAll() {
        for continuation in waiters {
            continuation.resume()
        }
        waiters.removeAll()
    }
}

@Suite(.serialized)
struct LargeFilesServiceTests {

    @Test func largeFileScanThrowsForMissingRoot() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-large-files-\(UUID().uuidString)", isDirectory: true)

        do {
            _ = try await LargeFilesService.shared.scanLargeFiles(atPath: missing.path)
            Issue.record("Expected a missing scan root to throw")
        } catch let error as DiskManagerScanError {
            guard case .rootUnavailable(_, let reason) = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
            #expect(reason == "the path does not exist")
            #expect(error.localizedDescription.contains(missing.lastPathComponent))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func largeFileScanReturnsEmptyForExistingEmptyRoot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-empty-large-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let files = try await LargeFilesService.shared.scanLargeFiles(atPath: root.path)
        #expect(files.isEmpty)
    }
}

@MainActor
@Suite struct DiskManagerAgentToolsTests {

    private var toolNames: Set<String> {
        Set(DiskManagerPlugin.agentTools.map { $0.name })
    }

    @Test func pluginRegistersAllDiskManagerTools() {
        let expected: Set<String> = [
            "disk-manager.disk-usage",
            "disk-manager.scan-large-files",
            "disk-manager.scan-directory-tree",
            "disk-manager.scan-caches",
            "disk-manager.clean-caches",
            "disk-manager.scan-xcode-caches",
            "disk-manager.clean-xcode-caches",
            "disk-manager.scan-projects",
            "disk-manager.clean-projects",
            "disk-manager.delete-files",
        ]
        #expect(toolNames == expected)
    }

    @Test func destructiveToolsAreHighRisk() {
        let destructiveIDs: Set<String> = [
            "disk-manager.clean-caches",
            "disk-manager.clean-xcode-caches",
            "disk-manager.clean-projects",
            "disk-manager.delete-files",
        ]
        for tool in DiskManagerPlugin.agentTools where destructiveIDs.contains(tool.name) {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .high)
        }
    }

    @Test func readToolsAreLowRisk() {
        let readIDs: Set<String> = [
            "disk-manager.disk-usage",
            "disk-manager.scan-large-files",
            "disk-manager.scan-directory-tree",
            "disk-manager.scan-caches",
            "disk-manager.scan-xcode-caches",
            "disk-manager.scan-projects",
        ]
        for tool in DiskManagerPlugin.agentTools where readIDs.contains(tool.name) {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }

    @Test func destructiveToolsProvideDisplayDescriptions() {
        let paths = ["paths": ToolArgument(["/tmp/a", "/tmp/b"])]
        for tool in DiskManagerPlugin.agentTools where tool.name == "disk-manager.delete-files" {
            let description = tool.displayDescription(for: paths)
            #expect(description.contains("2"))
        }
    }

    @Test func scanLargeFilesToolReportsMissingRootAsFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tool-large-\(UUID().uuidString)", isDirectory: true)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ScanLargeFilesTool().executeResult(arguments: ["path": ToolArgument(missing.path)])
        }
    }

    @Test func scanDirectoryTreeToolReportsMissingRootAsFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tool-tree-\(UUID().uuidString)", isDirectory: true)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ScanDirectoryTreeTool().executeResult(arguments: ["path": ToolArgument(missing.path)])
        }
    }

    // MARK: - 回归 #740：删除失败必须抛出错误，不能当作成功 Job

    @Test func cleanToolsThrowWhenDeletionFails() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-clean-\(UUID().uuidString)", isDirectory: true)
        let tools: [any SuperAgentTool] = [
            CleanCachesTool(),
            CleanXcodeCachesTool(),
            CleanProjectsTool(),
        ]

        for tool in tools {
            await #expect(throws: ToolExecutionError.self) {
                _ = try await tool.executeResult(
                    arguments: ["paths": ToolArgument([missing.path])]
                )
            }
        }
    }

    // MARK: - 回归 #738：路径末尾空白不得被裁剪

    @Test func cleanCachesToolDeletesExactPathWithTrailingWhitespace() async throws {
        let fixture = try makeTrailingWhitespaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try await CleanCachesTool().execute(
            arguments: ["paths": ToolArgument([fixture.spacedPath])]
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.spacedPath))
        #expect(FileManager.default.fileExists(atPath: fixture.unspacedPath))
    }

    // MARK: - 回归 #870：普通文件根路径必须报告真实释放字节

    @Test func cleanCachesToolReportsActualSizeForRegularFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-regular-file-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("plain-cache.bin")
        let byteCount = 8_192
        try Data(repeating: 0, count: byteCount).write(to: fileURL)

        let measured = await DiskManagerToolSupport.sizeOfPath(fileURL.path)
        #expect(measured == Int64(byteCount))

        let output = try await CleanCachesTool().execute(
            arguments: ["paths": ToolArgument([fileURL.path])]
        )
        #expect(output.contains(DiskManagerToolSupport.formatBytes(Int64(byteCount))))
        #expect(!output.contains(DiskManagerToolSupport.formatBytes(0)))
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - 回归 #871：删除大文件后通知侧栏容量与环形图刷新

    @Test func deletingLargeFilePostsDiskUsageChangeNotification() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-large-file-delete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("big.bin")
        try Data(repeating: 0, count: 1_024).write(to: fileURL)

        try await confirmation("disk usage change notification") { confirm in
            let token = NotificationCenter.default.addObserver(
                forName: .diskManagerDiskUsageDidChange,
                object: nil,
                queue: nil
            ) { _ in confirm() }
            defer { NotificationCenter.default.removeObserver(token) }

            try await LargeFilesService.shared.deleteFile(atPath: fileURL.path)
        }

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func cleanXcodeCachesToolDeletesExactPathWithTrailingWhitespace() async throws {
        let fixture = try makeTrailingWhitespaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try await CleanXcodeCachesTool().execute(
            arguments: ["paths": ToolArgument([fixture.spacedPath])]
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.spacedPath))
        #expect(FileManager.default.fileExists(atPath: fixture.unspacedPath))
    }

    @Test func cleanProjectsToolDeletesExactPathWithTrailingWhitespace() async throws {
        let fixture = try makeTrailingWhitespaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try await CleanProjectsTool().execute(
            arguments: ["paths": ToolArgument([fixture.spacedPath])]
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.spacedPath))
        #expect(FileManager.default.fileExists(atPath: fixture.unspacedPath))
    }

    @Test func deleteFilesToolDeletesExactPathWithTrailingWhitespace() async throws {
        let fixture = try makeTrailingWhitespaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try await DeleteFilesTool().execute(
            arguments: ["paths": ToolArgument([fixture.spacedPath])]
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.spacedPath))
        #expect(FileManager.default.fileExists(atPath: fixture.unspacedPath))
    }

    /// 造一对只差末尾空格的兄弟目录，用来验证删除工具不会「裁剪到另一个目录」。
    private func makeTrailingWhitespaceFixture() throws
        -> (root: URL, spacedPath: String, unspacedPath: String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-path-whitespace-\(UUID().uuidString)", isDirectory: true)
        let spaced = root.appendingPathComponent("lumi-target ", isDirectory: true)
        let unspaced = root.appendingPathComponent("lumi-target", isDirectory: true)
        try FileManager.default.createDirectory(at: spaced, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unspaced, withIntermediateDirectories: true)
        return (root, spaced.path, unspaced.path)
    }
}
