import Foundation
import Testing
@testable import ProviderTheme

@MainActor
@Suite("ProviderTheme")
struct ProviderThemeTests {

    // MARK: - Helpers

    private func makeTheme(id: String, sortOrder: Int = 100) -> LumiTheme {
        LumiTheme(
            id: id,
            sortOrder: sortOrder,
            displayName: id,
            iconName: "circle",
            iconColor: ThemeHexPair(hex: "007AFF"),
            appearanceKind: .system,
            palette: BuiltinThemes.system.palette
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderThemeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 构造使用独立临时目录的 Provider，避免并行测试间共享持久化状态。
    private func makeProvider(builtinThemes: [LumiTheme] = BuiltinThemes.all) throws -> DefaultThemeProviding {
        DefaultThemeProviding(
            storageDirectory: try makeTemporaryDirectory(),
            builtinThemes: builtinThemes
        )
    }

    // MARK: - Builtin Themes

    @Test("内置主题全部注册，默认选中第一个（System）")
    func builtinThemesRegisteredAndDefaultSelection() throws {
        let provider = try makeProvider()

        #expect(provider.themes.map(\.id) == ["lumi-system", "lumi-dark", "lumi-light"])
        #expect(provider.selectedThemeId == "lumi-system")
        #expect(provider.selectedTheme?.id == "lumi-system")
    }

    @Test("默认选中主题跟随系统外观")
    func defaultThemeFollowsSystemAppearance() throws {
        let provider = try makeProvider()
        #expect(provider.followsSystemAppearance == true)
    }

    // MARK: - Selection

    @Test("切换到已注册主题成功")
    func selectThemeSuccess() throws {
        let provider = try makeProvider()

        try provider.selectTheme(id: "lumi-dark")

        #expect(provider.selectedThemeId == "lumi-dark")
        #expect(provider.selectedTheme?.displayName == "Dark")
        #expect(provider.followsSystemAppearance == false)
    }

    @Test("切换到未知主题抛错")
    func selectUnknownThemeThrows() throws {
        let provider = try makeProvider()

        #expect(throws: ThemeProvidingError.unknownThemeId("nope")) {
            try provider.selectTheme(id: "nope")
        }
        // 选中状态保持不变
        #expect(provider.selectedThemeId == "lumi-system")
    }

    // MARK: - Registration

    @Test("注册主题按 sortOrder 升序排列")
    func registerSortsByOrder() throws {
        let provider = try makeProvider(builtinThemes: [])

        provider.registerTheme(makeTheme(id: "b", sortOrder: 200))
        provider.registerTheme(makeTheme(id: "a", sortOrder: 100))

        #expect(provider.themes.map(\.id) == ["a", "b"])
    }

    @Test("同 id 注册覆盖旧主题且不重复")
    func registerSameIDOverrides() throws {
        let provider = try makeProvider(builtinThemes: [])

        provider.registerTheme(makeTheme(id: "a", sortOrder: 100))
        provider.registerTheme(makeTheme(id: "a", sortOrder: 500))

        #expect(provider.themes.count == 1)
        #expect(provider.themes.first?.sortOrder == 500)
    }

    @Test("注销当前选中主题回退到剩余第一个")
    func unregisterSelectedFallsBack() throws {
        let provider = try makeProvider()
        try? provider.selectTheme(id: "lumi-dark")

        provider.unregisterTheme(id: "lumi-dark")

        #expect(!provider.themes.contains { $0.id == "lumi-dark" })
        #expect(provider.selectedThemeId == "lumi-system")
    }

    @Test("注销未注册主题为 no-op")
    func unregisterUnknownIsNoop() throws {
        let provider = try makeProvider()
        let count = provider.themes.count

        provider.unregisterTheme(id: "missing")

        #expect(provider.themes.count == count)
        #expect(provider.selectedThemeId == "lumi-system")
    }

    // MARK: - Replace All

    @Test("空列表全量替换抛错")
    func replaceAllEmptyThrows() throws {
        let provider = try makeProvider()

        #expect(throws: ThemeProvidingError.noThemesRegistered) {
            try provider.replaceAllThemes([])
        }
    }

    @Test("重复 id 全量替换抛错")
    func replaceAllDuplicateThrows() throws {
        let provider = try makeProvider()

        #expect(throws: ThemeProvidingError.duplicateThemeId("dup")) {
            try provider.replaceAllThemes([
                makeTheme(id: "dup"),
                makeTheme(id: "dup"),
            ])
        }
    }

    @Test("全量替换保持当前选中")
    func replaceAllKeepsSelection() throws {
        let provider = try makeProvider()
        try provider.selectTheme(id: "lumi-dark")

        try provider.replaceAllThemes([
            makeTheme(id: "lumi-dark", sortOrder: 100),
            makeTheme(id: "other", sortOrder: 200),
        ])

        #expect(provider.themes.map(\.id) == ["lumi-dark", "other"])
        #expect(provider.selectedThemeId == "lumi-dark")
    }

    @Test("全量替换后原选中不存在则回退第一个")
    func replaceAllFallsBackToFirst() throws {
        let provider = try makeProvider()
        try provider.selectTheme(id: "lumi-dark")

        try provider.replaceAllThemes([
            makeTheme(id: "a", sortOrder: 100),
            makeTheme(id: "b", sortOrder: 200),
        ])

        #expect(provider.selectedThemeId == "a")
    }

    // MARK: - Persistence

    @Test("选中主题持久化并在重建后恢复")
    func selectionPersistsAcrossInstances() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = DefaultThemeProviding(storageDirectory: directory)
        try first.selectTheme(id: "lumi-dark")

        // 等待异步写盘完成。
        try await Task.sleep(for: .milliseconds(300))

        let second = DefaultThemeProviding(storageDirectory: directory)
        #expect(second.selectedThemeId == "lumi-dark")
    }

    @Test("持久化偏好优先于默认第一个主题")
    func persistedSelectionBeatsDefault() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = DefaultThemeProviding(storageDirectory: directory)
        try first.selectTheme(id: "lumi-light")
        try await Task.sleep(for: .milliseconds(300))

        // 重建后 lumi-light（sortOrder 300）仍应被选中，而非默认的 lumi-system。
        let second = DefaultThemeProviding(storageDirectory: directory)
        #expect(second.selectedThemeId == "lumi-light")
    }
}
