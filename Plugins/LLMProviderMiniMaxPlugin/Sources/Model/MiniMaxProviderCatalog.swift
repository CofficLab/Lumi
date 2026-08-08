import Foundation
import LumiKernel

enum MiniMaxProviderCatalog {
    static let models: [LumiModelInfo] = [
            .init(
                id: "MiniMax-M3",
                contextWindowSize: 1_000_000,
                // M3 only supports an on/off toggle (no levels); the request-level
                // `LumiThinkingAndReasoning` value is mapped to Anthropic `thinking.type`
                // (disabled / adaptive) inside `MiniMaxRequestBuilder`.
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .toggle)
            ),
            .init(
                id: "MiniMax-M2.7",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.7-highspeed",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.5",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.5-highspeed",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.1",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.1-highspeed",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-Text-01",
                contextWindowSize: 4_000_000,
                capabilities: .init(supportsVision: false, supportsTools: false)
            ),
    ]
}
