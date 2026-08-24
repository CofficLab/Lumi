import Combine
import Foundation

/// 配置能力（契约 V2，见重构方案 §8.7）。
///
/// 支持默认值、用户、工作区、语言覆盖的分作用域解析；
/// 配置 schema 与插件默认值由贡献包声明（后续阶段接入）。
@MainActor
public protocol EditorConfigurationProviding: AnyObject {
    /// 配置快照（各作用域原始值）。
    var snapshot: EditorConfigurationSnapshot { get }

    /// 配置状态流（CurrentValue 语义）。
    var statePublisher: AnyPublisher<EditorConfigurationSnapshot, Never> { get }

    /// 按作用域优先级解析某键的最终值。
    func resolvedValue(for key: EditorSettingKey, context: EditorConfigurationContext) -> EditorSettingValue?

    /// 在指定作用域写入（nil 表示删除该键）。
    ///
    /// - Throws: `EditorContractError.permissionDenied` 只读作用域；
    ///   `EditorContractError.capabilityUnavailable` 键未在 schema 中声明。
    func update(_ value: EditorSettingValue?, for key: EditorSettingKey, scope: EditorSettingScope) throws
}
