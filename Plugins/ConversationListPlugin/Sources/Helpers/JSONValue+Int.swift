import Foundation
import KernelLumi

// MARK: - LumiJSONValue Int Extension

extension LumiJSONValue {
    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        default:
            nil
        }
    }
}

// MARK: - String Table Escaping Extension

extension String {
    func escapedForTable() -> String {
        replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}