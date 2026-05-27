import AgentToolKit
import Foundation

enum IconToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func double(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Double) -> Double {
        guard let value = arguments[key]?.value else { return defaultValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String, let double = Double(string) { return double }
        return defaultValue
    }

    static func optionalDouble(_ arguments: [String: ToolArgument], _ key: String) -> Double? {
        guard let value = arguments[key]?.value else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }

    static func color(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: String) -> IconPaint {
        .color(string(arguments, key) ?? defaultValue)
    }

    static func layerSummary(_ layer: IconLayer) -> String {
        """
        layerId: \(layer.id)
        name: \(layer.name)
        """
    }
}
