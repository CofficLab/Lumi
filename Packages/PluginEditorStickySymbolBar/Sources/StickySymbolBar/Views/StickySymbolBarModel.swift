import Combine
import Foundation
import KernelLumi

/// Sticky Symbol Bar 视图模型：订阅 KernelLumi V2 符号/选择/文档状态并暴露操作。
@MainActor
public final class StickySymbolBarModel: ObservableObject {
    @Published public private(set) var symbols: [EditorDocumentSymbol] = []
    @Published public private(set) var isLoading = false
    /// 当前光标行（1-based）。
    @Published public private(set) var cursorLine: Int = 1
    @Published public private(set) var activeDocumentURI: URL?

    public let editor: any EditorProvidingV2

    public init(editor: any EditorProvidingV2) {
        self.editor = editor
        symbols = editor.documentSymbols.activeSymbols
        isLoading = editor.documentSymbols.isLoading
        cursorLine = Self.cursorLine(from: editor.selections.snapshot)
        activeDocumentURI = editor.documents.activeDocument?.uri

        editor.documentSymbols.statePublisher
            .receive(on: DispatchQueue.main)
            .map(\.symbols)
            .assign(to: &$symbols)
        editor.documentSymbols.statePublisher
            .receive(on: DispatchQueue.main)
            .map(\.isLoading)
            .assign(to: &$isLoading)
        editor.selections.statePublisher
            .receive(on: DispatchQueue.main)
            .map(Self.cursorLine(from:))
            .assign(to: &$cursorLine)
        editor.documents.statePublisher
            .receive(on: DispatchQueue.main)
            .map(\.activeDocument?.uri)
            .assign(to: &$activeDocumentURI)
    }

    /// 从选择快照推导 1-based 光标行。
    nonisolated private static func cursorLine(from snapshot: EditorSelectionSnapshot) -> Int {
        (snapshot.selections.first?.active.line ?? 0) + 1
    }

    // MARK: - Derived state

    /// 光标所在的符号层级路径（根到当前节点）。
    public var activeSymbolTrail: [EditorDocumentSymbol] {
        symbols.compactMap { $0.activePath(for: cursorLine) }
            .max(by: { $0.count < $1.count }) ?? []
    }

    // MARK: - Actions

    /// 跳转到某个符号（打开活动文档并选中该符号）。
    public func open(_ symbol: EditorDocumentSymbol) {
        guard let uri = activeDocumentURI else { return }
        editor.navigation.open(
            EditorLocation(uri: uri, range: symbol.selectionRange),
            options: EditorOpenOptions()
        )
    }
}

extension EditorDocumentSymbol {
    /// 与 EditorService 时代一致的符号图标映射。
    public var iconSymbol: String {
        switch kind {
        case .function: return "f.cursive"
        case .method: return "cube"
        case .constructor: return "plus.square"
        case .class: return "square.stack"
        case .interface: return "circle.square"
        case .struct: return "box"
        case .enum: return "list.bullet"
        case .enumMember: return "bullet"
        case .property: return "p.circle"
        case .constant: return "c.circle"
        case .field: return "f.circle"
        case .variable: return "text.word.spacing"
        default: return "doc"
        }
    }
}
