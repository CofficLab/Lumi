import Foundation
import NaturalLanguage

/// Apple 原生向量化提供者
/// 使用系统内置的 NaturalLanguage 框架进行向量化
///
/// ## 性能与线程安全
///
/// `NLEmbedding` 的向量计算（内部走 `libBNNS` 神经网络推理）本身已是
/// 多核并行：实测单次 `vector(for:)` 的 CPU/墙钟比约 2~4，即已占用 2~4 个核心。
/// 因此**在本层再做并行化没有收益**，反而会因为多任务同时进入 `libBNNS`
/// 而放大对前台的 CPU 争抢。
///
/// 实测（8 条 4000 字符 chunk，串行 vs 本层并发 2/4）：
/// 串行 1.73s / 3.99 核，并发 2 为 1.56s / 4.27 核，并发 4 为 1.99s / 3.66 核。
/// 墙钟时间基本持平，CPU 总量不变——本层并发只是把同一份工作重新切分。
///
/// 本实现的优化点是**消除重复的模型加载与重复的语言识别**：
///
/// 1. `NLEmbedding.sentenceEmbedding(for:)` 每次调用都会返回**新实例**
///    且模型是惰性加载的，逐条新建会重复加载模型；
/// 2. `NLLanguageRecognizer` 每次新建都有语言模型加载成本；
/// 3. 部分语言（如 `traditionalChinese`）根本没有嵌入模型，逐条查询是纯粹的浪费。
///
/// 上述三点通过 `NLEmbeddingModelPool` 的独占泳道解决。
public struct AppleNativeEmbeddingProvider: RAGEmbeddingProvider {
    public let modelID: String
    public let modelVersion: String
    public let dimension: Int
    private let hashFallback: MockEmbeddingProvider

    /// 模型池。
    ///
    /// - Important: `NLEmbedding` 实例非线程安全（并发调用会破坏堆内存），
    ///   因此池按泳道独占实例，**不得**把单个实例暴露给多个并发调用方。
    private let pool: NLEmbeddingModelPool

    static let supportedNativeEmbeddingLanguages: Set<NLLanguage> = [
        .english,
        .simplifiedChinese,
        .traditionalChinese,
    ]

    /// 泳道数量。
    ///
    /// 覆盖「后台索引 + 前台查询」可能并存的场景即可：实测单次向量计算
    /// 已占用 2~4 核，再多只会加剧与前台的争抢。
    public static let defaultPoolCapacity = 2

    /// 使用句子级 embedding 的最大字符数。
    ///
    /// 句子级模型语义质量最好，但对整段文本做逐词神经网络推理，耗时与长度线性相关
    /// （实测 1850 字符 0.54s、7400 字符 2.05s、29600 字符 7.60s、74000 字符 19.78s）。
    /// 超过该阈值改用词级平均（快约 19 倍，语义分离度相当）。
    public static let sentenceEmbeddingMaxCharacters = 1_500

    public init(
        modelID: String = "apple-nl-proj",
        modelVersion: String = "v1",
        dimension: Int = 384,
        poolCapacity: Int = AppleNativeEmbeddingProvider.defaultPoolCapacity
    ) {
        let dim = max(dimension, 8)
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = dim
        self.hashFallback = MockEmbeddingProvider(modelID: "local-hash", modelVersion: "v1", dimension: dim)
        self.pool = NLEmbeddingModelPool(capacity: poolCapacity)
    }

