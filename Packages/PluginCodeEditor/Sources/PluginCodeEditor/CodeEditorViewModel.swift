import Combine
import EditorService
import Foundation

/// Code editor 的最小状态模型。
///
/// ProjectProviding 是当前文件选择的唯一来源。插件启动时把当前文件和后续
/// `currentFileChanged` 事件转发到这里，由 ViewModel 驱动 EditorService 加载内容。
@MainActor
public final class CodeEditorViewModel: ObservableObject {
    public let editor: EditorService

    @Published public private(set) var currentFileURL: URL?

    public init(editor: EditorService) {
        self.editor = editor
    }

    /// 接收 ProjectProviding 的当前文件变更。
    public func updateCurrentFile(_ fileURL: URL?) {
        let normalizedURL = fileURL?.standardizedFileURL
        guard currentFileURL != normalizedURL else { return }

        currentFileURL = normalizedURL
        editor.files.loadFile(from: normalizedURL)
    }
}
