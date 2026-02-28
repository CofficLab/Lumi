import Foundation

struct AppSetting: Codable, Identifiable, Hashable {
    var id: String { appId }
    var appId: String
    var allowed: Bool
    
    init(appId: String, allowed: Bool) {
        self.appId = appId
        self.allowed = allowed
    }
}
