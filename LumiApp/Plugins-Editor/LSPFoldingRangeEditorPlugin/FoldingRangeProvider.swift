import Foundation
import LanguageServerProtocol

// MARK: - Folding Range Provider

/// 代码折叠范围提供者
@MainActor
final class FoldingRangeProvider: ObservableObject {
    
    private let lspService: LSPService

    init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    @Published var ranges: [FoldingRangeItem] = []
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func requestRanges(uri: String) async {
        let serverRanges = await lspService.requestFoldingRange(uri: uri)
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
    
    func clear() { ranges.removeAll() }
}

struct FoldingRangeItem: Identifiable, Hashable {
    let id = UUID()
    let startLine: Int
    let endLine: Int
    let startCharacter: Int?
    let kind: FoldingRangeKind?
    var collapsedText: String?
    
    var isComment: Bool { kind == .comment }
    var isImports: Bool { kind == .imports }
    var isRegion: Bool { kind == .region }
    var hiddenLineCount: Int { max(0, endLine - startLine) }
}
