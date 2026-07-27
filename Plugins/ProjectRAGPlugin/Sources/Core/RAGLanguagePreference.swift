import Foundation

/// 语言偏好
///
/// 用于 `RAGContextBuilder` 构建对应语言的提示词。
/// 替代对 MagicKit 中 `LanguagePreference` 类型的依赖。
public enum RAGLanguagePreference: Sendable, Equatable {
    case chinese
    case english
}
