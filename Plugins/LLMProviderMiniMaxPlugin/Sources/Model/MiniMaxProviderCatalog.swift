import Foundation

enum MiniMaxProviderCatalog {
    static let models = ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed", "MiniMax-M2.5", "MiniMax-M2", "MiniMax-Text-01"]
    static let contexts = ["MiniMax-M3": 204800, "MiniMax-M2.7": 204800, "MiniMax-M2.7-highspeed": 204800, "MiniMax-M2.5": 204800, "MiniMax-M2": 131072, "MiniMax-Text-01": 4000000]
    static let capabilities: [String: LumiModelCapabilities] = [
        "MiniMax-M3": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.7": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.7-highspeed": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true), "MiniMax-M2": .init(supportsVision: false, supportsTools: true), "MiniMax-Text-01": .init(supportsVision: false, supportsTools: false),
    ]
}
