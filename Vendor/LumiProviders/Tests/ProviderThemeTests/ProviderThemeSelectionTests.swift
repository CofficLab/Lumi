import Foundation
import Testing
@testable import ProviderTheme

/// 主题选中状态持久化、存储注入与事件精确度的契约测试。
@Suite("ProviderTheme selection")
@MainActor
struct ProviderThemeSelectionTests {

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderThemeSelectionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeProvider(
        storageDirectory: URL? = nil
    ) throws -> DefaultThemeProviding {
        DefaultThemeProviding(
            storageDirectory: try storageDirectory ?? makeTemporaryDirectory(),
            builtinThemes: BuiltinThemes.all
        )
    }

    @Test("setStorageDirectory 从新目录恢复持久化选中并通知")
    func setStorageDirectoryRestoresAndNotifies() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try makeProvider(storageDirectory: directory)
        try first.selectTheme(id: "lumi-dark")
        try await Task.sleep(for: .milliseconds(300))

        var observed: String?
        let second = try makeProvider()
        let handle = second.addObserver { event in
            if case let .selectionChanged(themeID) = event {
                observed = themeID
            }
        }

        second.setStorageDirectory(directory)

        #expect(second.selectedThemeId == "lumi-dark")
        #expect(observed == "lumi-dark")
        handle.cancel()
    }

    @Test("setStorageDirectory 注入相同选中时不上抛事件")
    func setStorageDirectoryWithSameSelectionIsQuiet() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = try makeProvider(storageDirectory: directory)
        var eventCount = 0
        let handle = provider.addObserver { _ in eventCount += 1 }

        provider.setStorageDirectory(directory)

        #expect(eventCount == 0)
        handle.cancel()
    }

    @Test("重复选中同一主题不触发事件")
    func reselectingSameThemeIsQuiet() throws {
        let provider = try makeProvider()
        var eventCount = 0
        let handle = provider.addObserver { _ in eventCount += 1 }

        try provider.selectTheme(id: "lumi")

        #expect(eventCount == 0)
        #expect(provider.selectedThemeId == "lumi")
        handle.cancel()
    }

    @Test("注销当前选中同时发布列表变化与选中变化")
    func unregisteringSelectedEmitsBothEvents() throws {
        let provider = try makeProvider()
        var events: [String] = []
        let handle = provider.addObserver { event in
            switch event {
            case .themesChanged: events.append("themes")
            case .selectionChanged: events.append("selection")
            }
        }

        try provider.selectTheme(id: "lumi-dark")
        events.removeAll()

        provider.unregisterTheme(id: "lumi-dark")

        #expect(events == ["themes", "selection"])
        #expect(provider.selectedThemeId == "lumi")
        handle.cancel()
    }

    @Test("全量替换保持选中时只发布列表变化")
    func replaceAllKeepingSelectionEmitsOnlyThemesChanged() throws {
        let provider = try makeProvider()
        var events: [String] = []
        let handle = provider.addObserver { event in
            switch event {
            case .themesChanged: events.append("themes")
            case .selectionChanged: events.append("selection")
            }
        }

        try provider.replaceAllThemes([provider.themes[0]])

        #expect(events == ["themes"])
        handle.cancel()
    }

    @Test("全量替换导致选中回退时发布选中变化")
    func replaceAllFallingBackEmitsSelectionChanged() throws {
        let provider = try makeProvider()
        try provider.selectTheme(id: "lumi-dark")
        var events: [String] = []
        let handle = provider.addObserver { event in
            switch event {
            case .themesChanged: events.append("themes")
            case .selectionChanged: events.append("selection")
            }
        }

        try provider.replaceAllThemes([
            makeTheme(id: "a", sortOrder: 100),
            makeTheme(id: "b", sortOrder: 200),
        ])

        #expect(events == ["themes", "selection"])
        #expect(provider.selectedThemeId == "a")
        handle.cancel()
    }

    @Test("持久化选中不存在的主题时回退到第一个")
    func persistedSelectionOfUnknownThemeFallsBack() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 直接写入幽灵主题 id，模拟旧文件损坏/主题被移除。
        let plist: [String: String] = ["selectedThemeID": "ghost-theme"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("theme-selection.plist"))

        let provider = try makeProvider(storageDirectory: directory)

        #expect(provider.selectedThemeId == "lumi")
        #expect(provider.selectedTheme?.id == "lumi")
    }

    @Test("selectedTheme 与选中 id 保持一致")
    func selectedThemeFollowsSelection() throws {
        let provider = try makeProvider()
        try provider.selectTheme(id: "lumi-light")

        #expect(provider.selectedThemeId == "lumi-light")
        #expect(provider.selectedTheme?.id == "lumi-light")
        #expect(provider.followsSystemAppearance == false)
    }

    private func makeTheme(id: String, sortOrder: Int) -> LumiTheme {
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
}
