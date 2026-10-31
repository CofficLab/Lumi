import Foundation
import KitTestIsolation

@MainActor
enum MLXModelPaths {
    /// `onBoot` 注入的模型根目录。未注入时为 `nil`。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    nonisolated(unsafe) static var injectedRootDirectory: URL?

    /// 模型根目录。
    static var rootDirectory: URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedRootDirectory,
            owner: "MLXModelPaths",
            accessor: "rootDirectory",
            fallback: { productionFallbackRoot }
        )
    }

    static func configure(rootDirectory: URL) {
        injectedRootDirectory = rootDirectory
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    /// 生产环境兜底根目录。
    private static let productionFallbackRoot = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("com.coffic.lumi/LLMProviderMLX", isDirectory: true)

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