    public func embed(_ text: String) throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [Float](repeating: 0, count: dimension) }

        // 尝试使用 Apple 原生引擎
        let lane = pool.borrow()
        defer { pool.release(lane) }
        if let raw = rawVector(for: trimmed, lane: lane), !raw.isEmpty {
            return projectedNormalized(raw: raw, dimension: dimension)
        }

        // 降级到哈希方案
        return try hashFallback.embed(trimmed)
    }

    // MARK: - Private Methods

    /// 使用 Apple NaturalLanguage 框架生成原始向量
    ///
    /// - Important: `lane` 由调用方独占持有，本方法内不得再并发使用同一泳道。
    private func rawVector(for text: String, lane: NLEmbeddingModelPool.Lane) -> [Double]? {
        lane.recognizer.reset()
        lane.recognizer.processString(text)
        let detected = lane.recognizer.dominantLanguage

        let candidates = Self.nativeEmbeddingCandidates(detected: detected)

        // 短文本优先用句子级 embedding——语义质量最好。
        //
        // - Note: `NLEmbedding.wordEmbedding` 的 `vector(for:)` **只接受单个词**，
        //   对多词文本一律返回 `nil`。因此不能把整段文本直接传给它，
        //   必须先分词、逐词求向量再求平均，否则降级路径形同虚设
        //   （会一路回退到无语义的 hash 向量）。
        if text.count <= Self.sentenceEmbeddingMaxCharacters,
           let vector = Self.sentenceVector(for: text, lane: lane, candidates: candidates) {
            return vector
        }

        // 长文本改用词级平均。
        //
        // 句子级模型对整段文本做**逐词**神经网络推理，耗时与文本长度线性相关：
        // 实测 1850 字符 0.54s、7400 字符 2.05s、29600 字符 7.60s、74000 字符 19.78s。
        // 词级模型只对单个词推理再求平均，耗时几乎与长度无关：
        // 实测 10 个 4000 字符 chunk，句子级 9.55s vs 词级平均 0.50s（快 19 倍）。
        return Self.wordLevelVector(for: text, lane: lane, candidates: candidates)
    }

    /// 句子级向量（按候选语言依次尝试）。
    private static func sentenceVector(
        for text: String,
        lane: NLEmbeddingModelPool.Lane,
        candidates: [NLLanguage]
    ) -> [Double]? {
        for lang in candidates {
            if let model = lane.sentenceModel(for: lang),
               let vector = model.vector(for: text) {
                return vector
            }
        }
        return nil
    }

    /// 词级向量（分词后逐词求向量再平均）。
    private static func wordLevelVector(
        for text: String,
        lane: NLEmbeddingModelPool.Lane,
        candidates: [NLLanguage]
    ) -> [Double]? {
        for lang in candidates {
            if let model = lane.wordModel(for: lang),
               let vector = averagedWordVector(for: text, model: model) {
                return vector
            }
        }
        return nil
    }

    /// 词级向量平均。
    ///
    /// 用 `NLTokenizer` 分词，对每个词求词级向量后取平均，得到与句子级向量
    /// 维度不同的但语义可用的表示。
    ///
    /// 性能对比（100 行文本）：句子级整段 0.81 s vs 词级逐词平均 0.038 s。
    ///
    /// - Returns: 平均后的词向量；无有效词时返回 `nil`。
    static func averagedWordVector(for text: String, model: NLEmbedding) -> [Double]? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var sums = [Double](repeating: 0, count: model.dimension)
        var tokenCount = 0

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            guard let vector = model.vector(for: token) else { return true }
            for index in 0..<min(vector.count, sums.count) {
                sums[index] += Double(vector[index])
            }
            tokenCount += 1
            return true
        }

        guard tokenCount > 0 else { return nil }
        return sums.map { $0 / Double(tokenCount) }
    }

    static func nativeEmbeddingCandidates(detected: NLLanguage?) -> [NLLanguage] {
        var candidates: [NLLanguage] = []
        if let detected, supportedNativeEmbeddingLanguages.contains(detected) {
            candidates.append(detected)
        }
        candidates.append(contentsOf: [.english, .simplifiedChinese, .traditionalChinese])

        var seen = Set<NLLanguage>()
        return candidates.filter { seen.insert($0).inserted }
    }

    /// 投影并归一化向量到指定维度
    private func projectedNormalized(raw: [Double], dimension: Int) -> [Float] {
        var output = [Float](repeating: 0, count: dimension)

        // 使用伪随机投影将原始向量映射到目标维度
        for (index, value) in raw.enumerated() {
            let bucket = index % dimension
            let sign: Float = ((index &* 1103515245 &+ 12345) & 1) == 0 ? 1 : -1
            output[bucket] += Float(value) * sign
        }

        // L2 归一化
        let norm = sqrt(output.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm > 0 else { return output }
        return output.map { $0 / norm }
    }
}
