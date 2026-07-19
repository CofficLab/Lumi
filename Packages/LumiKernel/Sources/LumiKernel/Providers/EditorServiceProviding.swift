import Foundation

/// 编辑器服务能力协议
///
/// 定义 LumiCore 需要的编辑器功能，由具体编辑器插件实现。
@MainActor
public protocol EditorServiceProviding: AnyObject {
    /// 打开文件
    func openFile(at path: String) async throws

    /// 关闭文件
    func closeFile(at path: String) async

    /// 当前文件路径
    var currentFilePath: String? { get }
}
