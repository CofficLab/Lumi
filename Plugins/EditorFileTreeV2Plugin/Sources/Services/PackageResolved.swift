import Foundation

public struct ResolvedPackagePin: Equatable, Sendable {
    public let identity: String
    public let location: String
    public let version: String?
    public let branch: String?
    public let revision: String?
}

public enum PackageResolved {
    public static func parse(url: URL) throws -> [ResolvedPackagePin] {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    public static func parse(data: Data) throws -> [ResolvedPackagePin] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else { return [] }

        if let pins = root["pins"] as? [[String: Any]] {
            return pins.compactMap(parseV2Pin(_:))
        }

        if let object = root["object"] as? [String: Any],
           let pins = object["pins"] as? [[String: Any]] {
            return pins.compactMap(parseV1Pin(_:))
        }

        return []
    }

    private static func parseV2Pin(_ pin: [String: Any]) -> ResolvedPackagePin? {
        guard let identity = pin["identity"] as? String else { return nil }
        let location = (pin["location"] as? String) ?? identity
        let state = pin["state"] as? [String: Any] ?? [:]
        return ResolvedPackagePin(
            identity: normalizeIdentity(identity),
            location: location,
            version: state["version"] as? String,
            branch: state["branch"] as? String,
            revision: state["revision"] as? String
        )
    }

    private static func parseV1Pin(_ pin: [String: Any]) -> ResolvedPackagePin? {
        guard let package = pin["package"] as? String else { return nil }
        let repositoryURL = (pin["repositoryURL"] as? String) ?? package
        let state = pin["state"] as? [String: Any] ?? [:]
        let identity = (pin["identity"] as? String) ?? identityFromLocation(repositoryURL)
        return ResolvedPackagePin(
            identity: normalizeIdentity(identity),
            location: repositoryURL,
            version: state["version"] as? String,
            branch: state["branch"] as? String,
            revision: state["revision"] as? String
        )
    }

    public static func normalizeIdentity(_ value: String) -> String {
        identityFromLocation(value).lowercased()
    }

    public static func identityFromLocation(_ location: String) -> String {
        var value = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix(".git") {
            value.removeLast(4)
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return value.split(separator: "/").last.map(String.init) ?? value
    }
}
