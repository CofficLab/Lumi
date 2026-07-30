import Foundation

@MainActor
final class ConversationListRuntimeBridge {
    static let shared = ConversationListRuntimeBridge()

    var storageDirectory: URL?

    private init() {}

    static var defaultStorageDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/ConversationList")
    }
}
