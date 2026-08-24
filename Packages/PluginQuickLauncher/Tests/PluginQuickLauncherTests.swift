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
        let plugin = QuickLauncherSuperPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.quick-launcher")
        #expect(plugin.order == 8)
        #expect(plugin.metadata.policy == .alwaysOn)
    }
}
