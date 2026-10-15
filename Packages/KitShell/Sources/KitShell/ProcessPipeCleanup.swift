import Foundation

/// 确定性释放管道持有的文件描述符。
///
/// `Foundation.Pipe`（底层 `NSPipe`）创建时占用 2 个 fd（读端 + 写端），
/// 其释放依赖 autorelease pool 排空或对象析构。在 chat/agent 热路径上，
/// 同步代码段跨多个 `await` 边界时会长时间不排空 autorelease pool，
/// 导致这些 fd 持续堆积；长时间对话后耗尽进程 fd 上限（EMFILE，
/// "Too many open files"），使网络与工具同时失败。
///
/// 因此每个 `Process` 管道在**使用结束后必须显式关闭两端 fd**，而不是等待 ARC。
/// 详见 `ProcessPipeLeakTests` 的回归用例。
extension Pipe {
    /// 关闭管道读写两端的文件描述符。
    ///
    /// 幂等：重复调用时已关闭的一端会忽略错误。
    func closeFileDescriptors() {
        try? fileHandleForReading.close()
        try? fileHandleForWriting.close()
    }
}
