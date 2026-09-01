import Foundation

public struct BrewPackage: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public let desc: String?
    public let homepage: String?
    public let version: String
    public let installedVersion: String?
    public let outdated: Bool
    public let isCask: Bool

    public var id: String { name }

    // 用于UI显示的状态
    public var isInstalled: Bool { installedVersion != nil }

    public init(
        name: String,
        desc: String?,
        homepage: String?,
        version: String,
        installedVersion: String?,
        outdated: Bool,
        isCask: Bool
    ) {
        self.name = name
        self.desc = desc
        self.homepage = homepage
        self.version = version
        self.installedVersion = installedVersion
        self.outdated = outdated
        self.isCask = isCask
    }
}

public struct BrewInfo: Codable, Sendable {
    public let formulae: [BrewPackageInfo]
    public let casks: [BrewPackageInfo]

    public init(formulae: [BrewPackageInfo], casks: [BrewPackageInfo]) {
        self.formulae = formulae
        self.casks = casks
    }
}

public struct BrewPackageInfo: Codable, Sendable {
    public let name: String
    public let full_name: String?
    public let desc: String?
    public let homepage: String?
    public let versions: BrewVersions?
    public let installed: [InstalledVersion]?
    public let outdated: Bool?
    public let token: String? // Cask specific

    // Cask version is a string
    public let version: String?

    public init(
        name: String,
        full_name: String?,
        desc: String?,
        homepage: String?,
        versions: BrewVersions?,
        installed: [InstalledVersion]?,
        outdated: Bool?,
        token: String?,
        version: String?
    ) {
        self.name = name
        self.full_name = full_name
        self.desc = desc
        self.homepage = homepage
        self.versions = versions
        self.installed = installed
        self.outdated = outdated
        self.token = token
        self.version = version
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case full_name
        case desc
        case homepage
        case versions
        case installed
        case outdated
        case token
        case version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Formulae expose `name` as a string, while Homebrew casks expose
        // their display names as an array (for example, ["Google Chrome"]).
        // Keep the public model stable and accept both Homebrew shapes.
        if let formulaName = try? container.decode(String.self, forKey: .name) {
            name = formulaName
        } else {
            let caskNames = try container.decode([String].self, forKey: .name)
            guard let caskName = caskNames.first else {
                throw DecodingError.dataCorruptedError(
                    forKey: .name,
                    in: container,
                    debugDescription: "Homebrew cask name array must not be empty"
                )
            }
            name = caskName
        }
        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        versions = try container.decodeIfPresent(BrewVersions.self, forKey: .versions)

        // Formulae return an array here, while Homebrew casks return the
        // installed version as a string. The cask version is already exposed
        // through `version`, so the string form can safely be ignored.
        installed = try? container.decode([InstalledVersion].self, forKey: .installed)

        outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        version = try container.decodeIfPresent(String.self, forKey: .version)
    }
}

public struct BrewVersions: Codable, Sendable {
    public let stable: String?

    public init(stable: String?) {
        self.stable = stable
    }
}

public struct InstalledVersion: Codable, Sendable {
    public let version: String
    public let installed_on_request: Bool?

    public init(version: String, installed_on_request: Bool?) {
        self.version = version
        self.installed_on_request = installed_on_request
    }
}
