// MARK: - LumiCore 配置

/// LumiCore 配置
public struct LumiCoreConfiguration: Sendable {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }
}