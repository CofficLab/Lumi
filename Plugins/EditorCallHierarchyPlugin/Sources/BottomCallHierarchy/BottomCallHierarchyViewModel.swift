import Combine
import Foundation
import KernelLumi

/// Call Hierarchy 面板视图模型：订阅 KernelLumi V2 调用层级状态并暴露操作。
@MainActor
public final class BottomCallHierarchyViewModel: ObservableObject {
    @Published public private(set) var state: EditorCallHierarchyState = .empty

    private let editor: any EditorProvidingV2
    private var cancellables: Set<AnyCancellable> = []

    public init(editor: any EditorProvidingV2) {
        self.editor = editor
        state = editor.callHierarchy.hierarchy
        editor.callHierarchy.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }

    /// 以当前活动文档光标位置准备调用层级（root = 光标处符号）。
    public func prepareFromCursor() {
        guard let document = editor.documents.activeDocument,
              let cursor = editor.selections.snapshot.selections.first?.active else {
            return
        }
        editor.callHierarchy.prepare(uri: document.uri, position: cursor)
    }

    /// 请求某节点的调用者（incoming calls）。
    public func fetchIncomingCalls(for node: EditorCallHierarchyNode) {
        editor.callHierarchy.fetchIncomingCalls(node: node)
    }

    /// 请求某节点的被调用者（outgoing calls）。
    public func fetchOutgoingCalls(for node: EditorCallHierarchyNode) {
        editor.callHierarchy.fetchOutgoingCalls(node: node)
    }

    /// 在编辑器中打开一个符号节点。
    public func open(_ node: EditorCallHierarchyNode) {
        editor.navigation.open(node.location, options: EditorOpenOptions())
    }

    /// 收起底部调用层级面板并清空会话。
    public func close() {
        editor.callHierarchy.clear()
        editor.panels.presentBottomPanel(nil)
    }
}
