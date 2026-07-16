import Testing
@testable import LLMKit

// MARK: - 辅助工厂

extension RouteSignal {
    /// 快速构建测试用的 RouteSignal
    static func make(
        hasImages: Bool = false,
        messageLength: Int = 500,
        allowsTools: Bool = false,
        currentProviderId: String = "openai",
        currentModel: String = "gpt-4o"
    ) -> RouteSignal {
        RouteSignal(
            hasImages: hasImages,
            messageLength: messageLength,
            allowsTools: allowsTools,
            currentProviderId: currentProviderId,
            currentModel: currentModel
        )
    }
}

extension RouteCandidate {
    /// 快速构建测试用的 RouteCandidate
    static func make(
        providerId: String = "openai",
        providerDisplayName: String = "OpenAI",
        model: String = "gpt-4o",
        availability: CandidateAvailability = .available,
        contextWindowSizes: [String: Int] = [:]
    ) -> RouteCandidate {
        RouteCandidate(
            providerId: providerId,
            providerDisplayName: providerDisplayName,
            model: model,
            availability: availability,
            contextWindowSizes: contextWindowSizes
        )
    }
}

// MARK: - DefaultModelScoring Tests

@Suite("DefaultModelScoring")
struct DefaultModelScoringTests {

    let scoring = DefaultModelScoring()

    // MARK: 可用性评分

