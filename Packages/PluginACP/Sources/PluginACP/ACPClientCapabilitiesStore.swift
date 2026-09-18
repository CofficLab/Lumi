import Foundation
import ProviderACP

/// Client 能力登记簿。
///
/// ACP 要求：未在 `initialize` 中声明的能力一律视为**不支持**，Agent
/// **MUST NOT** 调用对应方法。因此这里默认全部为 `false`，只有 Client
/// 显式声明 `true` 才启用。
///
/// 能力是**连接级**的（整个 stdio 连接共享），不属于某个会话。
@MainActor
public final class ACPClientCapabilitiesStore {
    /// Client 声明支持 `fs/read_text_file`。
    public private(set) var readTextFile = false
    /// Client 声明支持 `fs/write_text_file`。
    public private(set) var writeTextFile = false

    public init() {}

    /// 记录 `initialize` 请求中声明的能力。
    ///
    /// - Parameter capabilities: Client 能力（缺失字段视为不支持）。
    public func update(from capabilities: ACPClientCapabilities) {
        readTextFile = capabilities.fs?.readTextFile ?? false
        writeTextFile = capabilities.fs?.writeTextFile ?? false
    }

    /// 是否可用编辑器文件系统桥。
    public var hasFileSystemBridge: Bool { readTextFile && writeTextFile }
}
