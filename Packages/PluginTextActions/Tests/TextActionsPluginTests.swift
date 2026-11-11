import AppKit
import Foundation
import Testing
@testable import TextActionsPlugin

@MainActor
@Test
func pluginMetadata() {
    let plugin = TextActionsPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.text-actions")
    #expect(plugin.metadata.name == pluginLocalization.string("Text Actions"))
    #expect(plugin.metadata.category == .system)
}

@Test
func localStorePersistsEnabledFlagInBinaryPlist() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextActionsStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = TextActionsPluginLocalStore(settingsDirectory: directory)
    // 缺省为启用（从未写过该键）：划词失效时完全静默，
    // 缺省关闭会让新装用户拿到一个「装上却像没装」的功能。
    #expect(store.isEnabled)

    store.setEnabled(false)
    #expect(!store.isEnabled)

    // 重新构造实例，确认已落盘而非仅在内存中生效。
    let reloaded = TextActionsPluginLocalStore(settingsDirectory: directory)
    #expect(!reloaded.isEnabled)

    let plistURL = directory.appendingPathComponent("settings.plist")
    let data = try Data(contentsOf: plistURL)
    var format = PropertyListSerialization.PropertyListFormat.xml
    _ = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    #expect(format == .binary)
}

@Test
func localStoreWritesNoUserDefaults() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextActionsStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    // - Important: 这里**只读** `UserDefaults.standard`，绝不写它。
    //   写入会删掉开发者本机真实的「TextActions.enabled」设置（用户数据），
    //   也会让断言受历史残留影响。改成「记录原值 → 写本地存储 → 断言原值未变」，
    //   既验证了「本地存储不写 UserDefaults」，又不碰用户数据。
    let key = "TextActions.enabled"
    let original = UserDefaults.standard.object(forKey: key)

    let store = TextActionsPluginLocalStore(settingsDirectory: directory)
    store.setEnabled(true)

    // `object(forKey:)` 返回 `Any?`，无法直接比较；用描述串对比。
    func describe(_ value: Any?) -> String {
        value.map { String(describing: $0) } ?? "nil"
    }
    #expect(describe(UserDefaults.standard.object(forKey: key)) == describe(original))
    // 实际状态落在插件自己的 plist 里。
    #expect(store.isEnabled == true)
}

@Test
func textActionCatalogIsComplete() {
    #expect(TextAction.allCases == [.copy, .search, .translate])
    #expect(TextAction.copy.systemImage == "doc.on.doc")
    #expect(TextAction.search.systemImage == "magnifyingglass")
    #expect(TextAction.translate.systemImage == "character.book.closed")
}

@Test
func searchURLEncodesQueryItems() throws {
    let url = try #require(TextAction.searchURL(for: "hello world & swift"))
    #expect(url.absoluteString == "https://www.google.com/search?q=hello%20world%20%26%20swift")
}

@Test
func translationRequestUsesSelectedTextAndTranslationInstruction() {
    let request = TextAction.translationRequest(for: "Hello world")

    #expect(request.messages.count == 2)
    #expect(request.messages[0].content.contains("Simplified Chinese"))
    #expect(request.messages[1].content == "Hello world")
    #expect(request.messages[0].role == .system)
    #expect(request.messages[1].role == .user)
}

@Test
func v2TranslationRequestPreservesPromptAndText() {
    let request = TextAction.v2TranslationRequest(for: "Hello world")
    #expect(request.messages.count == 2)
    #expect(request.messages[0].content.contains("Simplified Chinese"))
    #expect(request.messages[1].content == "Hello world")
}

@MainActor
@Test
func v2PluginPreservesIdentityAndOptInPolicy() {
    let plugin = TextActionsPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.text-actions")
    #expect(plugin.order == 275)
    // 划词是「装上就该能用」的功能，且失效时完全静默，
    // 因此插件必须默认启用，而不是要求用户先手动开启。
    #expect(plugin.metadata.policy == .enabledByDefault)
}

@Test
func copyActionWritesToPasteboard() {
    TextAction.copy.perform(with: "selected text")
    #expect(NSPasteboard.general.string(forType: .string) == "selected text")
}

@Test(arguments: [nil, "", "   ", "\n\t"] as [String?])
func emptySelectionDoesNotPresentMenu(_ text: String?) {
    #expect(!TextSelectionReadPolicy.shouldPresentMenu(for: text))
}

