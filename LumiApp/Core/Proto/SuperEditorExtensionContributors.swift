import Foundation
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

// MARK: - Contribution Context

@MainActor
struct EditorContributionContext {
    let languageId: String
    let fileURL: URL?
    let hasSelection: Bool
    let line: Int
    let character: Int
    let isEditorActive: Bool
    let isLargeFileMode: Bool

    func value(for key: EditorContextKey) -> EditorContextValue {
        switch key {
        case .languageId:
            .string(languageId)
        case .hasFileURL:
            .bool(fileURL != nil)
        case .hasSelection:
            .bool(hasSelection)
        case .line:
            .int(line)
        case .character:
            .int(character)
        case .isEditorActive:
            .bool(isEditorActive)
        case .isLargeFileMode:
            .bool(isLargeFileMode)
        }
    }
}

enum EditorContextValue: Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)
}

enum EditorContextKey: String, CaseIterable, Equatable {
    case languageId = "editor.languageId"
    case hasFileURL = "editor.hasFileURL"
    case hasSelection = "editor.hasSelection"
    case line = "editor.line"
    case character = "editor.character"
    case isEditorActive = "editor.isEditorActive"
    case isLargeFileMode = "editor.isLargeFileMode"
}

indirect enum EditorWhenClause: Equatable {
    case key(EditorContextKey)
    case equals(EditorContextKey, EditorContextValue)
    case not(EditorWhenClause)
    case all([EditorWhenClause])
    case any([EditorWhenClause])

    @MainActor
    func evaluate(in context: EditorContributionContext) -> Bool {
        switch self {
        case .key(let key):
            guard case .bool(let value) = context.value(for: key) else { return false }
            return value
        case .equals(let key, let expected):
            return context.value(for: key) == expected
        case .not(let clause):
            return !clause.evaluate(in: context)
        case .all(let clauses):
            return clauses.allSatisfy { $0.evaluate(in: context) }
        case .any(let clauses):
            return clauses.contains { $0.evaluate(in: context) }
        }
    }
}

@MainActor
struct EditorContributionMetadata {
    let priority: Int
    let dedupeKey: String?
    let whenClause: EditorWhenClause?
    let enablement: (EditorContributionContext) -> Bool

    init(
        priority: Int = 0,
        dedupeKey: String? = nil,
        whenClause: EditorWhenClause? = nil,
        isEnabled: @escaping (EditorContributionContext) -> Bool = { _ in true }
    ) {
        self.priority = priority
        self.dedupeKey = dedupeKey
        self.whenClause = whenClause
        self.enablement = isEnabled
    }

    @MainActor
    func matches(_ context: EditorContributionContext) -> Bool {
        let whenMatches = whenClause?.evaluate(in: context) ?? true
        return whenMatches && enablement(context)
    }
}

// MARK: - Completion

/// 编辑器补全上下文
@MainActor
struct EditorCompletionContext {
    let languageId: String
    let line: Int
    let character: Int
    let prefix: String
    let isTypeContext: Bool
}

/// 编辑器补全建议（由扩展提供）
@MainActor
struct EditorCompletionSuggestion: Hashable {
    let label: String
    let insertText: String
    let detail: String?
    let priority: Int
}

/// 编辑器补全扩展点
@MainActor
protocol SuperEditorCompletionContributor: AnyObject {
    var id: String { get }
    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion]
}

// MARK: - Hover

/// 编辑器悬停上下文
@MainActor
struct EditorHoverContext {
    let languageId: String
    let line: Int
    let character: Int
    let symbol: String
}

/// 编辑器悬停建议
@MainActor
struct EditorHoverSuggestion: Hashable {
    let markdown: String
    let priority: Int
    let dedupeKey: String?

    init(markdown: String, priority: Int, dedupeKey: String? = nil) {
        self.markdown = markdown
        self.priority = priority
        self.dedupeKey = dedupeKey
    }
}

/// 编辑器悬停扩展点
@MainActor
protocol SuperEditorHoverContributor: AnyObject {
    var id: String { get }
    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion]
}

/// 编辑器悬停内容扩展点
///
/// 相比旧的 `SuperEditorHoverContributor`，这个命名更明确地强调它只负责贡献 hover 内容，
/// 不负责 hover 的触发时机、请求生命周期或卡片布局。
@MainActor
protocol SuperEditorHoverContentContributor: AnyObject {
    var id: String { get }
    func provideHoverContent(context: EditorHoverContext) async -> [EditorHoverSuggestion]
}

// MARK: - Code Action

/// 编辑器代码动作上下文
@MainActor
struct EditorCodeActionContext {
    let languageId: String
    let line: Int
    let character: Int
    let selectedText: String?
}

/// 编辑器代码动作建议
@MainActor
struct EditorCodeActionSuggestion: Hashable {
    let id: String
    let title: String
    let command: String
    let priority: Int
}

/// 编辑器代码动作扩展点
@MainActor
protocol SuperEditorCodeActionContributor: AnyObject {
    var id: String { get }
    func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion]
}

// MARK: - Highlight Provider

