import Foundation

public enum WorkspaceDetector {
    public struct Workspace: Sendable {
        public let rootPath: String
        public let packagePaths: [String]
        public let manager: JSPackageInfo.PackageManager
        public let framework: JSPackageInfo.JSFramework?
        public let builder: JSPackageInfo.Builder?
    }

    public static func detect(projectPath: String) -> Workspace? {
        let root = findRoot(from: URL(fileURLWithPath: projectPath)) ?? URL(fileURLWithPath: projectPath)
        let package = PackageJSONParser.parse(projectPath: root.path)
        return Workspace(
            rootPath: root.path,
            packagePaths: packageDirectories(root: root),
            manager: JSEnvResolver.detectPackageManager(projectPath: root.path),
            framework: package?.inferredFramework,
            builder: package?.inferredBuilder
        )
    }

    public static func findRoot(from url: URL) -> URL? {
        var current = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("package.json").path) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }

    private static func packageDirectories(root: URL) -> [String] {
        guard let package = PackageJSONParser.parse(projectPath: root.path) else { return [root.path] }
        var result = [root.path]
        if package.devDependencies["turbo"] != nil || package.packageManager?.contains("pnpm") == true {
            result.append(contentsOf: globWorkspacePackages(root: root))
        }
        return Array(Set(result)).sorted()
    }

    private static func globWorkspacePackages(root: URL) -> [String] {
        let common = ["packages", "apps"]
        return common.flatMap { folder -> [String] in
            let url = root.appendingPathComponent(folder)
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return children.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && FileManager.default.fileExists(atPath: $0.appendingPathComponent("package.json").path)
            }.map(\.path)
        }
    }
}
