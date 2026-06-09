import Foundation
import EditorKernel
import EditorPanelPlugin
import EditorService
import LanguageServerProtocol

// MARK: - Folding Range Provider

/// 代码折叠范围提供者
@MainActor
public final class FoldingRangeProvider: ObservableObject, SuperEditorFoldingRangeProvider {
    private let lspService: LSPService
    private let requestRangesOperation: @Sendable (_ uri: String) async -> [FoldingRange]
    private let requestLifecycle = LSPRequestLifecycle()

    public init(
        lspService: LSPService = .shared,
        requestRangesOperation: (@Sendable (_ uri: String) async -> [FoldingRange])? = nil
    ) {
        self.lspService = lspService
        self.requestRangesOperation = requestRangesOperation ?? { [lspService] uri in
            await lspService.requestFoldingRange(uri: uri)
        }
    }
    
    @Published public var ranges: [FoldingRangeItem] = []
    
    public var isAvailable: Bool { lspService.isAvailable }
    
    public func requestRanges(uri: String) async {
        requestLifecycle.run(
            operation: { [requestRangesOperation] in
                await requestRangesOperation(uri)
            },
            apply: { [weak self] serverRanges in
                guard let self else { return }
                ranges = serverRanges.map { range in
                    FoldingRangeItem(
                        startLine: Int(range.startLine),
                        endLine: Int(range.endLine),
                        startCharacter: range.startCharacter.map { Int($0) },
                        kind: range.kind,
                        collapsedText: nil
                    )
                }
                ranges.sort { $0.startLine < $1.startLine }
            }
        )
    }
    
    public func clear() {
        requestLifecycle.reset()
        ranges.removeAll()
    }

    public func reset() {
        requestLifecycle.reset()
    }
}
