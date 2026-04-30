#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import SwiftUI
@testable import Lumi

@MainActor
final class EditorExtensionRegistryTests: XCTestCase {
    func testHighlightProvidersFiltersByLanguageAndDeduplicatesProviderInstances() {
        let registry = EditorExtensionRegistry()
        let sharedProvider = TestHighlightProvider()
        let swiftOnly = TestHighlightContributor(
            id: "swift-only",
            supportedLanguageIDs: ["swift"],
            providers: [sharedProvider]
        )
        let duplicateSwift = TestHighlightContributor(
            id: "swift-duplicate",
            supportedLanguageIDs: ["swift"],
            providers: [sharedProvider]
        )
        let markdownOnly = TestHighlightContributor(
            id: "markdown-only",
            supportedLanguageIDs: ["markdown"],
            providers: [TestHighlightProvider()]
        )

        registry.registerHighlightProviderContributor(swiftOnly)
        registry.registerHighlightProviderContributor(duplicateSwift)
        registry.registerHighlightProviderContributor(markdownOnly)

        let swiftProviders = registry.highlightProviders(for: "swift")
        let markdownProviders = registry.highlightProviders(for: "markdown")

        XCTAssertEqual(swiftProviders.count, 1)
        XCTAssertTrue(swiftProviders.first === sharedProvider)
        XCTAssertEqual(markdownProviders.count, 1)
        XCTAssertFalse(markdownProviders.first === sharedProvider)
    }

    func testHoverSuggestionsMergeLegacyAndHoverContentContributors() async {
        let registry = EditorExtensionRegistry()
        registry.registerHoverContributor(
            TestHoverContributor(id: "legacy-hover", markdowns: ["legacy"], priority: 10)
        )
        registry.registerHoverContentContributor(
            TestHoverContentContributor(id: "content-hover", markdowns: ["content"], priority: 20)
        )

        let suggestions = await registry.hoverSuggestions(
            for: EditorHoverContext(languageId: "swift", line: 0, character: 0, symbol: "demo")
        )

        XCTAssertEqual(suggestions.map(\.markdown), ["content", "legacy"])
    }

    func testContextMenuSuggestionsMergeCommandsAndContextMenuContributors() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerCommandContributor(
            TestCommandContributor(id: "legacy-command", items: [
                EditorCommandSuggestion(
                    id: "builtin.rename",
                    title: "Rename",
                    systemImage: "pencil",
                    category: EditorCommandCategory.navigation.rawValue,
                    order: 20,
                    isEnabled: true,
                    action: {}
                )
            ])
        )
        registry.registerContextMenuContributor(
            TestContextMenuContributor(id: "menu-extra", items: [
                EditorContextMenuItemSuggestion(
                    id: "custom.inspect",
                    title: "Inspect Selection",
                    systemImage: "magnifyingglass",
                    category: EditorCommandCategory.other.rawValue,
                    order: 10,
                    isEnabled: true,
                    action: {}
                )
            ])
        )

        let suggestions = registry.contextMenuSuggestions(
            for: EditorCommandContext(languageId: "swift", hasSelection: true, line: 0, character: 0),
            state: state,
            textView: nil
        )

