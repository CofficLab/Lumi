import Foundation

struct AppStoreConnectCredentials: Equatable {
    var issuerID: String
    var keyID: String
    var privateKey: String

    var isComplete: Bool {
        !issuerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
