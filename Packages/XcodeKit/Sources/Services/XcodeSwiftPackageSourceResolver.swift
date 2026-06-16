import Foundation
import XcodeProj

/// 将 Xcode target 关联的 Swift Package 源码纳入 target 文件归属。
enum XcodeSwiftPackageSourceResolver {

    static func resolveTargetSourceFiles(
        projectURL: URL,
        onScanProgress: (@Sendable (String) -> Void)? = nil
    ) -> [String: Set<String>] {
        guard let xcodeProj = try? XcodeProj(pathString: projectURL.path),
              let project = try? xcodeProj.pbxproj.rootProject() ?? xcodeProj.pbxproj.projects.first else {
            return [:]
        }

        let projectRoot = projectURL.deletingLastPathComponent()
        let localPackageRoots = project.localPackages.map {
            projectRoot.appendingPathComponent($0.relativePath).standardizedFileURL
        }

        var result: [String: Set<String>] = [:]
        for target in project.targets {
            var files = Set<String>()
            for dependency in target.packageProductDependencies ?? [] {
                guard let packageRoot = resolveLocalPackageRoot(
                    productName: dependency.productName,
                    localPackageRoots: localPackageRoots
                ) else {
                    continue
                }
                for reachableRoot in SwiftPackageManifestParser.localTransitivePackageRoots(from: packageRoot) {
                    files.formUnion(
                        enumeratePackageSourceFiles(
                            packageRoot: reachableRoot,
                            onScanProgress: onScanProgress
                        )
                    )
                }
            }
            if !files.isEmpty {
                result[target.name] = files
            }
        }

        return result
    }

    static func resolveLocalPackageRoot(
        productName: String,
        localPackageRoots: [URL]
    ) -> URL? {
        localPackageRoots.first { packageExports(productName: productName, packageRoot: $0) }
    }

    static func packageExports(productName: String, packageRoot: URL) -> Bool {
        let manifestURL = packageRoot.appendingPathComponent("Package.swift")
        guard let text = try? String(contentsOf: manifestURL, encoding: .utf8) else { return false }
        let pattern = #"name:\s*"\#(NSRegularExpression.escapedPattern(for: productName))""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    static func enumeratePackageSourceFiles(
        packageRoot: URL,
        onScanProgress: (@Sendable (String) -> Void)? = nil
    ) -> Set<String> {
        let targetRoots = SwiftPackageManifestParser.regularTargetSourceRoots(packageRoot: packageRoot)
        if targetRoots.isEmpty {
            let sourcesRoot = packageRoot.appendingPathComponent("Sources")
            guard FileManager.default.fileExists(atPath: sourcesRoot.path) else { return [] }
            return XcodeProjectFileEnumerator.enumerateFiles(
                in: sourcesRoot,
                excluding: [],
                onScanProgress: onScanProgress
            )
        }

        return targetRoots.reduce(into: Set<String>()) { partial, root in
            let rootURL: URL
            if root.relativePath.hasPrefix("/") {
                rootURL = URL(fileURLWithPath: root.relativePath)
            } else {
                rootURL = packageRoot.appendingPathComponent(root.relativePath)
            }
            partial.formUnion(
                XcodeProjectFileEnumerator.enumerateFiles(
                    in: rootURL,
                    excluding: root.excludedRelativePaths,
                    onScanProgress: onScanProgress
                )
            )
        }
    }
}

enum XcodeProjectFileEnumerator {
    static func enumerateFiles(
        in rootURL: URL,
        excluding excludedRelativePaths: Set<String>,
        onScanProgress: (@Sendable (String) -> Void)? = nil
    ) -> Set<String> {
        let scanReporter: ThrottledScanProgressReporter? = onScanProgress == nil ? nil : ThrottledScanProgressReporter()
        if let values = try? rootURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
           values.isRegularFile == true {
            return excludedRelativePaths.isEmpty ? [XcodeProjectResolver.normalizedMembershipPath(for: rootURL)] : []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files = Set<String>()
        while let fileURL = enumerator.nextObject() as? URL {
            let relativePath = XcodeProjectResolver.path(fileURL, relativeTo: rootURL)
            if excludedRelativePaths.contains(relativePath) {
                continue
            }
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values?.isDirectory == true {
                continue
            }
            if values?.isRegularFile == true {
                let normalizedPath = XcodeProjectResolver.normalizedMembershipPath(for: fileURL)
                files.insert(normalizedPath)
                if let onScanProgress, let scanReporter {
                    scanReporter.report(normalizedPath, handler: onScanProgress)
                }
            }
        }
        return files
    }
}
