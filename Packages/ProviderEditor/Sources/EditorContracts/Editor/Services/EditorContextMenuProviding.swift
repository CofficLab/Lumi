import Foundation

/// 编辑器右键菜单上下文，不暴露 TextView/EditorService 等实现类型。
@MainActor
public struct EditorContextMenuContext {
    public let languageID: String
    public let fileURL: URL?
    public let projectRootPath: String?
    public let selectedText: String?
    public let documentText: String?
    public let selection: NSRange?
    public let isEditorActive: Bool
    public let isLargeFileMode: Bool

    public var hasSelection: Bool {
        guard let selectedText else { return false }
        return !selectedText.isEmpty
    }

    public init(
        languageID: String,
        fileURL: URL?,
        projectRootPath: String?,
        selectedText: String?,
        documentText: String?,
        selection: NSRange?,
        isEditorActive: Bool,
        isLargeFileMode: Bool
    ) {
        self.languageID = languageID
        self.fileURL = fileURL
        self.projectRootPath = projectRootPath
        self.selectedText = selectedText
        self.documentText = documentText
        self.selection = selection
        self.isEditorActive = isEditorActive
        self.isLargeFileMode = isLargeFileMode
    }
}

/// 一个由功能插件注入的右键菜单项。
@MainActor
public struct EditorContextMenuItem {
    public let id: String
    public let title: String
    public let systemImage: String
    public let category: String?
    public let order: Int
    public let priority: Int
    public let dedupeKey: String?
    public let isEnabled: Bool
    public let requiresSelection: Bool
    public let action: () -> Void

    public init(
        id: String,
        title: String,
        systemImage: String,
        category: String? = nil,
        order: Int = 0,
        priority: Int = 0,
        dedupeKey: String? = nil,
        isEnabled: Bool = true,
        requiresSelection: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.category = category
        self.order = order
        self.priority = priority
        self.dedupeKey = dedupeKey
        self.isEnabled = isEnabled
        self.requiresSelection = requiresSelection
        self.action = action
    }
}

/// 右键菜单贡献 Provider。
@MainActor
public protocol EditorContextMenuProviding: AnyObject {
    var id: String { get }
    func provideItems(context: EditorContextMenuContext) -> [EditorContextMenuItem]
}
