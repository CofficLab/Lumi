import Foundation

/// 项目路径的存在性探测入口。
///
/// 探测是同步文件系统调用，遇到外接/网络卷可能阻塞很久，必须放在后台执行。
/// 抽象成协议是为了让测试注入替身，记录探测发生的线程与次数（issue #1251）。
public protocol RAGProjectPathProbing: Sendable {
    func isDirectory(atPath path: String) -> Bool
}

/// 默认实现：直接问 FileManager。
public struct RAGDefaultProjectPathProbe: RAGProjectPathProbing {
    public init() {}

    public func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}