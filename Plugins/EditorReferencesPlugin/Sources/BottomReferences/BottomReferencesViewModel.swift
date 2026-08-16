import Combine
import Foundation
import KernelLumi

/// References 面板视图模型：订阅 KernelLumi V2 引用状态并暴露操作。
@MainActor
public final class BottomReferencesViewModel: ObservableObject {
    @Published public private(set) var state: EditorReferencesState = .empty

    private let editor: any EditorProvidingV2
    private var cancellables: Set<AnyCancellable> = []

    public init(editor: any EditorProvidingV2) {
        self.editor = editor
        state = editor.references.references
        editor.references.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }

    /// 在编辑器中打开一条引用结果。
    public func open(_ item: EditorReferenceItem) {
        editor.navigation.open(item.location, options: EditorOpenOptions())
    }

    /// 收起底部引用面板。
    public func close() {
        editor.panels.presentBottomPanel(nil)
    }
}