        XCTAssertEqual(suggestions.map(\.id), ["custom.inspect", "builtin.rename"])
    }

    func testContextMenuSuggestionsRespectContributionEnablementContext() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerContextMenuContributor(
            TestContextMenuContributor(id: "menu-extra", items: [
                EditorContextMenuItemSuggestion(
                    id: "custom.selection-only",
                    title: "Selection Only",
                    systemImage: "selection.pin.in.out",
                    order: 10,
                    isEnabled: true,
                    metadata: .init(whenClause: .key(.hasSelection)),
                    action: {}
                )
            ])
        )

        let withoutSelection = registry.contextMenuSuggestions(
            for: EditorCommandContext(languageId: "swift", hasSelection: false, line: 0, character: 0),
            state: state,
            textView: nil
        )
        let withSelection = registry.contextMenuSuggestions(
            for: EditorCommandContext(languageId: "swift", hasSelection: true, line: 0, character: 0),
            state: state,
            textView: nil
        )

        XCTAssertTrue(withoutSelection.isEmpty)
        XCTAssertEqual(withSelection.map(\.id), ["custom.selection-only"])
    }

    func testQuickOpenSuggestionsSupportComposedWhenClauses() async {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerQuickOpenContributor(
            TestQuickOpenContributor(id: "quick-open-when", items: [
                EditorQuickOpenItemSuggestion(
                    id: "symbol.swift-only",
                    sectionTitle: "Symbols",
                    title: "Swift Only",
                    subtitle: nil,
                    systemImage: "swift",
                    badge: nil,
                    order: 10,
                    isEnabled: true,
                    metadata: .init(
                        whenClause: .all([
                            .equals(.languageId, .string("swift")),
                            .not(.key(.isLargeFileMode)),
                        ])
                    ),
                    action: {}
                )
            ])
        )

        let items = await registry.quickOpenSuggestions(matching: "swift", state: state)

        XCTAssertEqual(items.map(\.id), ["symbol.swift-only"])
    }

    func testPanelSuggestionsFilterByPlacementAndDeduplicateIDs() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerPanelContributor(
            TestPanelContributor(id: "panel-contributor", items: [
                EditorPanelSuggestion(
                    id: "custom.tools",
                    title: "Tools",
                    systemImage: "hammer",
                    placement: .bottom,
                    order: 20,
                    isPresented: { _ in true },
                    onDismiss: { _ in },
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorPanelSuggestion(
                    id: "custom.tools",
                    title: "Tools Duplicate",
                    systemImage: "hammer",
                    placement: .bottom,
                    order: 30,
                    isPresented: { _ in true },
                    onDismiss: { _ in },
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorPanelSuggestion(
                    id: "custom.inspect",
                    title: "Inspect",
                    systemImage: "sidebar.left",
                    placement: .side,
                    order: 10,
                    isPresented: { _ in true },
                    onDismiss: { _ in },
                    content: { _ in AnyView(EmptyView()) }
                )
            ])
        )

        let panels = registry.panelSuggestions(state: state)

        XCTAssertEqual(panels.map(\.id), ["custom.tools", "custom.inspect"])
        XCTAssertEqual(panels.map(\.placement), [.bottom, .side])
    }

    func testPanelSuggestionsPreferHigherPriorityForSharedDedupeKey() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerPanelContributor(
            TestPanelContributor(id: "panel-priority", items: [
                EditorPanelSuggestion(
                    id: "custom.inspect-low",
                    title: "Inspect Low",
                    systemImage: "sidebar.left",
                    placement: .side,
                    order: 20,
                    metadata: .init(priority: 10, dedupeKey: "inspect"),
                    isPresented: { _ in true },
                    onDismiss: { _ in },
                    content: { _ in AnyView(Text("Low")) }
                ),
                EditorPanelSuggestion(
                    id: "custom.inspect-high",
                    title: "Inspect High",
                    systemImage: "sidebar.left",
                    placement: .side,
                    order: 30,
                    metadata: .init(priority: 100, dedupeKey: "inspect"),
                    isPresented: { _ in true },
                    onDismiss: { _ in },
                    content: { _ in AnyView(Text("High")) }
                )
            ])
        )

        let panels = registry.panelSuggestions(state: state)

        XCTAssertEqual(panels.map(\.id), ["custom.inspect-high"])
    }

    func testToolbarSuggestionsBridgeStatusItemContributors() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerStatusItemContributor(
            TestStatusItemContributor(id: "status-items", items: [
                EditorStatusItemSuggestion(
                    id: "status.center",
                    order: 20,
                    placement: .toolbarCenter,
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorStatusItemSuggestion(
                    id: "status.trailing",
                    order: 10,
                    placement: .toolbarTrailing,
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorStatusItemSuggestion(
                    id: "status.title",
                    order: 30,
                    placement: .titleTrailing,
                    content: { _ in AnyView(EmptyView()) }
                )
            ])
        )

        let toolbarItems = registry.toolbarItemSuggestions(state: state)
        let statusItems = registry.statusItemSuggestions(state: state)

        XCTAssertEqual(toolbarItems.map(\.id), ["status.center", "status.trailing"])
        XCTAssertEqual(toolbarItems.map(\.placement), [.center, .trailing])
        XCTAssertEqual(statusItems.map(\.id), ["status.center", "status.trailing", "status.title"])
    }

    func testStatusItemsPreferHigherPriorityForSharedPlacementAndDedupeKey() {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerStatusItemContributor(
            TestStatusItemContributor(id: "status-priority", items: [
                EditorStatusItemSuggestion(
                    id: "status.low",
                    order: 20,
                    placement: .toolbarTrailing,
                    metadata: .init(priority: 1, dedupeKey: "shared"),
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorStatusItemSuggestion(
                    id: "status.high",
                    order: 30,
                    placement: .toolbarTrailing,
                    metadata: .init(priority: 20, dedupeKey: "shared"),
                    content: { _ in AnyView(EmptyView()) }
                )
            ])
        )

        let statusItems = registry.statusItemSuggestions(state: state)

        XCTAssertEqual(statusItems.map(\.id), ["status.high"])
    }

    func testQuickOpenSuggestionsDeduplicateByIDAndPreserveSectionOrdering() async {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerQuickOpenContributor(
            TestQuickOpenContributor(id: "quick-open", items: [
                EditorQuickOpenItemSuggestion(
                    id: "symbol.main",
                    sectionTitle: "Symbols",
                    title: "MainView",
                    subtitle: "App",
                    systemImage: "swift",
                    badge: "Struct",
                    order: 20,
                    isEnabled: true,
                    action: {}
                ),
                EditorQuickOpenItemSuggestion(
                    id: "symbol.main",
                    sectionTitle: "Symbols",
                    title: "MainView Duplicate",
                    subtitle: "App",
                    systemImage: "swift",
                    badge: "Struct",
                    order: 30,
                    isEnabled: true,
                    action: {}
                ),
                EditorQuickOpenItemSuggestion(
                    id: "file.readme",
                    sectionTitle: "Files",
                    title: "README.md",
                    subtitle: "/docs",
                    systemImage: "doc",
                    badge: nil,
                    order: 10,
                    isEnabled: true,
                    action: {}
                )
            ])
        )

        let items = await registry.quickOpenSuggestions(matching: "main", state: state)

        XCTAssertEqual(items.map(\.id), ["file.readme", "symbol.main"])
        XCTAssertEqual(items.map(\.sectionTitle), ["Files", "Symbols"])
    }

    func testQuickOpenSuggestionsRespectEnablementAndPriorityMetadata() async {
        let registry = EditorExtensionRegistry()
        let state = EditorState()
        registry.registerQuickOpenContributor(
            TestQuickOpenContributor(id: "quick-open-priority", items: [
                EditorQuickOpenItemSuggestion(
                    id: "symbol.low",
                    sectionTitle: "Symbols",
                    title: "Demo Low",
                    subtitle: "App",
                    systemImage: "swift",
                    badge: "Struct",
                    order: 20,
                    isEnabled: true,
                    metadata: .init(priority: 10, dedupeKey: "symbol-demo"),
                    action: {}
                ),
                EditorQuickOpenItemSuggestion(
                    id: "symbol.high",
                    sectionTitle: "Symbols",
                    title: "Demo High",
                    subtitle: "App",
                    systemImage: "swift",
                    badge: "Struct",
                    order: 50,
                    isEnabled: true,
                    metadata: .init(priority: 100, dedupeKey: "symbol-demo"),
                    action: {}
                ),
                EditorQuickOpenItemSuggestion(
                    id: "symbol.disabled",
                    sectionTitle: "Symbols",
                    title: "Disabled",
                    subtitle: nil,
                    systemImage: "swift",
                    badge: nil,
                    order: 0,
                    isEnabled: true,
                    metadata: .init(isEnabled: { _ in false }),
                    action: {}
                )
            ])
        )

        let items = await registry.quickOpenSuggestions(matching: "demo", state: state)

        XCTAssertEqual(items.map(\.id), ["symbol.high"])
    }

    func testSettingsSuggestionsRespectPriorityAndDedupe() {
        let registry = EditorExtensionRegistry()
        let settingsState = EditorSettingsState()
        registry.registerSettingsContributor(
            TestSettingsContributor(id: "settings-priority", items: [
                EditorSettingsItemSuggestion(
                    id: "settings.low",
                    sectionTitle: "Extensions",
                    title: "Low Priority",
                    keywords: ["demo"],
                    order: 20,
                    metadata: .init(priority: 10, dedupeKey: "shared-setting"),
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorSettingsItemSuggestion(
                    id: "settings.high",
                    sectionTitle: "Extensions",
                    title: "High Priority",
                    keywords: ["demo"],
                    order: 30,
                    metadata: .init(priority: 80, dedupeKey: "shared-setting"),
                    content: { _ in AnyView(EmptyView()) }
                ),
                EditorSettingsItemSuggestion(
                    id: "settings.disabled",
                    sectionTitle: "Extensions",
                    title: "Disabled",
                    keywords: ["demo"],
                    order: 40,
                    metadata: .init(isEnabled: { _ in false }),
                    content: { _ in AnyView(EmptyView()) }
                )
            ])
        )

        let items = registry.settingsSuggestions(state: settingsState)

        XCTAssertEqual(items.map(\.id), ["settings.high"])
    }
}

@MainActor
private final class TestHighlightContributor: EditorHighlightProviderContributor {
    let id: String
    private let supportedLanguageIDs: Set<String>
    private let providers: [any HighlightProviding]

    init(id: String, supportedLanguageIDs: Set<String>, providers: [any HighlightProviding]) {
        self.id = id
        self.supportedLanguageIDs = supportedLanguageIDs
        self.providers = providers
    }

    func supports(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId)
    }

    func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        providers
    }
}

