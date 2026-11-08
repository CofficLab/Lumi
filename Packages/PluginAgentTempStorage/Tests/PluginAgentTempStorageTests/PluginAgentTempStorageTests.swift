import KitAgentTool
import Testing
import Foundation
@testable import PluginAgentTempStorage

@MainActor
struct PluginAgentTempStorageTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = AgentTempStoragePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.agent-temp-storage")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 80)
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    @Test
    func pluginRegistersThreeTools() {
        let names = AgentTempStoragePlugin.agentTools.map(\.name)
        #expect(names == ["list_temp_files", "read_temp_file", "write_temp_file"])
    }

    @Test
    func toolsAreLowRisk() {
        for tool in AgentTempStoragePlugin.agentTools {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        // `.xcstrings` 是**源**目录里的文件；SPM 打包时会被编译成各语言的
        // `Localizable.strings`（`<lang>.lproj/Localizable.strings`），
        // 原始 `.xcstrings` 不会进 bundle。只查 `.xcstrings` 恒为 nil。
        let hasCatalog = bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
        #expect(pluginLocalization.string("Agent Temp Storage").isEmpty == false)
    }

    @Test
    func storageSupportsNestedReadWriteAndList() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        let path = try await service.write(filename: "notes/today.md", content: "# today")
        #expect(path.hasSuffix("notes/today.md"))
        #expect(try await service.read(filename: "notes/today.md") == "# today")

        // 列表必须递归：嵌套文件要能以相对路径出现，否则可读写却不可见。
        let listed = try await service.listFiles()
        #expect(listed.map(\.name) == ["notes/today.md"])
        #expect(listed.first?.path.hasSuffix("notes/today.md") == true)
    }

    @Test
    func preservesLeadingAndTrailingSpacesInFilenames() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        let plain = try await service.write(filename: "report.md", content: "first")
        let spaced = try await service.write(filename: " report.md ", content: "second")

        // 两个合法名称必须落到不同文件，不能因裁剪而互相覆盖。
        #expect(plain != spaced)
        #expect(spaced.hasSuffix("/ report.md "))
        #expect(try await service.read(filename: "report.md") == "first")
        #expect(try await service.read(filename: " report.md ") == "second")
        #expect(try await service.listFiles().map(\.name).sorted() == [" report.md ", "report.md"])
    }

    @Test
    func storageRejectsInvalidAndTraversingPaths() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "", content: "x")
        }
        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "   ", content: "x")
        }
        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "/absolute.md", content: "x")
        }
        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.write(filename: "../escape.md", content: "x")
        }
    }

    @Test
    func readReportsMissingFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        await #expect(throws: TempFileStorageError.fileNotFound("nope.md")) {
            _ = try await service.read(filename: "nope.md")
        }
    }

    @Test
    func listFilesSortsByRecencyAndExcludesDirectories() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        _ = try await service.write(filename: "zebra.md", content: "z")
        _ = try await service.write(filename: "alpha.md", content: "a")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60)],
            ofItemAtPath: root.appendingPathComponent("alpha.md").path
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("afolder"),
            withIntermediateDirectories: false
        )

        let listed = try await service.listFiles()
        #expect(listed.map(\.name) == ["zebra.md", "alpha.md"])
        #expect(listed.allSatisfy { !$0.name.contains("afolder") })
    }

    @Test
    func purgeRemovesOnlyFilesOlderThanRetention() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        _ = try await service.write(filename: "old.md", content: "old")
        _ = try await service.write(filename: "fresh.md", content: "fresh")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)],
            ofItemAtPath: root.appendingPathComponent("old.md").path
        )

        try await service.purgeExpiredFiles()
        let remaining = try await service.listFiles()
        #expect(remaining.map(\.name) == ["fresh.md"])
    }

    @Test
    func unreadableSettingsAbortPurgeAndSurfaceError() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = root.appendingPathComponent("files", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)

        let store = AgentTempStoragePluginLocalStore(settingsDirectory: root)
        store.retentionDays = 14
        #expect(try store.resolvedRetentionDays() == 14)

        let keep = files.appendingPathComponent("report.md")
        try "keep".write(to: keep, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)],
            ofItemAtPath: keep.path
        )

        // 已有配置在保存成功后才损坏：不能把读取故障当成「未配置」。
        try Data("not a plist".utf8).write(to: root.appendingPathComponent("settings.plist"))

        let service = TempFileStorageService(
            directory: files,
            retentionDaysProvider: { try store.resolvedRetentionDays() }
        )

        await #expect {
            _ = try await service.read(filename: "report.md")
        } throws: { error in
            guard case .settingsUnavailable = error as? TempFileStorageError else { return false }
            return true
        }

        // 按 14 天策略仍然有效的 8 天文件必须保留。
        #expect(FileManager.default.fileExists(atPath: keep.path))
        #expect(try String(contentsOf: keep, encoding: .utf8) == "keep")

        // 配置确实不存在时才允许回退默认值。
        try FileManager.default.removeItem(at: root.appendingPathComponent("settings.plist"))
        #expect(try store.resolvedRetentionDays() == 7)
    }

    @Test
    func readFailsWhenExpiredFileCannotBeDeleted() async throws {
        let root = try makeTemporaryDirectory()
        defer {
            // 恢复写权限后才能清理隔离目录。
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        let expired = root.appendingPathComponent("old.md")
        try "old".write(to: expired, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)],
            ofItemAtPath: expired.path
        )

        // 父目录不可写时文件仍可读，但删除必然失败：不能因此把过期内容当有效结果返回。
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)

        await #expect {
            _ = try await service.read(filename: "old.md")
        } throws: { error in
            guard case .purgeFailed(let detail) = error as? TempFileStorageError else { return false }
            return detail.contains("old.md")
        }
        #expect(FileManager.default.fileExists(atPath: expired.path))
    }

    @Test
    func storageErrorsExposeDescriptions() {
        #expect(!TempFileStorageError.invalidFilename.errorDescription!.isEmpty)
        #expect(!TempFileStorageError.pathTraversal.errorDescription!.isEmpty)
        #expect(TempFileStorageError.fileNotFound("x").errorDescription?.contains("x") == true)
        #expect(TempFileStorageError.readFailed("boom").errorDescription?.contains("boom") == true)
        #expect(TempFileStorageError.settingsUnavailable("boom").errorDescription?.contains("boom") == true)
        #expect(TempFileStorageError.purgeFailed("old.md").errorDescription?.contains("old.md") == true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAgentTempStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
