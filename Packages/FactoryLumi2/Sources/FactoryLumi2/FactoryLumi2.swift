import Foundation
import ProviderProject

/// FactoryLumi2 — 占位命名空间。
///
/// 当前为骨架包，已依赖 ProviderProject（负责 ProjectProviding 相关内容）。
/// 后续在此扩展。
public enum FactoryLumi2 {
    /// 占位引用，确保 ProviderProject 依赖在编译期生效。
    static let placeholder = ProjectProviding.self
}
