import Combine
import Foundation

// MARK: - 文档符号能力（契约 V2，§8）

/// 文档符号数据面：当前文档符号树 + 变更流。
@MainActor
public protocol EditorDocumentSymbolProviding: AnyObject {
    /// 当前活动文档的符号树（无文档/无 Provider 时为空）。
    var activeSymbols: [EditorDocumentSymbol] { get }

    /// 是否正在加载（LSP 请求进行中）。
    var isLoading: Bool { get }

    /// 活动文档符号变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorDocumentSymbolsState, Never> { get }

    /// 请求刷新活动文档符号（Host 自行决定请求时机与去抖）。
    func refresh()
}

/// 文档符号观察状态。
public struct EditorDocumentSymbolsState: Equatable, Sendable {
    public let symbols: [EditorDocumentSymbol]
    public let isLoading: Bool

    public init(symbols: [EditorDocumentSymbol], isLoading: Bool) {
        self.symbols = symbols
        self.isLoading = isLoading
    }

    public static let empty = EditorDocumentSymbolsState(symbols: [], isLoading: false)
}
