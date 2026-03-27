import Foundation

enum ManifestSection {
    private static let exactNames = [
        "package.json", "Cargo.toml", "Package.swift", "Podfile", "pyproject.toml", "go.mod",
        "requirements.txt", "Gemfile", "build.gradle", "build.gradle.kts", "pom.xml",
        "composer.json", "pubspec.yaml", "mix.exs", "build.sbt", "stack.yaml", "build.zig", "DESCRIPTION"
    ]

    static func render(at root: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: root.path) else { return "(Unable to list)" }
        var found: [String] = contents.filter { exactNames.contains($0) }
        let xcodeProjects = contents.filter { $0.hasSuffix(".xcodeproj") }
        let dotnetSolutions = contents.filter { $0.hasSuffix(".sln") }
        let dotnetProjects = contents.filter { $0.hasSuffix(".csproj") }
        let cabalFiles = contents.filter { $0.hasSuffix(".cabal") }
        found.append(contentsOf: xcodeProjects)
        found.append(contentsOf: dotnetSolutions)
        found.append(contentsOf: dotnetProjects)
        found.append(contentsOf: cabalFiles)
        return found.isEmpty ? "None of the common manifest files found at root." : found.sorted().joined(separator: ", ")
    }
}
