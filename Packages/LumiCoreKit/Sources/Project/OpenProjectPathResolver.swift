import Foundation

public enum OpenProjectPathResolver {
    public static func normalizePath(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasSuffix("/") {
            str = String(str.dropLast())
        }

        if str.hasPrefix("file://") {
            if let url = URL(string: str) {
                return url.path
            }

            let path = String(str.dropFirst("file://".count))
            return path.isEmpty ? raw : path
        }

        if str.hasPrefix("/") {
            return str.removingPercentEncoding ?? str
        }

        return str
    }

    public static func resolveProjectRoot(
        from path: String,
        fileManager: FileManager = .default,
        maxLevels: Int = 10
    ) -> String {
        let normalizedPath = normalizePath(path)
        var currentURL = URL(fileURLWithPath: normalizedPath)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: normalizedPath, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            currentURL = currentURL.deletingLastPathComponent()
        }

        for _ in 0 ..< maxLevels {
            let gitPath = currentURL.appendingPathComponent(".git").path
            if fileManager.fileExists(atPath: gitPath) {
                return currentURL.path
            }

            let parent = currentURL.deletingLastPathComponent()
            if parent.path == currentURL.path {
                break
            }
            currentURL = parent
        }

        return normalizedPath
    }

    public static func resolvePath(
        fromOpenURL url: URL,
        fileManager: FileManager = .default
    ) -> String? {
        guard url.scheme == "lumi" else { return nil }

        if url.host?.lowercased() == "openrepo" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let path = components?.queryItems?.first(where: { $0.name == "path" })?.value,
                  !path.isEmpty else {
                return nil
            }
            return resolveProjectRoot(from: path, fileManager: fileManager)
        }

        guard !url.path.isEmpty else { return nil }
        return resolveProjectRoot(from: url.path, fileManager: fileManager)
    }
}

public enum LumiOpenProjectUserInfoKey {
    public static let path = "path"
}

public extension Notification.Name {
    static let lumiOpenExternalProject = Notification.Name("lumi.openExternalProject")
}
