import Foundation

/// 自然语言查询 → 实时搜索词。
///
/// 语义 embed 仍使用原始 query；这里的提取只服务词法/路径搜索，避免
/// 「怎么/功能」这类疑问词进入 rg 模式稀释命中。优先级：标识符 > 文件名 > CJK。
public enum RAGQueryAnalyzer {
    private static let maxTerms = 8

    private static let stopwords = [
        "为什么", "怎么", "如何", "请问", "一下", "什么", "哪些",
        "项目", "代码", "功能", "文件", "实现", "设计", "吗", "呢",
    ]

    private static let functionCharacters: Set<Character> = Set(
        "是的了吗呢啊吧么哪谁我你他她它就都也还要会能请帮给对从到为以及等个中里上下有和与或"
    )

    public static func extractTerms(query: String) -> [String] {
        let fileNameRegex = try? NSRegularExpression(pattern: "[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+")
        let identifierRegex = try? NSRegularExpression(pattern: "[A-Za-z_][A-Za-z0-9_]{2,}")
        let nsQuery = query as NSString
        let fullRange = NSRange(location: 0, length: nsQuery.length)

        var fileNames: [String] = []
        var fileRanges: [Range<String.Index>] = []
        for match in fileNameRegex?.matches(in: query, range: fullRange) ?? [] {
            guard let range = Range(match.range, in: query) else { continue }
            fileNames.append(String(query[range]))
            fileRanges.append(range)
        }

        var identifiers: [String] = []
        for match in identifierRegex?.matches(in: query, range: fullRange) ?? [] {
            guard let range = Range(match.range, in: query),
                  !fileRanges.contains(where: { $0.overlaps(range) }) else { continue }
            let word = String(query[range])
            if isSymbol(word) { identifiers.append(word) }
        }

        var cjkTerms: [String] = []
        var run = ""
        for scalar in query.unicodeScalars {
            if scalar.isCJK {
                run.unicodeScalars.append(scalar)
            } else if !run.isEmpty {
                cjkTerms.append(contentsOf: contentWords(in: run))
                run.removeAll(keepingCapacity: true)
            }
        }
        if !run.isEmpty {
            cjkTerms.append(contentsOf: contentWords(in: run))
        }

        var seen = Set<String>()
        let ordered = (identifiers + fileNames + cjkTerms).filter { seen.insert($0).inserted }
        guard !ordered.isEmpty else { return RAGTextUtils.tokenize(query) }
        return Array(ordered.prefix(maxTerms))
    }

    /// 普通英文单词（where/defined）不算标识符；内部大写、下划线或数字才算。
    private static func isSymbol(_ word: String) -> Bool {
        word.dropFirst().contains(where: \.isUppercase)
            || word.contains("_")
            || word.contains(where: \.isNumber)
    }

    /// 连续汉字段按停用词切分，保留内容词；单个虚词（是/的/了…）丢弃。
    private static func contentWords(in run: String) -> [String] {
        var fragments: [String] = []
        var current = ""
        var index = run.startIndex
        while index < run.endIndex {
            if let stop = stopwords.first(where: { run[index...].hasPrefix($0) }) {
                if !current.isEmpty {
                    fragments.append(current)
                    current = ""
                }
                index = run.index(index, offsetBy: stop.count)
            } else {
                current.append(run[index])
                index = run.index(after: index)
            }
        }
        if !current.isEmpty { fragments.append(current) }
        return fragments.filter { fragment in
            fragment.count >= 2 || !functionCharacters.contains(fragment.first!)
        }
    }
}