/// 编辑器高亮 provider 扩展点
///
/// 允许插件按语言注入 `CodeEditSourceEditor` 的高亮 provider，
/// 例如 Markdown、特殊 DSL、额外语义层等。
@MainActor
protocol SuperEditorHighlightProviderContributor: AnyObject {
    var id: String { get }
    func supports(languageId: String) -> Bool
    func provideHighlightProviders(languageId: String) -> [any HighlightProviding]
}

// MARK: - Command

/// 编辑器命令上下文
@MainActor
struct EditorCommandContext {
    let languageId: String
    let hasSelection: Bool
    let line: Int
    let character: Int
}

struct EditorCommandShortcut: Equatable {
    enum Modifier: String, CaseIterable, Codable, Sendable {
        case command
        case shift
        case option
        case control

        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .shift: return "⇧"
            case .option: return "⌥"
            case .control: return "⌃"
            }
        }
    }

    let key: String
    let modifiers: [Modifier]

    var displayText: String {
        modifiers.map(\.symbol).joined() + key.uppercased()
    }
}

/// 编辑器命令建议
@MainActor
struct EditorCommandSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let category: String?
    let shortcut: EditorCommandShortcut?
    let order: Int
    let isEnabled: Bool
    let action: () -> Void

    init(
        id: String,
        title: String,
        systemImage: String,
        category: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        order: Int,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.category = category
        self.shortcut = shortcut
        self.order = order
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// 编辑器命令扩展点
@MainActor
protocol SuperEditorCommandContributor: AnyObject {
    var id: String { get }
    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion]
}

/// 编辑器右键菜单建议
@MainActor
struct EditorContextMenuItemSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let category: String?
    let shortcut: EditorCommandShortcut?
    let order: Int
    let isEnabled: Bool
    let metadata: EditorContributionMetadata
    let action: () -> Void

    init(
        id: String,
        title: String,
        systemImage: String,
        category: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        order: Int,
        isEnabled: Bool,
        metadata: EditorContributionMetadata = .init(),
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.category = category
        self.shortcut = shortcut
        self.order = order
        self.isEnabled = isEnabled
        self.metadata = metadata
        self.action = action
    }

    init(command suggestion: EditorCommandSuggestion) {
        self.init(
            id: suggestion.id,
            title: suggestion.title,
            systemImage: suggestion.systemImage,
            category: suggestion.category,
            shortcut: suggestion.shortcut,
            order: suggestion.order,
            isEnabled: suggestion.isEnabled,
            metadata: .init(priority: suggestion.order, dedupeKey: suggestion.id),
            action: suggestion.action
        )
    }

    var asCommandSuggestion: EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: id,
            title: title,
            systemImage: systemImage,
            category: category,
            shortcut: shortcut,
            order: order,
            isEnabled: isEnabled,
            action: action
        )
    }
}

/// 编辑器右键菜单扩展点
@MainActor
protocol SuperEditorContextMenuContributor: AnyObject {
    var id: String { get }
    func provideContextMenuItems(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorContextMenuItemSuggestion]
}

// MARK: - Gutter Decoration

/// 编辑器 decoration 扩展点
///
/// 当前先以 gutter decoration 作为第一批稳定 surface。
/// 后续如果扩展到 inline / block / overlay decoration，可以继续在这个语义层上外扩。
@MainActor
protocol SuperEditorDecorationContributor: SuperEditorGutterDecorationContributor {}

@MainActor
protocol SuperEditorGutterDecorationContributor: AnyObject {
    var id: String { get }
    func provideGutterDecorations(
        context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion]
}

// MARK: - Panel

@MainActor
enum EditorPanelPlacement: String, Equatable {
    case sheet
    case bottom
}

/// 编辑器统一面板建议
///
/// 用于把 sheet 与 bottom panel 收口到一个统一 contribution point。
/// 旧的 `SuperEditorSheetContributor` 仍然保留，便于渐进迁移。
@MainActor
struct EditorPanelSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let placement: EditorPanelPlacement
    let order: Int
    let metadata: EditorContributionMetadata
    let isPresented: (EditorState) -> Bool
    let onDismiss: (EditorState) -> Void
    let content: (EditorState) -> AnyView

    init(
        id: String,
        title: String,
        systemImage: String,
        placement: EditorPanelPlacement,
        order: Int,
        metadata: EditorContributionMetadata = .init(),
        isPresented: @escaping (EditorState) -> Bool,
        onDismiss: @escaping (EditorState) -> Void,
        content: @escaping (EditorState) -> AnyView
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
        self.order = order
        self.metadata = metadata
        self.isPresented = isPresented
        self.onDismiss = onDismiss
        self.content = content
    }
}

/// 编辑器统一面板扩展点
@MainActor
protocol SuperEditorPanelContributor: AnyObject {
    var id: String { get }
    func providePanels(state: EditorState) -> [EditorPanelSuggestion]
}

// MARK: - Settings

