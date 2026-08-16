import Combine
import Foundation
import KernelLumi

/// Problems 视图模型：订阅 KernelLumi V2 诊断/文档状态并暴露操作。
@MainActor
public final class ProblemsEditorModel: ObservableObject {
    @Published public private(set) var diagnostics: [EditorDiagnosticItem] = []
    @Published public private(set) var activeDocumentURI: URL?

    public let editor: any EditorProvidingV2

    private var cancellables: Set<AnyCancellable> = []

    public init(editor: any EditorProvidingV2) {
        self.editor = editor
        diagnostics = editor.diagnostics.snapshot.diagnostics
        activeDocumentURI = editor.documents.activeDocument?.uri

        editor.diagnostics.statePublisher
            .receive(on: DispatchQueue.main)
            .map(\.diagnostics)
            .assign(to: &$diagnostics)
        editor.documents.statePublisher
            .receive(on: DispatchQueue.main)
            .map(\.activeDocument?.uri)
            .assign(to: &$activeDocumentURI)
    }

    // MARK: - Derived state

    public var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }

    /// 活动文档的显示用相对路径（V2 契约不暴露项目根，退化为文件名）。
    public var relativeFilePath: String {
        guard let uri = activeDocumentURI else { return "" }
        return uri.lastPathComponent
    }

    // MARK: - Actions

    /// 在编辑器中打开一条诊断对应的位置。
    public func open(_ item: EditorDiagnosticItem) {
        editor.navigation.open(
            EditorLocation(uri: item.documentURI, range: item.range),
            options: EditorOpenOptions()
        )
    }

    /// 收起底部 Problems 面板。
    public func closePanel() {
        editor.panels.presentBottomPanel(nil)
    }

    /// 展示底部 Problems 面板。
    public func presentPanel() {
        editor.panels.presentBottomPanel(.problems)
    }
}
