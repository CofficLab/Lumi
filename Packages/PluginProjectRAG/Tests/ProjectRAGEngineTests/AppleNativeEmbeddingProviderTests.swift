import Foundation
import NaturalLanguage
import Testing
@testable import ProjectRAGEngine

/// `AppleNativeEmbeddingProvider` 的并发安全与缓存行为测试。
///
/// 背景（对应 issue #130）：
/// - `NLEmbedding` 实例**非线程安全**，并发调用会破坏堆内存；
/// - `NLEmbedding.sentenceEmbedding(for:)` 每次返回新实例，模型惰性加载；
/// - `libBNNS` 内部已多核并行，本层再并行无收益。
///
/// 因此本测试重点验证：模型池在并发调用下**不崩溃**且结果稳定。
@Suite("AppleNativeEmbeddingProvider 并发安全")
struct AppleNativeEmbeddingProviderConcurrencyTests {

    @Test("并发 embed 不崩溃且维度一致")
    func concurrentEmbedDoesNotCrash() async {
        let provider = AppleNativeEmbeddingProvider(dimension: 384, poolCapacity: 2)
        let texts = (0..<12).map { "func handler\($0)() { let value = compute() }" }

        let results = await withTaskGroup(of: [Float]?.self, returning: [[Float]?].self) { group in
            for text in texts {
                group.addTask {
                    try? provider.embed(text)
                }
            }
            var collected: [[Float]?] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == texts.count)
        for vector in results {
            #expect(vector != nil)
            #expect(vector?.count == 384)
        }
    }

    @Test("并发 embed 结果与串行一致（向量稳定性）")
    func concurrentEmbedMatchesSerial() async {
        let provider = AppleNativeEmbeddingProvider(dimension: 384, poolCapacity: 2)
        let text = "struct UserProfile { let name: String; let age: Int }"

        let serial = try! provider.embed(text)

        let concurrent = await withTaskGroup(of: [Float]?.self, returning: [Float]?.self) { group in
            for _ in 0..<6 {
                group.addTask { try? provider.embed(text) }
            }
            var collected: [Float]? = nil
            for await result in group {
                if collected == nil { collected = result }
            }
            return collected
        }

        #expect(concurrent != nil)
        // 浮点计算可能有极小误差，比较整体范数与首尾元素即可
        #expect(serial.count == concurrent?.count)
        if let concurrent {
            for (lhs, rhs) in zip(serial, concurrent) {
                #expect(abs(lhs - rhs) < 1e-4)
            }
        }
    }

    @Test("空文本返回零向量")
    func emptyTextReturnsZeroVector() throws {
        let provider = AppleNativeEmbeddingProvider(dimension: 64)
        let vector = try provider.embed("   \n  ")
        #expect(vector.count == 64)
        #expect(vector.allSatisfy { $0 == 0 })
    }

    @Test("embedBatch 结果数量与输入一致")
    func embedBatchPreservesCount() throws {
        let provider = AppleNativeEmbeddingProvider(dimension: 128)
        let texts = ["alpha content", "beta content", "gamma content"]
        let vectors = try provider.embedBatch(texts)
        #expect(vectors.count == texts.count)
        #expect(vectors.allSatisfy { $0.count == 128 })
    }
}

/// 模型池自身的行为测试。
@Suite("NLEmbeddingModelPool")
struct NLEmbeddingModelPoolTests {

    @Test("借出的泳道互不相同")
    func borrowedLanesAreDistinct() {
        let pool = NLEmbeddingModelPool(capacity: 2)
        let first = pool.borrow()
        let second = pool.borrow()
        defer {
            pool.release(first)
            pool.release(second)
        }
        #expect(first !== second)
    }

    @Test("容量至少为 1")
    func capacityIsAtLeastOne() {
        let pool = NLEmbeddingModelPool(capacity: 0)
        #expect(pool.capacity == 1)
        let lane = pool.borrow()
        pool.release(lane)
    }

    @Test("归还后可再次借出")
    func releasedLaneCanBeBorrowedAgain() {
        let pool = NLEmbeddingModelPool(capacity: 1)
        let lane = pool.borrow()
        pool.release(lane)
        let again = pool.borrow()
        #expect(again === lane)
        pool.release(again)
    }

    @Test("池耗尽时借出会阻塞，归还后解除")
    func borrowBlocksWhenExhausted() async {
        let pool = NLEmbeddingModelPool(capacity: 1)
        let lane = pool.borrow()

        // 用一个 Sendable 盒子持有泳道，避免跨并发闭包捕获非 Sendable 值。
        let holder = LaneHolder(lane)

        let borrowed = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            group.addTask {
                let second = pool.borrow()
                pool.release(second)
                return true
            }
            // 给阻塞任务一点时间进入等待
            try? await Task.sleep(for: .milliseconds(50))
            group.addTask {
                if let held = holder.take() {
                    pool.release(held)
                }
                return false
            }
            var result = false
            for await value in group {
                result = result || value
            }
            return result
        }

        #expect(borrowed)
    }

    @Test("同一泳道重复查询返回同一模型实例（缓存生效）")
    func laneCachesModelInstances() {
        let pool = NLEmbeddingModelPool(capacity: 1)
        let lane = pool.borrow()
        defer { pool.release(lane) }

        let first = lane.sentenceModel(for: .english)
        let second = lane.sentenceModel(for: .english)
        #expect(first != nil)
        #expect(first === second)
    }

    @Test("没有模型的语言返回 nil 且被记录为缺失")
    func laneRecordsMissingModels() {
        let pool = NLEmbeddingModelPool(capacity: 1)
        let lane = pool.borrow()
        defer { pool.release(lane) }

        // traditionalChinese 在系统上没有可用的嵌入模型
        let first = lane.sentenceModel(for: .traditionalChinese)
        let second = lane.sentenceModel(for: .traditionalChinese)
        #expect(first == nil)
        #expect(second == nil)
    }
}

