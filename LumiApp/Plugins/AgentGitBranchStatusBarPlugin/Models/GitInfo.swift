import Foundation

/// Git 信息模型（用于状态栏详情弹窗展示）
struct GitInfo {
    let branch: String
    let remote: String
    let lastCommit: String
    let author: String
    let isDirty: Bool
}
