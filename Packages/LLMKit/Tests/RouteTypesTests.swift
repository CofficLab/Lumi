import Testing
@testable import LLMKit

// MARK: - RouteSignal Tests

@Suite("RouteSignal")
struct RouteSignalTests {

    @Test("初始化正确赋值所有属性")
    func initStoresAllProperties() {
        let signal = RouteSignal(
            hasImages: true,
            messageLength: 500,
            allowsTools: false,
            currentProviderId: "openai",
            currentModel: "gpt-4o"
        )
        #expect(signal.hasImages == true)
        #expect(signal.messageLength == 500)
        #expect(signal.allowsTools == false)
        #expect(signal.currentProviderId == "openai")
        #expect(signal.currentModel == "gpt-4o")
    }

    @Test("Equatable — 相同值相等")
    func equatableEqual() {
        let a = RouteSignal(
            hasImages: false,
            messageLength: 100,
            allowsTools: true,
            currentProviderId: "p",
            currentModel: "m"
        )
        let b = RouteSignal(
            hasImages: false,
            messageLength: 100,
            allowsTools: true,
            currentProviderId: "p",
            currentModel: "m"
        )
        #expect(a == b)
    }

    @Test("Equatable — 不同值不相等")
    func equatableNotEqual() {
        let base = RouteSignal(
            hasImages: false,
            messageLength: 100,
            allowsTools: true,
            currentProviderId: "p",
            currentModel: "m"
        )
        let diffImages = RouteSignal(
            hasImages: true, messageLength: 100,
            allowsTools: true, currentProviderId: "p", currentModel: "m"
        )
        let diffLength = RouteSignal(
            hasImages: false, messageLength: 999,
            allowsTools: true, currentProviderId: "p", currentModel: "m"
        )
        let diffTools = RouteSignal(
            hasImages: false, messageLength: 100,
            allowsTools: false, currentProviderId: "p", currentModel: "m"
        )
        let diffProvider = RouteSignal(
            hasImages: false, messageLength: 100,
            allowsTools: true, currentProviderId: "x", currentModel: "m"
        )
        let diffModel = RouteSignal(
            hasImages: false, messageLength: 100,
            allowsTools: true, currentProviderId: "p", currentModel: "x"
        )
        #expect(base != diffImages)
        #expect(base != diffLength)
        #expect(base != diffTools)
        #expect(base != diffProvider)
        #expect(base != diffModel)
    }

    @Test("边界值 — messageLength 为 0")
    func zeroMessageLength() {
        let signal = RouteSignal(
            hasImages: false,
            messageLength: 0,
            allowsTools: false,
            currentProviderId: "",
            currentModel: ""
        )
        #expect(signal.messageLength == 0)
    }
}

// MARK: - CandidateAvailability Tests

@Suite("CandidateAvailability")
struct CandidateAvailabilityTests {

    @Test("所有 case 可创建且互不相等")
    func allCasesDistinct() {
        let cases: [CandidateAvailability] = [.available, .checking, .unknown]
        for i in cases.indices {
            for j in cases.indices where i != j {
                #expect(cases[i] != cases[j])
            }
        }
    }

    @Test("相同 case 相等")
    func sameCaseEqual() {
        #expect(CandidateAvailability.available == CandidateAvailability.available)
        #expect(CandidateAvailability.checking == CandidateAvailability.checking)
        #expect(CandidateAvailability.unknown == CandidateAvailability.unknown)
    }
}

// MARK: - RouteCandidate Tests

@Suite("RouteCandidate")
struct RouteCandidateTests {

    @Test("初始化正确赋值所有属性")
    func initStoresAllProperties() {
        let candidate = RouteCandidate(
            providerId: "anthropic",
            providerDisplayName: "Anthropic",
            model: "claude-sonnet-4-20250514",
            availability: .available,
            contextWindowSizes: ["claude-sonnet-4-20250514": 200_000]
        )
        #expect(candidate.providerId == "anthropic")
        #expect(candidate.providerDisplayName == "Anthropic")
        #expect(candidate.model == "claude-sonnet-4-20250514")
        #expect(candidate.availability == .available)
        #expect(candidate.contextWindowSizes == ["claude-sonnet-4-20250514": 200_000])
    }

    @Test("contextWindowSizes 默认为空")
    func defaultContextWindowSizes() {
        let candidate = RouteCandidate(
            providerId: "p",
            providerDisplayName: "P",
            model: "m",
            availability: .unknown
        )
        #expect(candidate.contextWindowSizes.isEmpty)
    }

    @Test("Equatable — 相同值相等")
    func equatableEqual() {
        let a = RouteCandidate(
            providerId: "p",
            providerDisplayName: "P",
            model: "m",
            availability: .available,
            contextWindowSizes: ["m": 1000]
        )
        let b = RouteCandidate(
            providerId: "p",
            providerDisplayName: "P",
            model: "m",
            availability: .available,
            contextWindowSizes: ["m": 1000]
        )
        #expect(a == b)
    }

    @Test("Equatable — 不同 contextWindowSizes 不相等")
    func equatableDifferentWindows() {
        let a = RouteCandidate(
            providerId: "p",
            providerDisplayName: "P",
            model: "m",
            availability: .available,
            contextWindowSizes: ["m": 1000]
        )
        let b = RouteCandidate(
            providerId: "p",
            providerDisplayName: "P",
            model: "m",
            availability: .available,
            contextWindowSizes: [:]
        )
        #expect(a != b)
    }
}

// MARK: - RouteDecision Tests

@Suite("RouteDecision")
struct RouteDecisionTests {

    @Test("初始化正确赋值所有属性")
    func initStoresAllProperties() {
        let decision = RouteDecision(
            providerId: "openai",
            providerDisplayName: "OpenAI",
            model: "gpt-4o",
            reason: "测试理由",
            score: 116.0
        )
        #expect(decision.providerId == "openai")
        #expect(decision.providerDisplayName == "OpenAI")
        #expect(decision.model == "gpt-4o")
        #expect(decision.reason == "测试理由")
        #expect(decision.score == 116.0)
    }

    @Test("Equatable — 相同值相等")
    func equatableEqual() {
        let a = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r", score: 42.0
        )
        let b = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r", score: 42.0
        )
        #expect(a == b)
    }

    @Test("Equatable — 不同 score 不相等")
    func equatableDifferentScore() {
        let a = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r", score: 1.0
        )
        let b = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r", score: 2.0
        )
        #expect(a != b)
    }

    @Test("Equatable — 不同 reason 不相等")
    func equatableDifferentReason() {
        let a = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r1", score: 1.0
        )
        let b = RouteDecision(
            providerId: "p", providerDisplayName: "P",
            model: "m", reason: "r2", score: 1.0
        )
        #expect(a != b)
    }
}
