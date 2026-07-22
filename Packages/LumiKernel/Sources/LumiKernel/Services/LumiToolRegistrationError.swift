import Foundation

public enum LumiToolRegistrationError: LocalizedError {
    case duplicateNames([LumiToolDuplicateEntry])
}

public struct LumiToolDuplicateEntry: Sendable, Equatable {
    public let name: String
    public let owners: [String]
    public init(name: String, owners: [String]) { self.name = name; self.owners = owners }
}

extension LumiToolRegistrationError {
    public var errorDescription: String? {
        switch self {
        case .duplicateNames(let entries):
            let lines = entries.map { entry in
                "  • \(entry.name): \(entry.owners.joined(separator: ", "))"
            }
            return "工具名称冲突 (\(entries.count) 个):\n\(lines.joined(separator: "\n"))"
        }
    }
    public var failureReason: String? {
        "多个工具声明了相同的 name，这会导致工具调用歧义。请禁用冲突的插件或重命名其中之一。"
    }
}
