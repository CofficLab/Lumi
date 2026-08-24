import Foundation

public enum RAGTextUtils {
    /// 中英文分词器
    public static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""

        for scalar in text.unicodeScalars {
            // CJK ideographs are members of `alphanumerics` but must still be
            // tokenized per-character; otherwise a run like "swift代码" collapses
            // into a single token and defeats keyword retrieval for Chinese.
            if scalar.isCJK {
                if !buffer.isEmpty {
                    tokens.append(buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
                tokens.append(String(scalar))
                continue
            }

            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if !buffer.isEmpty {
                tokens.append(buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            tokens.append(buffer)
        }
        return tokens
    }

    /// 计算词法匹配度（查询词在内容中的命中率）
    public static func lexicalBoost(query: String, content: String) -> Float {
        let tokens = tokenize(query.lowercased())
        guard !tokens.isEmpty else { return 0 }

        let lowerContent = content.lowercased()
        let hitCount = tokens.reduce(0) { partial, token in
            partial + (lowerContent.contains(token) ? 1 : 0)
        }
        return Float(hitCount) / Float(tokens.count)
    }

    /// 计算路径匹配度（查询词在文件路径中的命中率）
    public static func sourcePathBoost(queryTerms: [String], filePath: String) -> Float {
        guard !queryTerms.isEmpty else { return 0 }
        let lowerPath = filePath.lowercased()
        let hits = queryTerms.reduce(0) { $0 + (lowerPath.contains($1) ? 1 : 0) }
        return Float(hits) / Float(queryTerms.count)
    }
}
