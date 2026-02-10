import Foundation
import OSLog

// MARK: - System Utilities

class SystemUtil {
    static let emoji = "🔧"

    /// Check if current macOS version meets minimum requirement
    static func isMacOSVersion(atLeast major: Int, _ minor: Int = 0, _ patch: Int = 0) -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion

        if osVersion.majorVersion > major {
            return true
        } else if osVersion.majorVersion == major {
            if osVersion.minorVersion > minor {
                return true
            } else if osVersion.minorVersion == minor {
                return osVersion.patchVersion >= patch
            }
        }
        return false
    }

    /// Get formatted macOS version string for logging
    static func macOSVersionString() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// Get detailed version components
    static func macOSVersion() -> (major: Int, minor: Int, patch: Int) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return (osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion)
    }

    /// Log current system information
    static func logSystemInfo() {
        let version = macOSVersion()
        os_log("\(SystemUtil.t)macOS \(version.major).\(version.minor).\(version.patch)")
        os_log("\(SystemUtil.t)Version string: \(macOSVersionString())")
    }
}

// MARK: - Log Helper

extension SystemUtil {
    static var t: String {
        return "[\(emoji)] "
    }
}
