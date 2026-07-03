import Foundation

public struct LumiCoreConfiguration: Sendable {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }
}
