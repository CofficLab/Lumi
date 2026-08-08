import Foundation
import LumiKernel

enum MiniMaxProviderCatalog {
    static let models: [LumiModelInfo] = [
            .init(
                id: "MiniMax-M3",
                contextWindowSize: 1_000_000,
                // M3 supports reasoning effort levels (minimal/low/medium/high) via Responses API
                // reasoningEffort maps to `reasoning.effort` in the request body
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .levels)
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
