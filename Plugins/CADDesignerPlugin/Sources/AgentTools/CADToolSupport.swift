import Foundation
import LumiCoreKit

/// CAD AgentTool 共用辅助：语言、参数提取、错误本地化。
enum CADToolSupport {
    static func language(_ context: LumiToolExecutionContext) -> LumiLanguagePreference {
        context.language
    }

    static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese: return zh
        case .english: return en
        }
    }

    static func error(_ error: Error, language: LumiLanguagePreference) -> String {
        localized(language, en: "Error: \(error.localizedDescription)", zh: "错误：\(localizedErrorDescription(error.localizedDescription))")
    }

    static func missingParameter(_ name: String, language: LumiLanguagePreference) -> String {
        localized(
            language,
            en: "Error: Missing required '\(name)' parameter.",
            zh: "错误：缺少必填参数 '\(name)'。"
        )
    }

    static func string(_ arguments: [String: LumiJSONValue], _ key: String) -> String? {
        arguments.string(key)
    }

    static func double(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: Double) -> Double {
        arguments.double(key) ?? defaultValue
    }

    static func optionalDouble(_ arguments: [String: LumiJSONValue], _ key: String) -> Double? {
        arguments.double(key)
    }

    static func int(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: Int) -> Int {
        arguments.int(key) ?? defaultValue
    }

    /// 把 CAD 错误描述翻译成中文。
    static func localizedErrorDescription(_ description: String) -> String {
        if description == "No CAD document is selected." {
            return "未选中 CAD 文档。"
        }
        if let suffix = description.dropPrefix("CAD component not found: ") {
            return "找不到 CAD 组件：\(suffix)"
        }
        return description
    }

    /// 组件摘要。
    static func componentSummary(_ component: CADComponent, library: ComponentLibrary, language: LumiLanguagePreference) -> String {
        let name = component.displayName(library: library)
        switch language {
        case .chinese:
            return """
            组件ID: \(component.id)
            名称: \(name)
            类型: \(component.kind == .profile ? "型材" : "连接件")
            """
        case .english:
            return """
            componentId: \(component.id)
            name: \(name)
            kind: \(component.kind.rawValue)
            """
        }
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
