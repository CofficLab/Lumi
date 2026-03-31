import Foundation
import SwiftUI

/// 文件搜索结果模型
struct FileResult: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let relativePath: String
    let isDirectory: Bool
    let score: Int  // 匹配分数，用于排序

    var url: URL {
        URL(fileURLWithPath: path)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileResult, rhs: FileResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// 文件索引模型
struct FileIndex {
    let projectPath: String
    let files: [FileResult]
    let lastUpdated: Date

    /// 检查索引是否过期（超过 5 分钟）
    var isExpired: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}
