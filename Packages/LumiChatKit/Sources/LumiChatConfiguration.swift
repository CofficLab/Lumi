import Foundation

public struct LumiChatConfiguration: Sendable {
    public let databaseDirectory: URL
    public let databaseFileName: String

    public init(databaseDirectory: URL, databaseFileName: String = "Lumi.db") {
        self.databaseDirectory = databaseDirectory
        self.databaseFileName = databaseFileName
    }

    public static func coreDatabase(directory: URL) -> LumiChatConfiguration {
        LumiChatConfiguration(databaseDirectory: directory, databaseFileName: "Lumi.db")
    }
}
