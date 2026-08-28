import Foundation

@MainActor
enum MLXModelPaths {
    private static let fallbackRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("com.coffic.lumi/LLMProviderMLX", isDirectory: true)

    static var rootDirectory = fallbackRoot

    static func configure(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    static var modelsDirectory: URL {
        rootDirectory.appendingPathComponent("models", isDirectory: true)
    }

    static func modelDirectory(for modelID: String) -> URL {
        let components = modelID.split(separator: "/").map { sanitize(String($0)) }
        return components.reduce(modelsDirectory) { $0.appendingPathComponent($1, isDirectory: true) }
    }

    private static func sanitize(_ component: String) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return "_" }
        return trimmed
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }
}
