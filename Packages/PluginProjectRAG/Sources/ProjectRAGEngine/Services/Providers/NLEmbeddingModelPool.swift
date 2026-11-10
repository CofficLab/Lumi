import Foundation
import NaturalLanguage

/// NLEmbedding 模型池
///
/// ## 线程安全约束（务必阅读）
///
/// `NLEmbedding` 实例**不是线程安全的**：并发调用同一实例的 `vector(for:)`
/// 会在 `Montreal MRLNeuralNetworkSetInput` 内破坏堆内存
/// （`libsystem_malloc: BUG IN CLIENT OF LIBMALLOC: memory corruption of free block`），
/// 表现为随机崩溃或静默的数据损坏。
///
/// 因此本池按「泳道（lane）」分配资源：每个泳道独占一组模型实例与一个
/// `NLLanguageRecognizer`，同一时刻只允许一个调用方持有并使用该泳道。
/// 借出与归还通过条件变量串行化；池满时等待归还，而不是退化到共享实例。
///
/// ## 为什么需要缓存
///
/// `NLEmbedding.sentenceEmbedding(for:)` 每次调用都会返回**新的实例**
/// （`a !== b`），且模型是惰性加载的。新建实例意味着重复加载模型，
/// 实测可占掉约 45% 的向量化耗时。缓存让同一泳道内的同一语言始终复用同一实例。
///
/// ## 关于「模型不存在」
///
/// 部分语言（如 `traditionalChinese`）没有可用的嵌入模型。首次查询得到 `nil`
/// 时会记入「已知缺失」集合，避免每次嵌入都重复发起无效查询。
final class NLEmbeddingModelPool: @unchecked Sendable {

    /// 独占资源组：模型缓存 + 语言识别器。
    ///
    /// `NLLanguageRecognizer` 同样不可跨线程共享，故随泳道一起独占。
    final class Lane {
        /// 语言识别器，复用前需 `reset()`。
        let recognizer = NLLanguageRecognizer()

        /// 缓存的句子级模型，按语言索引。
        private var sentenceModels: [NLLanguage: NLEmbedding] = [:]

        /// 缓存的词级模型，按语言索引。
        private var wordModels: [NLLanguage: NLEmbedding] = [:]

        /// 已知没有句子级模型的语言。
        private var missingSentenceLanguages: Set<NLLanguage> = []

        /// 已知没有词级模型的语言。
        private var missingWordLanguages: Set<NLLanguage> = []

        /// 取得（并缓存）指定语言的句子级模型。
        ///
        /// - Returns: 模型；该语言无可用模型时返回 `nil`。
        func sentenceModel(for language: NLLanguage) -> NLEmbedding? {
            if let cached = sentenceModels[language] { return cached }
            if missingSentenceLanguages.contains(language) { return nil }
            guard let model = NLEmbedding.sentenceEmbedding(for: language) else {
                missingSentenceLanguages.insert(language)
                return nil
            }
            sentenceModels[language] = model
            return model
        }

        /// 取得（并缓存）指定语言的词级模型。
        ///
        /// - Returns: 模型；该语言无可用模型时返回 `nil`。
        func wordModel(for language: NLLanguage) -> NLEmbedding? {
            if let cached = wordModels[language] { return cached }
            if missingWordLanguages.contains(language) { return nil }
            guard let model = NLEmbedding.wordEmbedding(for: language) else {
                missingWordLanguages.insert(language)
                return nil
            }
            wordModels[language] = model
            return model
        }
    }

    private let condition = NSCondition()
    private var lanes: [Lane] = []
    private var availableIndices: [Int] = []

    /// 创建一个容量为 `capacity` 的模型池。
    ///
    /// - Parameter capacity: 泳道数量，即最多可同时使用的 NLEmbedding 实例数。
    ///   容量需覆盖「索引 + 查询」等可能并存的调用方，否则调用方会互相等待。
    init(capacity: Int) {
        let count = max(1, capacity)
        lanes = (0..<count).map { _ in Lane() }
        availableIndices = lanes.indices.reversed()
    }

    /// 泳道总数。
    var capacity: Int { lanes.count }

    /// 借出一条泳道；池满时阻塞等待其它泳道归还。
    ///
    /// - Important: 返回的泳道**必须**在用完后通过 `release(_:)` 归还，
    ///   否则池会被耗尽并导致调用方永久阻塞。
    func borrow() -> Lane {
        condition.lock()
        while availableIndices.isEmpty {
            condition.wait()
        }
        let index = availableIndices.removeLast()
        condition.unlock()
        return lanes[index]
    }

    /// 归还泳道。
    func release(_ lane: Lane) {
        condition.lock()
        if let index = lanes.firstIndex(where: { $0 === lane }) {
            availableIndices.append(index)
        }
        condition.signal()
        condition.unlock()
    }
}
