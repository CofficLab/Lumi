import Foundation

public struct AppSetting: Codable, Identifiable, Hashable {
    public var id: String { appId }
    public var appId: String
    public var allowed: Bool
    
    public init(appId: String, allowed: Bool) {
        self.appId = appId
        self.allowed = allowed
    }
}
