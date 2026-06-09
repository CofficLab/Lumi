import Foundation
import EditorKernel
import EditorService
import LanguageServerProtocol

/// 选择范围扩展提供者
@MainActor
public final class SelectionRangeProvider: ObservableObject {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()

    public init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    @Published var rangeChain: [EditorSelectionRange] = []
    @Published var currentLevel: Int = -1
    
    public var isAvailable: Bool { lspService.isAvailable }
    
    public func requestSelectionRanges(uri: String, line: Int, character: Int) async {
        requestLifecycle.run(
            operation: { [lspService] in
                await lspService.requestSelectionRange(uri: uri, line: line, character: character)
            },
            apply: { [weak self] serverRanges in
                guard let self else { return }
                guard let root = serverRanges.first else {
                    rangeChain = []
                    currentLevel = -1
                    return
                }
                rangeChain = flattenSelectionRange(root)
                currentLevel = rangeChain.isEmpty ? -1 : 0
            }
        )
    }
    
    public func expandSelection() -> EditorSelectionRange? {
        guard !rangeChain.isEmpty else { return nil }
        currentLevel = min(currentLevel + 1, rangeChain.count - 1)
        return rangeChain[currentLevel]
    }
    
    public func shrinkSelection() -> EditorSelectionRange? {
        guard !rangeChain.isEmpty else { return nil }
        currentLevel = max(currentLevel - 1, 0)
        return rangeChain[currentLevel]
    }
    
    public func reset() {
        requestLifecycle.reset()
        rangeChain = []
        currentLevel = -1
    }
    
    private func flattenSelectionRange(_ range: SelectionRange) -> [EditorSelectionRange] {
        var result: [EditorSelectionRange] = []
        var current: SelectionRange? = range
        while let node = current {
            result.append(EditorSelectionRange(
                startLine: Int(node.range.start.line),
                startCharacter: Int(node.range.start.character),
                endLine: Int(node.range.end.line),
                endCharacter: Int(node.range.end.character),
                kind: nil // SelectionRange struct in LSP lib doesn't have .kind
            ))
            current = node.parent
        }
        return result.reversed()
    }
}

public struct EditorSelectionRange: Identifiable, Hashable {
    public let id = UUID()
    public let startLine: Int
    public let startCharacter: Int
    public let endLine: Int
    public let endCharacter: Int
    public let kind: String?
    
    public var range: ClosedRange<Int> { startLine...endLine }
}
