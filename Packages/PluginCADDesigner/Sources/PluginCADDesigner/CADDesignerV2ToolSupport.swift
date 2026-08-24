import AgentToolKit
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

    static func localized(en: String, zh: String) -> String {
        LanguagePreference.current == .chinese ? zh : en
    }

    static func missingParameter(_ name: String) -> String {
        localized(en: "Error: Missing required '\(name)' parameter.", zh: "错误：缺少必填参数 '\(name)'。")
    }

    static func error(_ error: Error) -> String {
        localized(en: "Error: \(error.localizedDescription)", zh: "错误：\(localizedErrorDescription(error.localizedDescription))")
    }

    private static func localizedErrorDescription(_ description: String) -> String {
        description == "No CAD document is selected." ? "未选中 CAD 文档。" : description
    }
}
