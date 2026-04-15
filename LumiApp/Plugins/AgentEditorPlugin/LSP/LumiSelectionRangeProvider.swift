import Foundation
import LanguageServerProtocol

/// 选择范围扩展提供者
@MainActor
final class LumiSelectionRangeProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
    @Published var rangeChain: [LumiSelectionRange] = []
    @Published var currentLevel: Int = -1
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func requestSelectionRanges(uri: String, line: Int, character: Int) async {
        let serverRanges = await lspService.requestSelectionRange(uri: uri, line: line, character: character)
        guard let root = serverRanges.first else {
            rangeChain = []
            currentLevel = -1
            return
        }
        rangeChain = flattenSelectionRange(root)
        currentLevel = rangeChain.isEmpty ? -1 : 0
    }
    
    func expandSelection() -> LumiSelectionRange? {
        guard !rangeChain.isEmpty else { return nil }
        currentLevel = min(currentLevel + 1, rangeChain.count - 1)
        return rangeChain[currentLevel]
    }
    
    func shrinkSelection() -> LumiSelectionRange? {
        guard !rangeChain.isEmpty else { return nil }
        currentLevel = max(currentLevel - 1, 0)
        return rangeChain[currentLevel]
    }
    
    func reset() {
        rangeChain = []
        currentLevel = -1
    }
    
    private func flattenSelectionRange(_ range: SelectionRange) -> [LumiSelectionRange] {
        var result: [LumiSelectionRange] = []
        var current: SelectionRange? = range
        while let node = current {
            result.append(LumiSelectionRange(
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

struct LumiSelectionRange: Identifiable, Hashable {
    let id = UUID()
    let startLine: Int
    let startCharacter: Int
    let endLine: Int
    let endCharacter: Int
    let kind: String?
    
    var range: ClosedRange<Int> { startLine...endLine }
}
