import Foundation

/// 供应商列表的用户可见文案。
///
/// 文案属于界面层，由插件本地化目录维护；视图不再写死中文字面量（#906）。
enum ProviderListLocalization {
    static func relaySectionTitle(
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        resolve("Relay")
    }
}