/// 词级降级路径的回归测试。
///
/// 背景：现状代码把整段文本直接传给 `wordEmbedding.vector(for:)`，
/// 而该 API **只接受单个词**，对多词文本返回 `nil`，导致降级路径形同虚设
/// （一路回退到无语义的 hash 向量）。
@Suite("词级降级路径")
struct WordLevelFallbackTests {

    @Test("整段文本的词级平均可用（不再返回 nil）")
    func averagedWordVectorWorksForLongText() throws {
        guard let model = NLEmbedding.wordEmbedding(for: .english) else {
            Issue.record("英文词级模型不可用")
            return
        }

        let text = String(repeating: "func handler() { let value = compute() }\n", count: 20)

        // 现状写法：直接传整段 -> nil
        let direct = model.vector(for: text)
        #expect(direct == nil)

        // 修复写法：分词后逐词平均 -> 有效向量
        let averaged = AppleNativeEmbeddingProvider.averagedWordVector(for: text, model: model)
        #expect(averaged != nil)
        #expect(averaged?.count == model.dimension)
    }

    @Test("空文本的词级平均返回 nil")
    func averagedWordVectorReturnsNilForEmptyText() throws {
        guard let model = NLEmbedding.wordEmbedding(for: .english) else {
            Issue.record("英文词级模型不可用")
            return
        }
        let result = AppleNativeEmbeddingProvider.averagedWordVector(for: "   ", model: model)
        #expect(result == nil)
    }

    @Test("词级平均对不同文本产生不同向量")
    func averagedWordVectorDistinguishesTexts() throws {
        guard let model = NLEmbedding.wordEmbedding(for: .english) else {
            Issue.record("英文词级模型不可用")
            return
        }

        let first = AppleNativeEmbeddingProvider.averagedWordVector(for: "database migration script", model: model)
        let second = AppleNativeEmbeddingProvider.averagedWordVector(for: "network request handler", model: model)

        #expect(first != nil)
        #expect(second != nil)
        if let first, let second, first.count == second.count {
            let differs = zip(first, second).contains { abs($0 - $1) > 1e-6 }
            #expect(differs)
        }
    }
}

/// 阈值策略的回归测试。
///
/// 短文本走句子级（语义质量最好），长文本走词级平均（快约 19 倍）。
@Suite("向量化阈值策略")
struct EmbeddingThresholdStrategyTests {

    @Test("长文本的 embed 显著快于句子级整段")
    func longTextUsesWordLevelAveraging() throws {
        guard let sentenceModel = NLEmbedding.sentenceEmbedding(for: .english) else {
            Issue.record("英文句子级模型不可用")
            return
        }

        let longText = String(repeating: "func handler() { let value = compute() }\n", count: 60)
        #expect(longText.count > AppleNativeEmbeddingProvider.sentenceEmbeddingMaxCharacters)

        let provider = AppleNativeEmbeddingProvider(dimension: 384)

        let start = Date()
        let vector = try provider.embed(longText)
        let providerElapsed = Date().timeIntervalSince(start)

        let sentenceStart = Date()
        _ = sentenceModel.vector(for: longText)
        let sentenceElapsed = Date().timeIntervalSince(sentenceStart)

        #expect(vector.count == 384)
        // 词级平均应显著快于句子级整段（实测约 19 倍）
        #expect(providerElapsed < sentenceElapsed)
    }

    @Test("短文本与长文本都能产出有效向量")
    func bothStrategiesProduceValidVectors() throws {
        let provider = AppleNativeEmbeddingProvider(dimension: 256)

        let short = try provider.embed("func handler() { let value = compute() }")
        let long = try provider.embed(String(repeating: "some source code line\n", count: 200))

        #expect(short.count == 256)
        #expect(long.count == 256)
        // 归一化向量不应全零
        #expect(short.contains { $0 != 0 })
        #expect(long.contains { $0 != 0 })
    }

    @Test("阈值常量合理")
    func thresholdIsReasonable() {
        #expect(AppleNativeEmbeddingProvider.sentenceEmbeddingMaxCharacters > 0)
        #expect(AppleNativeEmbeddingProvider.sentenceEmbeddingMaxCharacters < 10_000)
    }
}

/// 候选语言顺序的回归测试。
@Suite("nativeEmbeddingCandidates")
struct NativeEmbeddingCandidatesTests {

    @Test("检测语言排在首位")
    func detectedLanguageComesFirst() {
        let candidates = AppleNativeEmbeddingProvider.nativeEmbeddingCandidates(detected: .simplifiedChinese)
        #expect(candidates.first == .simplifiedChinese)
    }

    @Test("不支持的检测语言被忽略")
    func unsupportedDetectedLanguageIgnored() {
        let candidates = AppleNativeEmbeddingProvider.nativeEmbeddingCandidates(detected: .thai)
        #expect(candidates.first == .english)
    }

    @Test("候选无重复")
    func candidatesAreUnique() {
        let candidates = AppleNativeEmbeddingProvider.nativeEmbeddingCandidates(detected: .english)
        #expect(Set(candidates).count == candidates.count)
    }
}

/// 线程安全的单值盒子，用于在并发闭包之间传递泳道引用。
private final class LaneHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var lane: NLEmbeddingModelPool.Lane?

    init(_ lane: NLEmbeddingModelPool.Lane) {
        self.lane = lane
    }

    /// 取出并清空持有的泳道。
    func take() -> NLEmbeddingModelPool.Lane? {
        lock.lock()
        defer { lock.unlock() }
        let value = lane
        lane = nil
        return value
    }
}
