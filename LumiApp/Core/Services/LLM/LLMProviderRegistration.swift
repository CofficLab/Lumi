import Foundation
import MagicKit
import ObjectiveC.runtime

/// 使用 Objective‑C Runtime 扫描 `SuperLLMProvider` 并注册到 `ProviderRegistry`。
enum LLMProviderRegistration: SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let verbose: Bool = false
    static func registerAllProviders(to registry: LLMProviderRegistry) {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else {
            return
        }
        defer {
            free(UnsafeMutableRawPointer(classList))
        }

        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        var discoveredTypes: [(type: SuperLLMProvider.Type, name: String)] = []

        for i in 0 ..< classes.count {
            let cls: AnyClass = classes[i]
            let className = NSStringFromClass(cls)

            guard className.hasPrefix("Lumi."),
                  className.hasSuffix("Provider") else {
                continue
            }

            guard let providerType = cls as? SuperLLMProvider.Type else {
                continue
            }

            discoveredTypes.append((type: providerType, name: className))
        }

        discoveredTypes.sort { $0.type.id < $1.type.id }

        for item in discoveredTypes {
            registry.register(item.type)
            if Self.verbose {
                AppLogger.core.info("\(self.t)✅ Registered LLM provider: \(item.name) (id: \(item.type.id))")
            }
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)🔍 LLM providers loaded: \(discoveredTypes.count)")
        }
    }
}
