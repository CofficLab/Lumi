import Foundation

enum RAGTextUtils {
    /// 中英文分词器
    /// - Parameter text: 输入文本
    /// - Returns: 分词后的数组
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if !buffer.isEmpty {
                tokens.append(buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if scalar.isCJK {
                tokens.append(String(scalar))
            }
        }

        if !buffer.isEmpty {
            tokens.append(buffer)
        }
        return tokens
    }

    /// 计算词法匹配度（查询词在内容中的命中率）
    /// - Parameters:
    ///   - query: 查询文本
    ///   - content: 目标内容
    /// - Returns: 匹配度（0-1之间）
    static func lexicalBoost(query: String, content: String) -> Float {
        let tokens = tokenize(query.lowercased())
        guard !tokens.isEmpty else { return 0 }

        let lowerContent = content.lowercased()
        let hitCount = tokens.reduce(0) { partial, token in
            partial + (lowerContent.contains(token) ? 1 : 0)
        }
        return Float(hitCount) / Float(tokens.count)
    }

    /// 计算路径匹配度（查询词在文件路径中的命中率）
    /// - Parameters:
    ///   - queryTerms: 查询词数组
    ///   - filePath: 文件路径
    /// - Returns: 匹配度（0-1之间）
    static func sourcePathBoost(queryTerms: [String], filePath: String) -> Float {
        guard !queryTerms.isEmpty else { return 0 }
        let lowerPath = filePath.lowercased()
        let hits = queryTerms.reduce(0) { $0 + (lowerPath.contains($1) ? 1 : 0) }
        return Float(hits) / Float(queryTerms.count)
    }
}
