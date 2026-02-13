import Foundation

struct PermissionRequest: Identifiable, Sendable {
    let id = UUID()
    let toolName: String
    let argumentsString: String
    let toolCallID: String
    let riskLevel: CommandRiskLevel

    var arguments: [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    var summary: String {
        let args = arguments
        switch toolName {
        case "run_command":
            if let cmd = args["command"] as? String {
                return "Execute command: \(cmd)"
            }
        case "write_file":
            if let path = args["path"] as? String {
                return "Write file: \(URL(fileURLWithPath: path).lastPathComponent)"
            }
        default:
            break
        }
        return "Execute \(toolName)"
    }

    var details: String {
        return argumentsString
    }
}
