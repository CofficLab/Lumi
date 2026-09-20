import Combine
import Foundation
import ProviderEditor

/// Code editor 的最小状态模型。
///
/// ProjectProviding 是当前文件选择的唯一来源。插件启动时把当前文件和后续
/// `currentFileChanged` 事件转发到这里，由 ViewModel 驱动 EditorProviding 打开文档。
@MainActor
public final class CodeEditorViewModel: ObservableObject {
    public let editor: any EditorProviding

    @Published public private(set) var currentFileURL: URL?

    public init(editor: any EditorProviding) {
        self.editor = editor
    }

    /// 接收 ProjectProviding 的当前文件变更。
    public func updateCurrentFile(_ fileURL: URL?) {
        let normalizedURL = fileURL?.standardizedFileURL
        guard currentFileURL != normalizedURL else { return }

        currentFileURL = normalizedURL

        guard let normalizedURL else {
            closeActiveDocument()
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = try? await editor.documents.open(
                EditorOpenRequest(uri: normalizedURL, kind: .activate)
            )
        }
    }

    private func closeActiveDocument() {
        guard let activeDocument = editor.documents.activeDocument,
              let session = editor.sessions.state.allTabs.first(where: {
                  $0.documentID == activeDocument.id
              }) else {
            return
        }

        Task { @MainActor in
            _ = try? await editor.sessions.close(
                sessionID: session.id,
                policy: .discardChanges
            )
        }
    }
}
