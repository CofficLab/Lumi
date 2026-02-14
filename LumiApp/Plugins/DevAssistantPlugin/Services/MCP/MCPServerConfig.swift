
import Foundation

struct MCPServerConfig: Codable, Hashable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]
    let disabled: Bool
    
    init(name: String, command: String, args: [String] = [], env: [String: String] = [:], disabled: Bool = false) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.disabled = disabled
    }
}
