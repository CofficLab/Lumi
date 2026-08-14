import AppKit
import Testing
@testable import TextActionsPlugin

@MainActor
@Test
func pluginMetadata() {
    let plugin = TextActionsPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.text-actions")
    #expect(plugin.viewContainers(kernel: .init()).count == 1)
}

@Test
func textActionCatalogIsComplete() {
    #expect(TextAction.allCases == [.copy, .search])
    #expect(TextAction.copy.systemImage == "doc.on.doc")
    #expect(TextAction.search.systemImage == "magnifyingglass")
}

@Test
func searchURLEncodesQueryItems() throws {
    let url = try #require(TextAction.searchURL(for: "hello world & swift"))
    #expect(url.absoluteString == "https://www.google.com/search?q=hello%20world%20%26%20swift")
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
    let frame = TextActionMenuLayout.frame(
        for: CGPoint(x: 0, y: 0),
        menuSize: CGSize(width: 200, height: 60),
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )
    #expect(frame.minX == 0)
    #expect(frame.minY == 18)

    let topRightFrame = TextActionMenuLayout.frame(
        for: CGPoint(x: 1_000, y: 790),
        menuSize: CGSize(width: 200, height: 60),
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )
    #expect(topRightFrame.maxX == 992)
    #expect(topRightFrame.maxY == 792)
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
    #expect(monitor.lastMask == [.leftMouseUp, .rightMouseUp, .keyUp])

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