@MainActor
private final class TestHighlightProvider: HighlightProviding {
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {}

    func willApplyEdit(textView: TextView, range: NSRange) {}

    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        completion(.success(IndexSet()))
    }

    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        completion(.success([]))
    }
}

@MainActor
private final class TestHoverContributor: EditorHoverContributor {
    let id: String
    private let markdowns: [String]
    private let priority: Int

    init(id: String, markdowns: [String], priority: Int) {
        self.id = id
        self.markdowns = markdowns
        self.priority = priority
    }

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        markdowns.map { EditorHoverSuggestion(markdown: $0, priority: priority) }
    }
}

@MainActor
private final class TestHoverContentContributor: EditorHoverContentContributor {
    let id: String
    private let markdowns: [String]
    private let priority: Int

    init(id: String, markdowns: [String], priority: Int) {
        self.id = id
        self.markdowns = markdowns
        self.priority = priority
    }

    func provideHoverContent(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        markdowns.map { EditorHoverSuggestion(markdown: $0, priority: priority) }
    }
}

@MainActor
private final class TestCommandContributor: EditorCommandContributor {
    let id: String
    private let items: [EditorCommandSuggestion]

    init(id: String, items: [EditorCommandSuggestion]) {
        self.id = id
        self.items = items
    }

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        items
    }
}

