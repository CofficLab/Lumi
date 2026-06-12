import Foundation

/// Git 仓库状态
public struct GitStatus: Codable, Sendable {
    public let branch: String
    public let remote: String?
    public let modified: [String]
    public let added: [String]
    public let deleted: [String]
    public let renamed: [String]
    public let staged: [String]
}
