import AgentToolKit
import Foundation

/// 内置文件/终端工具的通用参数访问辅助。
extension [String: ToolArgument] {
    func stringValue(_ key: String) -> String? {
        guard let value = self[key]?.value else { return nil }
        return value as? String
    }

    func boolValue(_ key: String) -> Bool? {
        guard let value = self[key]?.value else { return nil }
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int != 0 }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    func intValue(_ key: String) -> Int? {
        guard let value = self[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
