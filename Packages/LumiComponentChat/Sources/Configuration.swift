import Foundation

public struct Configuration: Sendable {
    public let databaseDirectory: URL
    public let databaseFileName: String

    public init(databaseDirectory: URL, databaseFileName: String = "Lumi.db") {
        self.databaseDirectory = databaseDirectory
        self.databaseFileName = databaseFileName
    }

    public static func coreDatabase(directory: URL) -> Configuration {
        Configuration(databaseDirectory: directory, databaseFileName: "Lumi.db")
    }
}
