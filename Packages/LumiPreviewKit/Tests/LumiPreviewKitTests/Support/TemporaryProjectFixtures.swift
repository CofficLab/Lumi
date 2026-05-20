import Foundation

enum TemporaryProjectFixtures {
    static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func writeSwiftFileWithPreview(
        at fileURL: URL,
        previewLabel: String,
        body: String? = nil
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let previewBody = body ?? "Text(\"\(previewLabel)\")"
        let source = """
        import SwiftUI

        struct \(previewLabel)View: View {
            var body: some View { \(previewBody) }
        }

        #Preview("\(previewLabel)") {
            \(previewLabel)View()
        }
        """
        try source.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func makeSPMPackage(
        in directory: URL,
        targetName: String = "App",
        previewFiles: [(name: String, label: String)] = [("ContentView", "Main")]
    ) throws -> (packageDirectory: URL, sourceFiles: [URL]) {
        let packageDirectory = directory
        let sourcesRoot = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesRoot, withIntermediateDirectories: true)

        var sourceFiles: [URL] = []
        for file in previewFiles {
            let fileURL = sourcesRoot.appendingPathComponent("\(file.name).swift")
            try writeSwiftFileWithPreview(at: fileURL, previewLabel: file.label)
            sourceFiles.append(fileURL)
        }

        let packageManifest = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "PreviewTestPkg",
            platforms: [.macOS(.v14)],
            products: [],
            targets: [
                .target(name: "\(targetName)", path: "Sources/\(targetName)")
            ]
        )
        """
        try packageManifest.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let testsDirectory = packageDirectory.appendingPathComponent("Tests/Ignored", isDirectory: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try writeSwiftFileWithPreview(
            at: testsDirectory.appendingPathComponent("Ignored.swift"),
            previewLabel: "Ignored"
        )

        let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        try "ignored".write(
            to: buildDirectory.appendingPathComponent("ignored.txt"),
            atomically: true,
            encoding: .utf8
        )

        let nodeModules = packageDirectory.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try writeSwiftFileWithPreview(
            at: nodeModules.appendingPathComponent("Ignored.swift"),
            previewLabel: "NodeIgnored"
        )

        return (packageDirectory, sourceFiles)
    }

    static func makeBareSwiftDirectory(in directory: URL) throws -> URL {
        let sources = directory.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try writeSwiftFileWithPreview(
            at: sources.appendingPathComponent("Loose.swift"),
            previewLabel: "Loose"
        )
        return directory
    }

    static func makeDualXcodeProjects(in directory: URL) throws -> (first: URL, second: URL, swiftFile: URL) {
        let firstProject = directory.appendingPathComponent("First.xcodeproj", isDirectory: true)
        let secondProject = directory.appendingPathComponent("Second.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: firstProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondProject, withIntermediateDirectories: true)

        let sources = directory.appendingPathComponent("Shared", isDirectory: true)
        let swiftFile = sources.appendingPathComponent("Shared.swift")
        try writeSwiftFileWithPreview(at: swiftFile, previewLabel: "Shared")
        return (firstProject, secondProject, swiftFile)
    }
}
