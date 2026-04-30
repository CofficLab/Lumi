import Foundation
import AppKit
import CodeEditLanguages
import LanguageServerProtocol

/// 编辑器文件状态
///
/// 管理当前文件的元数据、内容、语言检测、编辑状态等。
/// 与 UI 配置和面板状态解耦。
///
/// ## 职责范围
/// - 文件 URL、内容（NSTextStorage）、文件名/扩展名
/// - 文件类型检测（文本/二进制、是否可编辑/截断）
/// - 语言检测（CodeLanguage）
/// - 编辑状态（未保存变更、保存状态）
/// - 文件总行数
///
/// ## 线程模型
/// 标记 `@MainActor`，所有属性更新在主线程执行。
@MainActor
final class EditorFileState: ObservableObject {

    // MARK: - 文件信息

    /// 当前文件 URL
    @Published var currentFileURL: URL?

    /// 当前文件内容（NSTextStorage，CodeEditSourceEditor 要求）
    @Published var content: NSTextStorage?

    /// 文件名
    @Published var fileName: String = ""

    /// 文件扩展名
    @Published var fileExtension: String = ""

    /// 检测到的语言
    @Published var detectedLanguage: CodeLanguage?

    // MARK: - 文件类型

    /// 当前文件是否可编辑
    @Published var isEditable: Bool = true

    /// 当前文件是否为截断预览
    @Published var isTruncated: Bool = false

    /// 当前文件是否可预览
    @Published var canPreview: Bool = false

    /// 当前文件是否为 Markdown 格式
    var isMarkdownFile: Bool {
        fileExtension == "md" || fileExtension == "mdx"
    }

    /// 当前文件是否为二进制/非文本文件
    @Published var isBinaryFile: Bool = false

    // MARK: - 编辑状态

    /// 是否有未保存的变更
    @Published var hasUnsavedChanges: Bool = false

    /// 保存状态
    @Published var saveState: EditorSaveState = .idle

    /// 总行数
    @Published var totalLines: Int = 0

    // MARK: - 持久化

    /// 上次持久化的内容快照（用于检测变更）
    var persistedContentSnapshot: String?

    // MARK: - 计算属性

    /// 当前文件相对于项目根目录的路径
    func relativeFilePath(projectRootPath: String?) -> String {
        guard let url = currentFileURL else { return "" }
        guard let projectPath = projectRootPath else {
            return url.lastPathComponent
        }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectPath) else {
            return url.lastPathComponent
        }
        var relative = String(absolutePath.dropFirst(projectPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative
    }

    // MARK: - 重置

    func reset() {
        currentFileURL = nil
        content = nil
        persistedContentSnapshot = nil
        fileName = ""
        fileExtension = ""
        detectedLanguage = nil
        isEditable = true
        isTruncated = false
        canPreview = false
        isBinaryFile = false
        hasUnsavedChanges = false
        saveState = .idle
        totalLines = 0
    }
}

// MARK: - 保存状态

enum EditorSaveState: Equatable {
    case idle
    case editing
    case saving
    case saved
    case conflict(String)
    case error(String)

    var icon: String {
        switch self {
        case .idle: return "checkmark.circle"
        case .editing: return "pencil.circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .saved: return "checkmark.circle.fill"
        case .conflict: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .idle: return String(localized: "No Changes", table: "LumiEditor")
        case .editing: return String(localized: "Editing...", table: "LumiEditor")
        case .saving: return String(localized: "Saving...", table: "LumiEditor")
        case .saved: return String(localized: "Saved", table: "LumiEditor")
        case .conflict(let msg): return msg
        case .error(let msg): return msg
        }
    }

    var shortLabel: String {
        switch self {
        case .idle: return String(localized: "No Changes", table: "LumiEditor")
        case .editing: return String(localized: "Editing...", table: "LumiEditor")
        case .saving: return String(localized: "Saving...", table: "LumiEditor")
        case .saved: return String(localized: "Saved", table: "LumiEditor")
        case .conflict: return "External Change"
        case .error: return "Save Failed"
        }
    }
}
