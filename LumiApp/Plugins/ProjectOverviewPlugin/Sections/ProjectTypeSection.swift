import Foundation

enum ProjectTypeSection {
    static func render(at root: URL) -> String {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { return "Unknown" }

        let set = Set(names)
        var types: [String] = []

        if set.contains("Package.swift") || set.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            types.append("Swift (Xcode / SPM)")
        }
        if set.contains("package.json") {
            types.append("Node / JavaScript")
        }
        if set.contains("Cargo.toml") {
            types.append("Rust")
        }
        if set.contains("pyproject.toml") || set.contains("requirements.txt") {
            types.append("Python")
        }
        if set.contains("go.mod") {
            types.append("Go")
        }
        if set.contains("Gemfile") {
            types.append("Ruby")
        }
        if set.contains("build.gradle") || set.contains("build.gradle.kts") || set.contains("pom.xml") {
            types.append("Java / Kotlin")
        }
        if set.contains(where: { $0.hasSuffix(".sln") }) || set.contains(where: { $0.hasSuffix(".csproj") }) {
            types.append("C# / .NET")
        }
        if set.contains("composer.json") {
            types.append("PHP")
        }
        if set.contains("pubspec.yaml") {
            types.append("Dart / Flutter")
        }
        if set.contains("mix.exs") {
            types.append("Elixir")
        }
        if set.contains("build.sbt") {
            types.append("Scala")
        }
        if set.contains("stack.yaml") || set.contains(where: { $0.hasSuffix(".cabal") }) {
            types.append("Haskell")
        }
        if set.contains("build.zig") {
            types.append("Zig")
        }
        if set.contains("DESCRIPTION") {
            types.append("R")
        }

        return types.isEmpty ? "Unknown" : types.joined(separator: "; ")
    }
}
