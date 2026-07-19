import Foundation
import LumiKernel

enum IconToolSupport {
    static func language(_ context: LumiToolExecutionContext) -> LumiLanguagePreference {
        context.language
    }

    static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese:
            zh
        case .english:
            en
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

    static func description(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        localized(language, en: en, zh: zh)
    }

    static func localizedErrorDescription(_ description: String) -> String {
        if description == "No icon document is selected." {
            return "未选中图标文档。"
        }
        if description == "No app icon document or candidate is selected." {
            return "未选中 App 图标文档或候选项。"
        }
        if let suffix = description.dropPrefix("Icon document not found: ") {
            return "找不到图标文档：\(suffix)"
        }
        if let suffix = description.dropPrefix("Icon layer not found: ") {
            return "找不到图层：\(suffix)"
        }
        if let suffix = description.dropPrefix("App icon artifact not found: ") {
            return "找不到 App 图标候选项：\(suffix)"
        }
        if let suffix = description.dropPrefix("Unsupported icon shape: ") {
            return "不支持的图标形状：\(suffix)"
        }
        if let suffix = description.dropPrefix("Image file not found: ") {
            return "找不到图片文件：\(suffix)"
        }
        if let suffix = description.dropPrefix("Unsupported image file: ") {
            return "不支持的图片文件：\(suffix)"
        }
        if let suffix = description.dropPrefix("Invalid source image: ") {
            return "无效源图片：\(suffix)"
        }
        if description.hasPrefix("Failed to render "), description.hasSuffix(" icon.") {
            return description
                .replacingOccurrences(of: "Failed to render ", with: "渲染 ")
                .replacingOccurrences(of: " icon.", with: " 图标失败。")
        }
        return description
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

    static func bool(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: Bool) -> Bool {
        arguments.bool(key) ?? defaultValue
    }

    static func color(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: String) -> IconPaint {
        .color(string(arguments, key) ?? defaultValue)
    }

    static func layerSummary(_ layer: IconLayer, language: LumiLanguagePreference) -> String {
        switch language {
        case .chinese:
            """
            图层ID: \(layer.id)
            名称: \(layer.name)
            """
        case .english:
            """
            layerId: \(layer.id)
            name: \(layer.name)
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
