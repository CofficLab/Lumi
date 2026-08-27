import Foundation
import ProviderProjectRAG

@MainActor
enum ProjectRAGRuntime {
    private(set) static var provider: (any ProjectRAGProviding)?

    static func configure(provider: any ProjectRAGProviding) {
        self.provider = provider
    }

    static func reset() {
        provider = nil
    }
}
