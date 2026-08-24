import Foundation

enum VersionCreateValidationError: LocalizedError {
    case emptyVersionString
    case invalidVersionFormat
    case duplicateVersion(versionString: String, platform: String)
    case platformInProgress(platform: String)

    var errorDescription: String? {
        switch self {
        case .emptyVersionString:
            return AppStoreConnectLocalization.string("Version number is required.")
        case .invalidVersionFormat:
            return AppStoreConnectLocalization.string("Invalid version number format.")
        case .duplicateVersion(let versionString, let platform):
            return AppStoreConnectLocalization.string(
                "Version %@ already exists for %@.",
                versionString,
                AppStoreVersion.platformDisplayName(platform)
            )
        case .platformInProgress(let platform):
            return AppStoreConnectLocalization.string(
                "A version is already in progress for %@.",
                AppStoreVersion.platformDisplayName(platform)
            )
        }
    }
}

enum VersionStringValidator {
    private static let pattern = #"^\d+(\.\d+)*$"#

    static func isValid(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return false }
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AppStoreVersion {
    static let platformOrder: [String] = ["IOS", "MAC_OS", "TV_OS", "VISION_OS"]

    var blocksNewVersionCreate: Bool {
        switch appStoreState.uppercased() {
        case "PREPARE_FOR_SUBMISSION",
             "WAITING_FOR_REVIEW",
             "IN_REVIEW",
             "WAITING_FOR_REVIEWER_ACTION",
             "WAITING_FOR_EXPORT_COMPLIANCE",
             "METADATA_REJECTED",
             "REJECTED",
             "DEVELOPER_REJECTED":
            return true
        default:
            return false
        }
    }

    static func platformDisplayName(_ platform: String) -> String {
        switch platform.normalizedASCPlatform {
        case "MAC_OS":
            return AppStoreConnectLocalization.string("macOS")
        case "IOS":
            return AppStoreConnectLocalization.string("iOS")
        case "TV_OS":
            return AppStoreConnectLocalization.string("tvOS")
        case "VISION_OS":
            return AppStoreConnectLocalization.string("visionOS")
        default:
            return platform
        }
    }

    static func platformsForVersionCreate(appPlatform: String?, versions: [AppStoreVersion]) -> [String] {
        var platforms = Set(versions.map(\.normalizedPlatform))
        platforms.insert((appPlatform ?? "IOS").normalizedASCPlatform)
        return platformOrder.filter { platforms.contains($0) }
            + platforms.subtracting(platformOrder).sorted()
    }

    static func isPlatformAvailableForVersionCreate(_ platform: String, versions: [AppStoreVersion]) -> Bool {
        let normalized = platform.normalizedASCPlatform
        return !versions.contains {
            $0.normalizedPlatform == normalized && $0.blocksNewVersionCreate
        }
    }

    static func suggestedNextVersionString(for platform: String, in versions: [AppStoreVersion]) -> String {
        let normalized = platform.normalizedASCPlatform
        let platformVersions = versions.filter { $0.normalizedPlatform == normalized }
        let base = highestValidVersionString(in: platformVersions)
            ?? mostRecentValidVersionString(in: versions)

        guard let base else { return "1.0.0" }

        var candidate = bumpPatchVersion(base)
        while versions.contains(where: {
            $0.normalizedPlatform == normalized && $0.versionString == candidate
        }) {
            candidate = bumpPatchVersion(candidate)
        }
        return candidate
    }

    static func highestValidVersionString(in versions: [AppStoreVersion]) -> String? {
        versions
            .map(\.versionString)
            .filter { VersionStringValidator.isValid($0) }
            .max { compareVersionStrings($0, $1) == .orderedAscending }
    }

    static func mostRecentValidVersionString(in versions: [AppStoreVersion]) -> String? {
        versions
            .filter { VersionStringValidator.isValid($0.versionString) }
            .max { lhs, rhs in
                (lhs.createdDate ?? .distantPast) < (rhs.createdDate ?? .distantPast)
            }?
            .versionString
    }

    static func validateCreate(
        versionString rawVersionString: String,
        platform: String,
        versions: [AppStoreVersion]
    ) throws -> (versionString: String, platform: String) {
        let versionString = VersionStringValidator.normalized(rawVersionString)
        guard !versionString.isEmpty else {
            throw VersionCreateValidationError.emptyVersionString
        }
        guard VersionStringValidator.isValid(versionString) else {
            throw VersionCreateValidationError.invalidVersionFormat
        }

        let normalizedPlatform = platform.normalizedASCPlatform
        guard isPlatformAvailableForVersionCreate(normalizedPlatform, versions: versions) else {
            throw VersionCreateValidationError.platformInProgress(platform: normalizedPlatform)
        }

        if versions.contains(where: {
            $0.normalizedPlatform == normalizedPlatform && $0.versionString == versionString
        }) {
            throw VersionCreateValidationError.duplicateVersion(
                versionString: versionString,
                platform: normalizedPlatform
            )
        }

        return (versionString, normalizedPlatform)
    }

    static func compareVersionStrings(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0 ..< count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    static func bumpPatchVersion(_ versionString: String) -> String {
        var parts = versionString.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return "1.0.0" }
        if let last = Int(parts[parts.count - 1]) {
            parts[parts.count - 1] = String(last + 1)
            return parts.joined(separator: ".")
        }
        parts.append("1")
        return parts.joined(separator: ".")
    }

    static func latestVersion(on platform: String, in versions: [AppStoreVersion]) -> AppStoreVersion? {
        let normalized = platform.normalizedASCPlatform
        let platformVersions = versions.filter { $0.normalizedPlatform == normalized }
        guard let versionString = highestValidVersionString(in: platformVersions) else { return nil }
        return platformVersions.first { $0.versionString == versionString }
    }
}
