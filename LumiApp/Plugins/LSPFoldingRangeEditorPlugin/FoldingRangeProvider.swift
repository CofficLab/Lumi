import Foundation
import LanguageServerProtocol

// MARK: - Folding Range Provider

/// 代码折叠范围提供者
@MainActor
final class FoldingRangeProvider: ObservableObject, SuperEditorFoldingRangeProvider {
    private let lspService: LSPService
    private let requestRangesOperation: @Sendable (_ uri: String) async -> [FoldingRange]
    private let requestLifecycle = LSPRequestLifecycle()

    init(
        lspService: LSPService = .shared,
        requestRangesOperation: (@Sendable (_ uri: String) async -> [FoldingRange])? = nil
    ) {
        self.lspService = lspService
        self.requestRangesOperation = requestRangesOperation ?? { [lspService] uri in
            await lspService.requestFoldingRange(uri: uri)
        }
    }
    
    @Published var ranges: [FoldingRangeItem] = []
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func requestRanges(uri: String) async {
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
    
    func clear() {
        requestLifecycle.reset()
        ranges.removeAll()
    }

    func reset() {
        requestLifecycle.reset()
    }
}
