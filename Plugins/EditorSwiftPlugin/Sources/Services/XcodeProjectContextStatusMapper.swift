import EditorService
import Foundation

enum XcodeProjectContextStatusMapper {
    static func map(description: String) -> EditorProjectContextStatus {
        if description.contains("Needs resync") {
            return .needsResync
        }
        if description.contains("Resolving build context...") {
            return .resolving
        }
        if description.contains(": ") && !description.contains("Available") {
            let prefix = "Unavailable" + ": "
            if description.hasPrefix(prefix) {
                return .unavailable(String(description.dropFirst(prefix.count)))
            }
            return .unavailable(description)
        }
        if description.contains("Available") {
            return .available(description)
        }
        if description == "Not Initialized" || description == "Unknown" {
            return .unknown
        }
        return .available(description)
    }
}
