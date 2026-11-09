import KitAgentTool
import KitCADDesigner
import Foundation

enum CADDesignerV2ToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func double(_ arguments: [String: ToolArgument], _ key: String) -> Double? {
        switch arguments[key]?.value {
        case let value as Double: value
        case let value as Int: Double(value)
        case let value as NSNumber: value.doubleValue
        default: nil
        }
    }

    static func double(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Double) -> Double {
        double(arguments, key) ?? defaultValue
    }

    /// `Double(Int.max)` 恰等于 2^63，用它做上界仍会在 `Int` 转换时触发陷阱，
    /// 因此要求严格小于该值。非有限值同样拒绝。
    static let safeMagnitudeLimit = 9_223_372_036_854_775_808.0

    /// 读取必须为正且可安全转换为 `Int` 的尺寸参数；不合法时抛出结构化工具错误。
    static func positiveDouble(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Double, toolName: String) throws -> Double {
        let value = double(arguments, key, default: defaultValue)
        guard value.isFinite, value > 0, value < safeMagnitudeLimit else {
            throw failure(
                en: "Invalid '\(key)' value: expected a finite, positive number below 2^63 mm.",
                zh: "参数 '\(key)' 无效：需要有限、正数且小于 2^63 毫米的值。",
                toolName: toolName
            )
        }
        return value
    }

    /// 把毫米值格式化为整数文本；超出安全范围时保留 `Double` 描述，绝不触发 `Int` 陷阱。
    static func millimetres(_ value: Double) -> String {
        guard value.isFinite, abs(value) < safeMagnitudeLimit else { return String(value) }
        return "\(Int(value))"
    }

    static func componentSummary(_ component: CADComponent) -> String {
        let name = component.displayName(library: .shared)
        return localized(
            en: "componentId: \(component.id)\nname: \(name)\nkind: \(component.kind.rawValue)",
            zh: "组件ID: \(component.id)\n名称: \(name)\n类型: \(component.kind == .profile ? "型材" : "连接件")"
        )
    }

    static func localized(en: String, zh: String) -> String {
        LanguagePreference.current == .chinese ? zh : en
    }

    static func missingParameter(_ name: String, toolName: String) -> ToolExecutionError {
        .executionFailed(
            toolName: toolName,
            reason: localized(
                en: "Missing required '\(name)' parameter.",
                zh: "缺少必填参数 '\(name)'。"
            )
        )
    }

    static func failure(_ error: Error, toolName: String) -> ToolExecutionError {
        .executionFailed(
            toolName: toolName,
            reason: localized(
                en: error.localizedDescription,
                zh: localizedErrorDescription(error.localizedDescription)
            )
        )
    }

    static func failure(en: String, zh: String, toolName: String) -> ToolExecutionError {
        .executionFailed(toolName: toolName, reason: localized(en: en, zh: zh))
    }

    private static func localizedErrorDescription(_ description: String) -> String {
        if description == "No CAD document is selected." { return "未选中 CAD 文档。" }
        let prefix = "CAD component not found: "
        if description.hasPrefix(prefix) {
            return "未找到 CAD 组件：\(description.dropFirst(prefix.count))"
        }
        return description
    }
}
