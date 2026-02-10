import Foundation

struct BrewPackage: Identifiable, Codable, Hashable {
    let name: String
    let desc: String?
    let homepage: String?
    let version: String
    let installedVersion: String?
    let outdated: Bool
    let isCask: Bool
    
    var id: String { name }
    
    // 用于UI显示的状态
    var isInstalled: Bool { installedVersion != nil }
}

struct BrewInfo: Codable {
    let formulae: [BrewPackageInfo]
    let casks: [BrewPackageInfo]
}

struct BrewPackageInfo: Codable {
    let name: String
    let full_name: String?
    let desc: String?
    let homepage: String?
    let versions: BrewVersions?
    let installed: [InstalledVersion]?
    let outdated: Bool?
    let token: String? // Cask specific
    
    // Cask version is a string
    let version: String?
}

struct BrewVersions: Codable {
    let stable: String?
}

struct InstalledVersion: Codable {
    let version: String
    let installed_on_request: Bool?
}