    @Test("可用性 .available 加 100 分")
    func availableScore() {
        let signal = RouteSignal.make()
        let candidate = RouteCandidate.make(availability: .available)
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score >= 100)
        // 额外验证：只有可用性贡献了基础分（gpt-4o 不含 haiku/mini/flash）
        // 但可能有惯性偏好分，所以只验证 >= 100
    }

    @Test("可用性 .checking 加 30 分")
    func checkingScore() {
        let signal = RouteSignal.make(currentProviderId: "other", currentModel: "other")
        let candidate = RouteCandidate.make(
            providerId: "p",
            model: "some-model",
            availability: .checking
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 30.0)
    }

    @Test("可用性 .unknown 加 20 分")
    func unknownScore() {
        let signal = RouteSignal.make(currentProviderId: "other", currentModel: "other")
        let candidate = RouteCandidate.make(
            providerId: "p",
            model: "some-model",
            availability: .unknown
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 20.0)
    }

    // MARK: 惯性偏好评分

    @Test("供应商相同但模型不同加 8 分")
    func sameProviderDifferentModel() {
        let signal = RouteSignal.make(currentProviderId: "openai", currentModel: "gpt-4o")
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 8 (same provider) + 2 (mini fast bonus) = 110
        #expect(score == 110.0)
    }

    @Test("供应商和模型都相同加 24 分 (8 + 16)")
    func sameProviderAndModel() {
        let signal = RouteSignal.make(currentProviderId: "openai", currentModel: "gpt-4o")
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 8 (same provider) + 16 (same provider + model) = 124
        #expect(score == 124.0)
    }

    @Test("供应商不同不获得惯性偏好加分")
    func differentProviderNoBonus() {
        let signal = RouteSignal.make(currentProviderId: "openai", currentModel: "gpt-4o")
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            providerDisplayName: "Anthropic",
            model: "claude-sonnet-4-20250514",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 0 = 100
        #expect(score == 100.0)
    }

    // MARK: 短消息 + mini 模型

    @Test("短消息(< 280) + mini 模型加 8 分")
    func shortMessageMiniBonus() {
        let signal = RouteSignal.make(
            messageLength: 100,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 8 (short+mini) + 2 (mini fast bonus) = 110
        #expect(score == 110.0)
    }

    @Test("短消息(280) + mini 模型不加分（边界值：< 280 不含 280）")
    func boundaryMessageLengthMini() {
        let signal = RouteSignal.make(
            messageLength: 280,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 2 (mini fast bonus) = 102, 没有 short+mini 的 8 分
        #expect(score == 102.0)
    }

    @Test("短消息 + 非 mini 模型不获得短消息加分")
    func shortMessageNonMini() {
        let signal = RouteSignal.make(
            messageLength: 100,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 100.0)
    }

    @Test("非短消息 + mini 模型不获得短消息加分")
    func longMessageMiniNoBonus() {
        let signal = RouteSignal.make(
            messageLength: 500,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 2 (mini fast bonus) = 102
        #expect(score == 102.0)
    }

    // MARK: 长消息 + 上下文窗口

    @Test("长消息(> 2000) + 有上下文窗口信息加分")
    func longMessageContextWindow() {
        let signal = RouteSignal.make(
            messageLength: 3000,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            providerDisplayName: "Anthropic",
            model: "claude-sonnet-4-20250514",
            availability: .available,
            contextWindowSizes: ["claude-sonnet-4-20250514": 200_000]
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available) + 200_000 / 100_000 = 100 + 2.0 = 102.0
        #expect(score == 102.0)
    }

    @Test("长消息(2000) + 有上下文窗口 — 边界值（> 2000 不含 2000）不加分")
    func boundaryLongMessage() {
        let signal = RouteSignal.make(
            messageLength: 2000,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            providerDisplayName: "Anthropic",
            model: "claude-sonnet-4-20250514",
            availability: .available,
            contextWindowSizes: ["claude-sonnet-4-20250514": 200_000]
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 100.0)
    }

    @Test("长消息 + 无上下文窗口信息不加分")
    func longMessageNoContextWindow() {
        let signal = RouteSignal.make(
            messageLength: 3000,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            providerDisplayName: "Anthropic",
            model: "claude-sonnet-4-20250514",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 100.0)
    }

    @Test("长消息 + 大上下文窗口加更多分")
    func longMessageLargeContextWindow() {
        let signal = RouteSignal.make(
            messageLength: 5000,
            currentProviderId: "other",
            currentModel: "other"
        )
        let small = RouteCandidate.make(
            providerId: "p1",
            model: "model-a",
            availability: .available,
            contextWindowSizes: ["model-a": 100_000]
        )
        let large = RouteCandidate.make(
            providerId: "p2",
            model: "model-b",
            availability: .available,
            contextWindowSizes: ["model-b": 500_000]
        )
        let scoreSmall = scoring.score(candidate: small, signal: signal)
        let scoreLarge = scoring.score(candidate: large, signal: signal)
        #expect(scoreLarge > scoreSmall)
    }

    // MARK: 工具 + 编码模型

    @Test("需要工具 + codex 模型加 10 分")
    func toolsWithCodex() {
        let signal = RouteSignal.make(
            allowsTools: true,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "codex-1",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 10 = 110
        #expect(score == 110.0)
    }

    @Test("需要工具 + coder 模型加 10 分")
    func toolsWithCoder() {
        let signal = RouteSignal.make(
            allowsTools: true,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "deepseek",
            model: "deepseek-coder",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 10 = 110
        #expect(score == 110.0)
    }

    @Test("不需要工具 + codex 模型不加分")
    func noToolsCodexNoBonus() {
        let signal = RouteSignal.make(
            allowsTools: false,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "codex-1",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 100.0)
    }

    @Test("需要工具 + 非编码模型不加分")
    func toolsNonCoderNoBonus() {
        let signal = RouteSignal.make(
            allowsTools: true,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 100.0)
    }

    // MARK: 快速模型加分

    @Test("haiku 模型加 2 分")
    func haikuBonus() {
        let signal = RouteSignal.make(
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            model: "claude-3-5-haiku",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 2 = 102
        #expect(score == 102.0)
    }

    @Test("mini 模型加 2 分")
    func miniBonus() {
        let signal = RouteSignal.make(
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 2 = 102
        #expect(score == 102.0)
    }

    @Test("flash 模型加 2 分")
    func flashBonus() {
        let signal = RouteSignal.make(
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "google",
            model: "gemini-2.0-flash",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 2 = 102
        #expect(score == 102.0)
    }

    @Test("快速模型名称大小写不敏感")
    func fastModelCaseInsensitive() {
        let signal = RouteSignal.make(
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "anthropic",
            model: "Claude-Haiku",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 + 2 = 102
        #expect(score == 102.0)
    }

    // MARK: 综合评分

    @Test("综合评分 — 多项加分叠加")
    func combinedScore() {
        let signal = RouteSignal.make(
            messageLength: 100,    // short
            allowsTools: true,
            currentProviderId: "openai",
            currentModel: "gpt-4o-mini"
        )
        let candidate = RouteCandidate.make(
            providerId: "openai",
            model: "gpt-4o-mini",
            availability: .available
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        // 100 (available)
        // + 8  (same provider)
        // + 16 (same provider + model)
        // + 8  (short + mini)
        // + 2  (mini fast bonus)
        // = 134
        #expect(score == 134.0)
    }

    @Test("最小评分 — unknown 可用性 + 无匹配加分")
    func minimumScore() {
        let signal = RouteSignal.make(
            messageLength: 500,
            allowsTools: false,
            currentProviderId: "other",
            currentModel: "other"
        )
        let candidate = RouteCandidate.make(
            providerId: "p",
            model: "some-model",
            availability: .unknown
        )
        let score = scoring.score(candidate: candidate, signal: signal)
        #expect(score == 20.0)
    }
}