@Test(arguments: ["text", " text ", "中文\n内容"])
func nonEmptySelectionPresentsMenu(_ text: String) {
    #expect(TextSelectionReadPolicy.shouldPresentMenu(for: text))
}

@Test
func menuLayoutClampsToScreenEdges() {
    let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let size = CGSize(width: 200, height: 60)

    // 无选区 bounds：回退锚点上方，水平夹到左边距。
    let frame = TextActionMenuLayout.frame(
        selectionRect: nil,
        anchor: CGPoint(x: 0, y: 0),
        menuSize: size,
        screenFrame: screen
    )
    #expect(frame.minX == 8)
    #expect(frame.minY == 14)

    // 有选区 bounds：靠右时夹到右边距；上方空间不足时放到选区下方。
    let topRightFrame = TextActionMenuLayout.frame(
        selectionRect: CGRect(x: 940, y: 770, width: 60, height: 20),
        anchor: CGPoint(x: 1_000, y: 790),
        menuSize: size,
        screenFrame: screen
    )
    #expect(topRightFrame.maxX == 992.0)
    #expect(topRightFrame.maxY == 764.0)
}

@MainActor
@Test
func selectionManagerStartsOnlyOnceAndStopsMonitoring() {
    let monitor = RecordingTextEventMonitor()
    let manager = TextSelectionManager(
        eventMonitor: monitor,
        selectedTextProvider: RecordingSelectedTextProvider(),
        permissionChecker: { true }
    )

    manager.startMonitoring()
    manager.startMonitoring()
    #expect(monitor.addCount == 1)
    // leftMouseDown 用于判定拖拽划选；右键是上下文菜单手势，不参与触发。
    #expect(monitor.lastMask == [.leftMouseDown, .leftMouseUp, .keyUp])

    manager.stopMonitoring()
    #expect(monitor.removeCount == 1)
}

@MainActor
@Test
func selectionManagerDoesNotMonitorWithoutAccessibilityPermission() {
    let monitor = RecordingTextEventMonitor()
    let manager = TextSelectionManager(
        eventMonitor: monitor,
        selectedTextProvider: RecordingSelectedTextProvider(),
        permissionChecker: { false }
    )

    manager.startMonitoring()

    #expect(!manager.isPermissionGranted)
    #expect(monitor.addCount == 0)
}

@MainActor
@Test
func selectionManagerCanStartAfterPermissionIsGranted() {
    let monitor = RecordingTextEventMonitor()
    var permissionGranted = false
    let manager = TextSelectionManager(
        eventMonitor: monitor,
        selectedTextProvider: RecordingSelectedTextProvider(),
        permissionChecker: { permissionGranted }
    )

    manager.startMonitoring()
    #expect(monitor.addCount == 0)

    permissionGranted = true
    manager.refreshPermission()
    manager.startMonitoring()
    #expect(monitor.addCount == 1)
}

@MainActor
@Test
func selectedTextProviderCanSimulateAXRetrySequence() {
    let provider = RecordingSelectedTextProvider(
        results: [nil, SelectedText(text: "selected", anchor: CGPoint(x: 10, y: 20))]
    )

    let first = provider.readSelectedText(anchor: CGPoint(x: 10, y: 20))
    let second = provider.readSelectedText(anchor: CGPoint(x: 10, y: 20))

    #expect(first == nil)
    #expect(second?.text == "selected")
    #expect(second?.anchor == CGPoint(x: 10, y: 20))
}

@MainActor
private final class RecordingTextEventMonitor: TextEventMonitoring {
    private(set) var addCount = 0
    private(set) var removeCount = 0
    private(set) var lastMask: NSEvent.EventTypeMask?

    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any? {
        addCount += 1
        lastMask = mask
        return NSObject()
    }

    func removeMonitor(_ monitor: Any) {
        removeCount += 1
    }
}

@MainActor
private final class RecordingSelectedTextProvider: SelectedTextProviding {
    private var results: [SelectedText?]

    init(results: [SelectedText?] = []) {
        self.results = results
    }

    func readSelectedText(anchor: CGPoint) -> SelectedText? {
        guard !results.isEmpty else { return nil }
        return results.removeFirst()
    }
}
