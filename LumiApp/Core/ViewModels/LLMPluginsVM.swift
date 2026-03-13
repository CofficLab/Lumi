import Foundation
import MagicKit
import OSLog
import ObjectiveC.runtime

/// LLM 插件加载器
///
/// 使用 Objective‑C Runtime 扫描所有实现 `SuperLLMProvider` 的类，
/// 并将其注册到 `ProviderRegistry`。
enum LLMPluginsVM: SuperLog {

    nonisolated static let emoji = "🧩"
    nonisolated static let verbose = true

    /// 扫描并注册所有 LLM 供应商
    ///
    /// - Parameter registry: 要注册到的供应商注册表实例
    static func registerAllProviders(to registry: ProviderRegistry) {
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

            // 仅匹配 Lumi 命名空间且以 Provider 结尾的类
            guard className.hasPrefix("Lumi."),
                  className.hasSuffix("Provider") else {
                continue
            }

            // 尝试转换为 SuperLLMProvider 类型
            guard let providerType = cls as? SuperLLMProvider.Type else {
                continue
            }

            discoveredTypes.append((type: providerType, name: className))
        }

        // 稳定排序，避免运行时枚举顺序导致 UI 抖动
        discoveredTypes.sort { $0.type.id < $1.type.id }

        for item in discoveredTypes {
            registry.register(item.type)
            if Self.verbose {
                os_log("\(self.t)✅ Registered LLM provider: \(item.name) (id: \(item.type.id))")
            }
        }

        if Self.verbose {
            os_log("\(self.t)🔍 LLM providers loaded: \(discoveredTypes.count)")
        }
    }
}

