import Foundation
import LumiKernel

/// 编辑器服务实现
@MainActor
public final class EditorService: EditorServiceProviding {

    /// 当前文件路径
    @Published public var currentFilePath: String?

    public init() {}

    public func openFile(at path: String) async throws {
        // TODO: 实现文件打开逻辑
        currentFilePath = path
    }

    public func closeFile(at path: String) async {
        // TODO: 实现文件关闭逻辑
        if currentFilePath == path {
            currentFilePath = nil
        }
    }
}