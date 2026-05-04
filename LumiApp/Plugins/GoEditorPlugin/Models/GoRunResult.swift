import Foundation

/// Go 命令执行结果
struct GoRunResult: Sendable {
    /// 退出码（0 表示成功）
    let exitCode: Int
    /// 标准输出
    let stdout: String
    /// 标准错误
    let stderr: String

    /// 是否成功
    var isSuccess: Bool { exitCode == 0 }
}
