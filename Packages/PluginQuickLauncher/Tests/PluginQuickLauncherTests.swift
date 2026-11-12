import Testing
import AppKit
import Carbon.HIToolbox
@testable import QuickLauncherPlugin

@MainActor
@Suite(.serialized)
struct QuickLauncherTests {

    // MARK: - HotkeyCombo

    @Test func hotkeyDefaultCombo() async throws {
        let combo = HotkeyCombo.defaultCombo
        #expect(combo.keyCode == 49) // kVK_Space
        #expect(combo.modifiers == UInt32(optionKey))
        #expect(combo.hasFunctionModifier)
        #expect(combo.displayString == "⌥Space")
    }

    @Test func hotkeyComboFromEventModifiers() async throws {
        let combo = HotkeyCombo(
            keyCode: UInt32(kVK_ANSI_J),
            eventModifiers: [.command, .shift]
        )
        #expect(combo.modifiers == UInt32(cmdKey | shiftKey))
        #expect(combo.displayString == "⇧⌘J")
    }

    @Test func hotkeyComboShiftOnlyIsNotFunctionModifier() async throws {
        let combo = HotkeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(shiftKey))
        #expect(!combo.hasFunctionModifier)
    }

    // MARK: - Fuzzy Matching

    @Test func fuzzyMatchBasics() async throws {
        #expect(AppSearchService.fuzzyMatch("saf", in: "safari"))
        #expect(AppSearchService.fuzzyMatch("sbm", in: "sublime text merge"))
        #expect(!AppSearchService.fuzzyMatch("zxc", in: "safari"))
        #expect(AppSearchService.fuzzyMatch("", in: "anything"))
    }

    @Test func appSearchFiltersByName() async throws {
        let apps = [
            LauncherAppItem(id: "com.apple.Safari", name: "Safari", path: "/Applications/Safari.app", bundleIdentifier: "com.apple.Safari"),
            LauncherAppItem(id: "com.apple.Terminal", name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", bundleIdentifier: "com.apple.Terminal"),
        ]
        let service = AppSearchService.shared
        service.setAppsForTesting(apps)

        let hit = service.search(matching: "term")
        #expect(hit.count == 1)
        #expect(hit.first?.name == "Terminal")

        let prefixHit = service.search(matching: "saf")
        #expect(prefixHit.first?.name == "Safari")

        let none = service.search(matching: "nonexistent")
        #expect(none.isEmpty)
    }

    // MARK: - LauncherResult

    @Test func launcherResultIDsAreDistinctPerKind() async throws {
        let app = LauncherResult(
            app: LauncherAppItem(id: "a", name: "A", path: "/Applications/A.app", bundleIdentifier: "a")
        )
        let file = LauncherResult(
            file: LauncherFileItem(id: "/tmp/a.txt", name: "a.txt", path: "/tmp/a.txt", isDirectory: false)
        )
        let ai = LauncherResult(aiQuery: "hello")
        #expect(app.kind == .app)
        #expect(file.kind == .file)
        #expect(ai.kind == .ai)
        #expect(app.id != file.id && file.id != ai.id && app.id != ai.id)
    }

    @Test func searchModelAIPrefix() async throws {
        let model = LauncherSearchModel.shared
        model.query = "? 总结这段代码"
        // AI 模式只产生一条结果
        #expect(model.results.count == 1)
        #expect(model.results.first?.kind == .ai)
        #expect(model.results.first?.aiQuery == "总结这段代码")

        // 只有前缀没有问题时无结果
        model.query = "?"
        #expect(model.results.isEmpty)

        model.reset()
        #expect(model.query.isEmpty)
    }

    @Test func commandSearchUsesKernelAgnosticBridge() {
        LauncherBridge.commandGroupsProvider = {
            [LauncherCommandGroup(
                id: "format",
                name: "Formatting",
                items: [LauncherCommandItem(id: "format.document", title: "Format Document", action: {})]
            )]
        }
        defer { LauncherBridge.commandGroupsProvider = nil }

        let model = LauncherSearchModel.shared
        model.query = "format"

        #expect(model.results.contains { $0.id == "command:Formatting/format.document" })
        model.reset()
    }

    @Test func v2PluginPreservesLauncherIdentityAndPolicy() {
        let plugin = QuickLauncherPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.quick-launcher")
        #expect(plugin.order == 8)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    // MARK: - 回归 #739：打开失败不得静默关闭面板

    @Test func fileOpenFailureIsReportedAndDoesNotCountAsSuccess() throws {
        let fileSearch = FileSearchService.shared
        let model = LauncherSearchModel.shared
        let item = LauncherFileItem(
            id: "/tmp/lumi-missing-\(UUID().uuidString).txt",
            name: "lumi-missing.txt",
            path: "/tmp/lumi-missing-\(UUID().uuidString).txt",
            isDirectory: false
        )
        defer {
            fileSearch.setOpenURLForTesting { NSWorkspace.shared.open($0) }
            fileSearch.setResultsForTesting([])
            model.reset()
        }

        fileSearch.setOpenURLForTesting { _ in false }
        fileSearch.setResultsForTesting([item])
        model.query = "lumi-missing"

        let index = try #require(model.results.firstIndex { $0.kind == .file })
        #expect(model.execute(at: index) == false)
        #expect(model.executionError?.contains("lumi-missing.txt") == true)
    }

    @Test func fileOpenSuccessUsesExactPathAndAllowsDismiss() throws {
        let fileSearch = FileSearchService.shared
        let model = LauncherSearchModel.shared
        let item = LauncherFileItem(
            id: "/tmp/lumi-open-\(UUID().uuidString).txt",
            name: "lumi-open.txt",
            path: "/tmp/lumi-open-\(UUID().uuidString).txt",
            isDirectory: false
        )
        var openedPaths: [String] = []
        defer {
            fileSearch.setOpenURLForTesting { NSWorkspace.shared.open($0) }
            fileSearch.setResultsForTesting([])
            model.reset()
        }

        fileSearch.setOpenURLForTesting { url in
            openedPaths.append(url.path)
            return true
        }
        fileSearch.setResultsForTesting([item])
        model.query = "lumi-open"

        let index = try #require(model.results.firstIndex { $0.kind == .file })
        #expect(model.execute(at: index) == true)
        #expect(model.executionError == nil)
        #expect(openedPaths == [item.path])
    }

    // MARK: - 回归 #754：异步文件结果插入后保持选中项身份

    @Test func asyncFileResultsPreserveSelectedItemIdentity() throws {
        let fileSearch = FileSearchService.shared
        let appSearch = AppSearchService.shared
        let model = LauncherSearchModel.shared
        defer {
            fileSearch.setResultsForTesting([])
            appSearch.setAppsForTesting([])
            LauncherBridge.commandGroupsProvider = nil
            model.reset()
        }

        appSearch.setAppsForTesting([
            LauncherAppItem(
                id: "reg754.app",
                name: "Find754App",
                path: "/Applications/Find754App.app",
                bundleIdentifier: "reg754.app"
            )
        ])
        LauncherBridge.commandGroupsProvider = {
            [
                LauncherCommandGroup(
                    id: "reg754",
                    name: "Group754",
                    items: [LauncherCommandItem(id: "run754", title: "Find754 Run", action: {})]
                )
            ]
        }

        model.query = "find754"
        #expect(model.results.map(\.id) == ["app:reg754.app", "command:Group754/run754"])

        // 用户在文件结果到达前选中命令。
        model.selectedIndex = 1
        let selectedID = model.results[model.selectedIndex].id
        #expect(selectedID == "command:Group754/run754")

        // Spotlight 文件结果异步返回，插入到应用与命令之间。
        fileSearch.setResultsForTesting([
            LauncherFileItem(id: "/tmp/find754.txt", name: "find754.txt", path: "/tmp/find754.txt", isDirectory: false)
        ])
        model.rebuildResults()

        #expect(model.results.count == 3)
        #expect(model.results[model.selectedIndex].id == selectedID)
    }

    @Test func disappearingSelectionFallsBackToClampedIndex() throws {
        let fileSearch = FileSearchService.shared
        let model = LauncherSearchModel.shared
        defer {
            fileSearch.setResultsForTesting([])
            model.reset()
        }

        fileSearch.setResultsForTesting([
            LauncherFileItem(id: "/tmp/reg754-a.txt", name: "reg754-a.txt", path: "/tmp/reg754-a.txt", isDirectory: false),
            LauncherFileItem(id: "/tmp/reg754-b.txt", name: "reg754-b.txt", path: "/tmp/reg754-b.txt", isDirectory: false),
        ])
        model.query = "reg754"
        #expect(model.results.count == 2)

        model.selectedIndex = 1
        // 选中的文件消失：下标越界时按既有规则回到 0。
        fileSearch.setResultsForTesting([])
        model.rebuildResults()

        #expect(model.results.isEmpty)
        #expect(model.selectedIndex == 0)
    }

    // MARK: - 回归 #1218：检索不再对全量集合做匹配后截断

    @Test func appSearchStopsOnceLimitIsReached() {
        let service = AppSearchService.shared
        defer { service.setAppsForTesting([]) }

        // 10 个同名应用排在最前，若实现是「全量过滤后再 prefix」，
        // 则 limit=3 时应返回 3 条；这里额外断言排序稳定在注册顺序前缀。
        let apps = (0..<10).map { index in
            LauncherAppItem(
                id: "app\(index)",
                name: "Target App \(index)",
                path: "/Applications/TargetApp\(index).app",
                bundleIdentifier: "app\(index)"
            )
        }
        service.setAppsForTesting(apps)

        let hits = service.searchItems(matching: "target", limit: 3)
        #expect(hits.count == 3)
        #expect(hits.map(\.item.id) == ["app0", "app1", "app2"])
    }

    @Test func appSearchRespectsLimitForFullMatchSet() {
        let service = AppSearchService.shared
        defer { service.setAppsForTesting([]) }

        service.setAppsForTesting([
            LauncherAppItem(id: "a", name: "Alpha", path: "/Applications/Alpha.app", bundleIdentifier: "a"),
            LauncherAppItem(id: "b", name: "Beta", path: "/Applications/Beta.app", bundleIdentifier: "b"),
            LauncherAppItem(id: "c", name: "Gamma", path: "/Applications/Gamma.app", bundleIdentifier: "c"),
        ])

        // 三个都模糊命中 "a"，limit=2 时只应返回 2 条。
        let hits = service.searchItems(matching: "a", limit: 2)
        #expect(hits.count == 2)
    }

    @Test func launcherModelCapsAppAndCommandResults() {
        let appSearch = AppSearchService.shared
        let model = LauncherSearchModel.shared
        defer {
            appSearch.setAppsForTesting([])
            LauncherBridge.commandGroupsProvider = nil
            model.reset()
        }

        appSearch.setAppsForTesting(
            (0..<20).map { index in
                LauncherAppItem(
                    id: "cap\(index)",
                    name: "Cap App \(index)",
                    path: "/Applications/CapApp\(index).app",
                    bundleIdentifier: "cap\(index)"
                )
            }
        )
        LauncherBridge.commandGroupsProvider = {
            [
                LauncherCommandGroup(
                    id: "cap",
                    name: "CapGroup",
                    items: (0..<20).map { index in
                        LauncherCommandItem(id: "cap\(index)", title: "Cap Command \(index)", action: {})
                    }
                )
            ]
        }

        model.query = "cap"
        let appResults = model.results.filter { $0.kind == .app }
        let commandResults = model.results.filter { $0.kind == .command }

        #expect(appResults.count == LauncherSearchModel.appLimit)
        #expect(commandResults.count == LauncherSearchModel.commandLimit)
    }

    @Test func commandIndexRebuildsWhenProviderChanges() {
        let model = LauncherSearchModel.shared
        defer {
            LauncherBridge.commandGroupsProvider = nil
            model.reset()
        }

        LauncherBridge.commandGroupsProvider = {
            [
                LauncherCommandGroup(
                    id: "v1",
                    name: "GroupV1",
                    items: [LauncherCommandItem(id: "one", title: "Version One", action: {})]
                )
            ]
        }
        model.query = "version"
        #expect(model.results.contains { $0.id == "command:GroupV1/one" })

        // 更换命令来源后，索引必须失效并反映新内容。
        LauncherBridge.commandGroupsProvider = {
            [
                LauncherCommandGroup(
                    id: "v2",
                    name: "GroupV2",
                    items: [LauncherCommandItem(id: "two", title: "Version Two", action: {})]
                )
            ]
        }
        model.rebuildResults()
        #expect(model.results.contains { $0.id == "command:GroupV2/two" })
        #expect(!model.results.contains { $0.id == "command:GroupV1/one" })
    }

    @Test func commandExecutionRunsCachedIndexEntry() {
        let model = LauncherSearchModel.shared
        var executed = false
        defer {
            LauncherBridge.commandGroupsProvider = nil
            model.reset()
        }

        LauncherBridge.commandGroupsProvider = {
            [
                LauncherCommandGroup(
                    id: "exec",
                    name: "ExecGroup",
                    items: [
                        LauncherCommandItem(id: "run", title: "Run Executable") {
                            executed = true
                        }
                    ]
                )
            ]
        }
        model.query = "run"
        let index = try? #require(model.results.firstIndex { $0.kind == .command })
        #expect(index != nil)
        if let index {
            #expect(model.execute(at: index) == true)
        }
        #expect(executed)
    }
}
