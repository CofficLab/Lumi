import Foundation

public enum EditorPackageDependencyResolver {
    /// Swift Package Dependencies 仅适用于 Xcode 工程或 Swift Package 项目。
    public static func shouldShowPackageDependencies(projectRootURL: URL) -> Bool {
        let root = projectRootURL.standardizedFileURL
        if findXcodeProject(in: root) != nil { return true }
        if findXcodeWorkspace(in: root) != nil { return true }
        return hasSwiftPackageManifest(at: root)
    }

    public static func resolve(projectRootURL: URL) -> [EditorPackageDependency] {
        let projectRootURL = projectRootURL.standardizedFileURL
        guard let projectURL = findXcodeProject(in: projectRootURL) else {
            return resolveSwiftPackage(projectRootURL: projectRootURL)
        }

        let references = (try? EditorXcodePackageReferenceParser.parse(projectURL: projectURL)) ?? []
        let pins = pinsByIdentity(resolvedFileCandidates(projectRootURL: projectRootURL, projectURL: projectURL))

        return references
            .map { dependency(reference: $0, projectRootURL: projectRootURL, pins: pins) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public static func resolvedFileCandidates(projectRootURL: URL, projectURL: URL? = nil) -> [URL] {
        var candidates: [URL] = []
        if let projectURL {
            candidates.append(
                projectURL
                    .appendingPathComponent("project.xcworkspace", isDirectory: true)
                    .appendingPathComponent("xcshareddata/swiftpm/Package.resolved")
            )
        }
        candidates.append(
            projectRootURL
                .appendingPathComponent(".swiftpm", isDirectory: true)
                .appendingPathComponent("configuration/Package.resolved")
        )
        candidates.append(projectRootURL.appendingPathComponent("Package.resolved"))
        return candidates
    }

    public static func findXcodeProject(in projectRootURL: URL) -> URL? {
        findProjectBundle(in: projectRootURL, pathExtension: "xcodeproj")
    }

    public static func findXcodeWorkspace(in projectRootURL: URL) -> URL? {
        findProjectBundle(in: projectRootURL, pathExtension: "xcworkspace")
    }

    private static func hasSwiftPackageManifest(at projectRootURL: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: projectRootURL.appendingPathComponent("Package.swift").path
        )
    }

    private static func findProjectBundle(in projectRootURL: URL, pathExtension: String) -> URL? {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: projectRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return urls
            .filter { $0.pathExtension == pathExtension }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .first
    }

    public static func watchedManifestURLs(projectRootURL: URL) -> [URL] {
        let projectURL = findXcodeProject(in: projectRootURL)
        var urls: [URL] = []
        if let projectURL {
            urls.append(projectURL.appendingPathComponent("project.pbxproj"))
        }
        urls.append(contentsOf: resolvedFileCandidates(projectRootURL: projectRootURL, projectURL: projectURL))
        return urls
    }

    private static func resolveSwiftPackage(projectRootURL: URL) -> [EditorPackageDependency] {
        let pins = pinsByIdentity(resolvedFileCandidates(projectRootURL: projectRootURL))
        return pins.values
            .map { pin in
                EditorPackageDependency(
                    identity: pin.identity,
                    displayName: EditorPackageResolved.identityFromLocation(pin.location),
                    location: pin.location,
                    kind: .remote,
                    version: pin.version,
                    branch: pin.branch,
                    revision: pin.revision,
                    status: .resolved
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func pinsByIdentity(_ candidates: [URL]) -> [String: EditorResolvedPackagePin] {
        let fileManager = FileManager.default
        for url in candidates where fileManager.fileExists(atPath: url.path) {
            let pins = (try? EditorPackageResolved.parse(url: url)) ?? []
            return pins.reduce(into: [String: EditorResolvedPackagePin]()) { result, pin in
                result[pin.identity] = pin
            }
        }
        return [:]
    }

    private static func dependency(
        reference: EditorXcodePackageReference,
        projectRootURL: URL,
        pins: [String: EditorResolvedPackagePin]
    ) -> EditorPackageDependency {
        if reference.kind == .local {
            let pathURL = URL(fileURLWithPath: reference.location, relativeTo: projectRootURL).standardizedFileURL
            let exists = FileManager.default.fileExists(atPath: pathURL.path)
            return EditorPackageDependency(
                identity: reference.identity,
                displayName: reference.displayName,
                location: pathURL.path,
                kind: .local,
                version: nil,
                branch: nil,
                revision: nil,
                status: exists ? .resolved : .missing("Missing")
            )
        }

        let pin = pins[reference.identity]
        return EditorPackageDependency(
            identity: reference.identity,
            displayName: reference.displayName,
            location: reference.location,
            kind: .remote,
            version: pin?.version ?? reference.version,
            branch: pin?.branch ?? reference.branch,
            revision: pin?.revision ?? reference.revision,
            status: pin == nil ? .unresolved : .resolved
        )
    }
}
