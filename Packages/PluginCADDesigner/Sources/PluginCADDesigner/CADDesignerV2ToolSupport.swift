import AgentToolKit

enum CADDesignerV2ToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
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
