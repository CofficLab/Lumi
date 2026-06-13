import Foundation

/// Fast scheme discovery by reading `.xcscheme` files on disk.
enum XcodeSchemeDiscovery {
    static func discoverSchemeNames(at projectLikeURL: URL) -> [String] {
        let schemeNames = schemeFileURLs(at: projectLikeURL).map {
            $0.deletingPathExtension().lastPathComponent
        }
        return XcodeProjectResolver.uniquePreservingOrder(schemeNames.filter { !$0.isEmpty })
    }

    static func schemeFileURLs(at projectLikeURL: URL) -> [URL] {
        switch projectLikeURL.pathExtension {
        case "xcodeproj":
            return schemeFiles(in: projectLikeURL)
        case "xcworkspace":
            var files = schemeFiles(in: projectLikeURL)
            let parent = projectLikeURL.deletingLastPathComponent()
            if let siblings = try? FileManager.default.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for sibling in siblings where sibling.pathExtension == "xcodeproj" {
                    files.append(contentsOf: schemeFiles(in: sibling))
                }
            }
            return uniqueSchemeFilesPreservingOrder(files)
        default:
            return []
        }
    }

    private static func schemeFiles(in bundleURL: URL) -> [URL] {
        var files: [URL] = []
        let sharedSchemes = bundleURL.appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        files.append(contentsOf: listXCSchemes(in: sharedSchemes))

        let userData = bundleURL.appendingPathComponent("xcuserdata", isDirectory: true)
        if let users = try? FileManager.default.contentsOfDirectory(
            at: userData,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for user in users {
                let userSchemes = user.appendingPathComponent("xcschemes", isDirectory: true)
                files.append(contentsOf: listXCSchemes(in: userSchemes))
            }
        }
        return files
    }

    private static func listXCSchemes(in directory: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "xcscheme" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func uniqueSchemeFilesPreservingOrder(_ files: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard seen.insert(name).inserted else { continue }
            result.append(file)
        }
        return result
    }
}
