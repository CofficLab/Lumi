import Foundation
import os

/// 记忆检索服务
///
/// 使用纯本地策略检索相关记忆，不依赖外部 LLM 调用。
///
/// ## 检索策略
/// 1. **关键词匹配（40%）**：将 query 分词，在 name/description/content 中匹配
/// 2. **类型权重（20%）**：feedback 和 user 类型更可能通用
/// 3. **时效衰减（20%）**：半衰期 30 天，越新越好
/// 4. **命中密度（20%）**：单条记忆中被命中关键词的比例
actor MemoryRetrievalService: SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false

    static let shared = MemoryRetrievalService()

    /// 半衰期（天）
    private var halfLifeDays: Double {
        MemoryPluginLocalStore.shared.halfLifeDays
    }

    /// 类型权重
    private let typeWeights: [MemoryType: Double] = [
        .feedback: 1.0,
        .user: 0.8,
        .project: 0.5,
        .reference: 0.3,
    ]

    /// 停用词列表（中文+英文）
    private let stopWords: Set<String> = [
        // 英文
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "can", "shall", "to", "of", "in", "for",
        "on", "with", "at", "by", "from", "as", "into", "through", "during",
        "before", "after", "above", "below", "between", "under", "again",
        "further", "then", "once", "here", "there", "when", "where", "why",
        "how", "all", "each", "few", "more", "most", "other", "some", "such",
        "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very",
        "just", "don", "now", "i", "me", "my", "myself", "we", "our", "you",
        "your", "he", "him", "his", "she", "her", "it", "its", "they", "them",
        "their", "what", "which", "who", "this", "that", "these", "those", "am",
        // 中文
        "的", "了", "是", "在", "我", "有", "和", "就", "不", "人", "都", "一",
        "一个", "上", "也", "很", "到", "说", "要", "去", "你", "会", "着", "没有",
        "看", "好", "自己", "这", "那", "什么", "怎么", "为什么", "吗", "呢", "啊",
        "吧", "哦", "嗯", "他", "她", "它", "们", "这个", "那个",
    ]

    // MARK: - 检索

    /// 检索与查询相关的记忆
    ///
    /// - Parameters:
    ///   - query: 查询文本（通常是用户消息）
    ///   - scope: 作用域
    ///   - maxResults: 最大返回数量
    /// - Returns: 按相关性降序排列的记忆列表
    func findRelevant(
        query: String,
        scope: MemoryScope,
        maxResults: Int = 3
    ) async -> [MemoryItem] {
        let memories = await MemoryStorageService.shared.listMemories(scope: scope)

        guard !memories.isEmpty else { return [] }

        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return [] }

        // 为每条记忆计算相关性分数
        var scored: [(item: MemoryItem, score: Double)] = []

        for memory in memories {
            let score = calculateRelevanceScore(
                memory: memory,
                queryTerms: queryTerms
            )
            if score > 0 {
                scored.append((item: memory, score: score))
            }
        }

        // 按分数降序，取 top-K
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(maxResults)).map { $0.item }
    }

    // MARK: - 相关性计算

    private func calculateRelevanceScore(
        memory: MemoryItem,
        queryTerms: [String]
    ) -> Double {
        var totalScore: Double = 0

        // 1. 关键词匹配（40%）
        let keywordScore = keywordMatchScore(memory: memory, queryTerms: queryTerms)
        totalScore += keywordScore * 0.4

        // 2. 类型权重（20%）
        let typeScore = typeWeights[memory.type] ?? 0.5
        totalScore += typeScore * 0.2

        // 3. 时效衰减（20%）
        let ageScore = timeDecayScore(updatedAt: memory.updatedAt)
        totalScore += ageScore * 0.2

        // 4. 命中密度（20%）
        let densityScore = hitDensityScore(memory: memory, queryTerms: queryTerms)
        totalScore += densityScore * 0.2

        return totalScore
    }

    /// 关键词匹配分数
    private func keywordMatchScore(memory: MemoryItem, queryTerms: [String]) -> Double {
        let nameLower = memory.name.lowercased()
        let descLower = memory.description.lowercased()
        let contentLower = memory.content.lowercased()

        var matchedCount = 0
        for term in queryTerms {
            if nameLower.contains(term) {
                matchedCount += 3 // name 权重最高
            }
            if descLower.contains(term) {
                matchedCount += 2 // description 次之
            }
            if contentLower.contains(term) {
                matchedCount += 1 // content 最低
            }
        }

        // 归一化到 0-1
        let maxPossible = Double(queryTerms.count * 3)
        return maxPossible > 0 ? Double(matchedCount) / maxPossible : 0
    }

    /// 时效衰减分数（指数衰减，半衰期 30 天）
    private func timeDecayScore(updatedAt: Date) -> Double {
        let daysSinceUpdate = Date().timeIntervalSince(updatedAt) / 86400
        // 半衰期公式：score = 2^(-t/halfLife)
        return pow(2.0, -daysSinceUpdate / halfLifeDays)
    }

    /// 命中密度分数
    private func hitDensityScore(memory: MemoryItem, queryTerms: [String]) -> Double {
        let contentLower = memory.content.lowercased()
        let words = contentLower.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return 0 }

        var hitCount = 0
        for term in queryTerms {
            for word in words {
                if word.contains(term) || term.contains(word) {
                    hitCount += 1
                }
            }
        }

        // 归一化
        return min(1.0, Double(hitCount) / Double(max(words.count, queryTerms.count)))
    }

    // MARK: - 分词

    /// 简单分词：转小写、去停用词、过滤短词
    private func tokenize(_ text: String) -> [String] {
        // 转小写并分割
        let lowercased = text.lowercased()

        // 简单分词：按空格和标点分割
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet.punctuationCharacters)
        var terms = lowercased
            .components(separatedBy: separators)
            .filter { !$0.isEmpty && $0.count > 1 }

        // 去停用词
        terms = terms.filter { !stopWords.contains($0) }

        // 去重
        return Array(Set(terms))
    }

    private nonisolated func logInfo(_ message: String) {
        AppLogger.core.info("[MemoryRetrieval][INFO] \(message)")
    }
}