/// 编辑器设置项建议
///
/// 用于把内置 editor settings 与插件贡献设置收口到统一展示模型。
@MainActor
struct EditorSettingsItemSuggestion: Identifiable {
    let id: String
    let sectionTitle: String
    let sectionSummary: String?
    let title: String
    let subtitle: String?
    let keywords: [String]
    let order: Int
    let metadata: EditorContributionMetadata
    let content: (EditorSettingsState) -> AnyView

    init(
        id: String,
        sectionTitle: String,
        sectionSummary: String? = nil,
        title: String,
        subtitle: String? = nil,
        keywords: [String] = [],
        order: Int,
        metadata: EditorContributionMetadata = .init(),
        content: @escaping (EditorSettingsState) -> AnyView
    ) {
        self.id = id
        self.sectionTitle = sectionTitle
        self.sectionSummary = sectionSummary
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.order = order
        self.metadata = metadata
        self.content = content
    }
}

/// 编辑器设置项扩展点
@MainActor
protocol SuperEditorSettingsContributor: AnyObject {
    var id: String { get }
    func provideSettingsItems(state: EditorSettingsState) -> [EditorSettingsItemSuggestion]
}

// MARK: - Sheet

/// 编辑器弹窗建议（Sheet）
@MainActor
struct EditorSheetSuggestion: Identifiable {
    let id: String
    let order: Int
    let isPresented: (EditorState) -> Bool
    let onDismiss: (EditorState) -> Void
    let content: (EditorState) -> AnyView
}

/// 编辑器弹窗扩展点（Sheet）
@MainActor
protocol SuperEditorSheetContributor: AnyObject {
    var id: String { get }
    func provideSheets(state: EditorState) -> [EditorSheetSuggestion]
}

// MARK: - Status Item

/// 编辑器状态项建议
///
/// 统一描述 toolbar 与 title 区的可插拔状态项。旧的 `SuperEditorToolbarContributor`
/// 仍然保留，并由注册中心桥接到这个 contract，便于渐进迁移。
@MainActor
struct EditorStatusItemSuggestion: Identifiable {
    enum Placement: String, Equatable {
        case toolbarCenter
        case toolbarTrailing
        case titleTrailing
    }

    let id: String
    let order: Int
    let placement: Placement
    let metadata: EditorContributionMetadata
    let content: (EditorState) -> AnyView

    init(
        id: String,
        order: Int,
        placement: Placement,
        metadata: EditorContributionMetadata = .init(),
        content: @escaping (EditorState) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.metadata = metadata
        self.content = content
    }
}

/// 编辑器状态项扩展点
@MainActor
protocol SuperEditorStatusItemContributor: AnyObject {
    var id: String { get }
    func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion]
}

// MARK: - Quick Open

/// 编辑器 Quick Open 建议
///
/// 用于统一文件、符号、命令等可搜索入口在 command palette 风格界面中的展示合同。
@MainActor
struct EditorQuickOpenItemSuggestion: Identifiable {
    let id: String
    let sectionTitle: String
    let title: String
    let subtitle: String?
    let systemImage: String
    let badge: String?
    let order: Int
    let isEnabled: Bool
    let metadata: EditorContributionMetadata
    let action: () -> Void

    init(
        id: String,
        sectionTitle: String,
        title: String,
        subtitle: String?,
        systemImage: String,
        badge: String? = nil,
        order: Int,
        isEnabled: Bool,
        metadata: EditorContributionMetadata = .init(),
        action: @escaping () -> Void
    ) {
        self.id = id
        self.sectionTitle = sectionTitle
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.badge = badge
        self.order = order
        self.isEnabled = isEnabled
        self.metadata = metadata
        self.action = action
    }
}

/// 编辑器 Quick Open 扩展点
@MainActor
protocol SuperEditorQuickOpenContributor: AnyObject {
    var id: String { get }
    func provideQuickOpenItems(
        query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion]
}

// MARK: - Toolbar

/// 编辑器工具栏项建议
@MainActor
struct EditorToolbarItemSuggestion: Identifiable {
    enum Placement {
        case center
        case trailing
    }

    let id: String
    let order: Int
    let placement: Placement
    let content: (EditorState) -> AnyView

    init(
        id: String,
        order: Int,
        placement: Placement,
        content: @escaping (EditorState) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.content = content
    }

    init(statusItem suggestion: EditorStatusItemSuggestion) {
        self.init(
            id: suggestion.id,
            order: suggestion.order,
            placement: suggestion.placement == .toolbarCenter ? .center : .trailing,
            content: suggestion.content
        )
    }
}

/// 编辑器工具栏扩展点
@MainActor
protocol SuperEditorToolbarContributor: AnyObject {
    var id: String { get }
    func provideToolbarItems(state: EditorState) -> [EditorToolbarItemSuggestion]
}

// MARK: - Interaction

/// 编辑器交互上下文（文本/选区变化）
@MainActor
struct EditorInteractionContext {
    let languageId: String
    let line: Int
    let character: Int
    let typedCharacter: String?
}

/// 编辑器交互扩展点
@MainActor
protocol SuperEditorInteractionContributor: AnyObject {
    var id: String { get }
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
}

extension SuperEditorInteractionContributor {
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}

    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}
}
