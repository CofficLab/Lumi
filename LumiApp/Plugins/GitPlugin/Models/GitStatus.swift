import Foundation

/// Git 仓库状态
struct GitStatus: Codable {
    let branch: String
    let remote: String?
    let modified: [String]
    let added: [String]
    let deleted: [String]
    let renamed: [String]
    let staged: [String]
}
