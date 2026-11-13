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
        #expect(model.results.map(\.id) == ["app:/Applications/Find754App.app", "command:Group754/run754"])

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

    // MARK: - 回归 #300：同 Bundle ID 的多份副本必须有唯一结果身份

    @Test func sameBundleIDAppsGetDistinctResultIDs() {
        let first = LauncherResult(app: LauncherAppItem(
            id: "com.example.foo", name: "Foo",
            path: "/Applications/Foo.app", bundleIdentifier: "com.example.foo"
        ))
        let second = LauncherResult(app: LauncherAppItem(
            id: "com.example.foo", name: "Foo",
            path: "/Users/test/Applications/Foo.app", bundleIdentifier: "com.example.foo"
        ))

        // 同一 Bundle ID、不同路径：结果身份必须唯一，不得碰撞。
        #expect(first.id != second.id, "同 Bundle ID 的不同副本必须有不同结果 ID")
        #expect(first.id == "app:/Applications/Foo.app")
        #expect(second.id == "app:/Users/test/Applications/Foo.app")
        // 各自仍指向自己的路径。
        #expect(first.app?.path == "/Applications/Foo.app")
        #expect(second.app?.path == "/Users/test/Applications/Foo.app")
    }

    @Test func clickingSecondCopyResolvesToItsOwnPath() throws {
        let appSearch = AppSearchService.shared
        let model = LauncherSearchModel.shared
        defer {
            appSearch.setAppsForTesting([])
            model.reset()
        }

        appSearch.setAppsForTesting([
            LauncherAppItem(id: "com.example.bar", name: "Bar",
                path: "/Applications/Bar.app", bundleIdentifier: "com.example.bar"),
            LauncherAppItem(id: "com.example.bar", name: "Bar",
                path: "/Users/test/Applications/Bar.app", bundleIdentifier: "com.example.bar"),
        ])
        model.query = "bar"

        let appResults = model.results.filter { $0.kind == .app }
        #expect(appResults.count == 2)
        #expect(Set(appResults.map(\.id)).count == 2, "两份副本的结果 ID 必须唯一")

        // 复刻 LauncherView.flattenedIndex：按结果 ID 反查下标。修复前两份
        // 副本共享 ID，反查永远落到第一份，点击第二份会启动错误路径。
        let secondCopy = try #require(appResults.first { $0.app?.path == "/Users/test/Applications/Bar.app" })
        let resolvedIndex = try #require(model.results.firstIndex(where: { $0.id == secondCopy.id }))
        #expect(model.results[resolvedIndex].app?.path == "/Users/test/Applications/Bar.app", "按 ID 反查必须落到第二份副本自身")
    }

    // MARK: - 回归 #299：Utilities 子目录必须列为扫描根

    @Test func searchDirectoriesIncludeUtilitiesRoots() {
        let roots = AppSearchService.searchDirectories
        // 扫描不递归，系统自带 Terminal/Activity Monitor/Console 位于 Utilities，
        // 必须把 Utilities 显式列为根，否则永远扫不到。
        #expect(roots.contains("/System/Applications/Utilities"), "系统 Utilities 必须显式列为扫描根（#299）")
        #expect(roots.contains("/Applications/Utilities"), "用户级 Utilities 也应列为扫描根（#299）")
        // 既有标准根不得丢失。
        #expect(roots.contains("/Applications"))
        #expect(roots.contains("/System/Applications"))
    }

    @Test func productionRootsDiscoverUtilitiesApp() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("lumi-299-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }

        // 在临时 base 下镜像生产目录布局，把 Terminal.app 放进 Utilities 子目录。
        let utilities = base.appendingPathComponent("System/Applications/Utilities")
        let terminal = utilities.appendingPathComponent("Terminal.app")
        let contents = terminal.appendingPathComponent("Contents")
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleName": "Terminal",
            "CFBundleDisplayName": "Terminal",
            "CFBundleIdentifier": "com.apple.Terminal",
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        // 把生产扫描根整体重定位到临时 base 下，复刻 scanApplications 的根选择。
        // 修复前根列表不含 Utilities，非递归扫描会漏掉其中的 Terminal.app。
        let mappedRoots = AppSearchService.searchDirectories.map { base.path + $0 }
        let items = AppSearchService.scanDirectories(mappedRoots)

        // FileManager 枚举返回 /private/var… 前缀，而构造路径为 /var…（符号链接），
        // 用 UUID base 下唯一的相对后缀匹配，避免绝对路径前缀差异造成误判。
        let relative = "System/Applications/Utilities/Terminal.app"
        let hit = try #require(items.first { $0.path.hasSuffix(relative) }, "生产扫描根必须能发现 Utilities 中的 Terminal（#299）")
        #expect(hit.name == "Terminal")
        #expect(hit.bundleIdentifier == "com.apple.Terminal")
    }
}
