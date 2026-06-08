import Foundation

struct LumiProject: Codable, Equatable, Identifiable {
    var id: String { path }

    let name: String
    let path: String
    let lastUsed: Date

    init(name: String, path: String, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.lastUsed = lastUsed
    }
}