@MainActor
private final class TestContextMenuContributor: EditorContextMenuContributor {
    let id: String
    private let items: [EditorContextMenuItemSuggestion]

    init(id: String, items: [EditorContextMenuItemSuggestion]) {
        self.id = id
        self.items = items
    }

    func provideContextMenuItems(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorContextMenuItemSuggestion] {
        items
    }
}

@MainActor
private final class TestPanelContributor: EditorPanelContributor {
    let id: String
    private let items: [EditorPanelSuggestion]

    init(id: String, items: [EditorPanelSuggestion]) {
        self.id = id
        self.items = items
    }

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        items
    }
}

@MainActor
private final class TestStatusItemContributor: EditorStatusItemContributor {
    let id: String
    private let items: [EditorStatusItemSuggestion]

    init(id: String, items: [EditorStatusItemSuggestion]) {
        self.id = id
        self.items = items
    }

    func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion] {
        items
    }
}

@MainActor
private final class TestSettingsContributor: EditorSettingsContributor {
    let id: String
    private let items: [EditorSettingsItemSuggestion]

    init(id: String, items: [EditorSettingsItemSuggestion]) {
        self.id = id
        self.items = items
    }

    func provideSettingsItems(state: EditorSettingsState) -> [EditorSettingsItemSuggestion] {
        items
    }
}

@MainActor
private final class TestQuickOpenContributor: EditorQuickOpenContributor {
    let id: String
    private let items: [EditorQuickOpenItemSuggestion]

    init(id: String, items: [EditorQuickOpenItemSuggestion]) {
        self.id = id
        self.items = items
    }

    func provideQuickOpenItems(
        query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        items
    }
}
#endif
