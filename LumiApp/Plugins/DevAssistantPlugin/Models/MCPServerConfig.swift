
import Foundation

enum MCPTransportType: String, Codable, Hashable, Sendable {
    case stdio
    case sse
}

struct MCPServerConfig: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]
    var disabled: Bool = false
    var homepage: String? // Optional homepage URL
    
    // New fields for SSE support
    var url: String?
    var transportType: MCPTransportType?
}
