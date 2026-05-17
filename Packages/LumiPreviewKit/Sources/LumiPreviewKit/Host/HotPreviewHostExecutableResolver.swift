import Foundation

public extension LumiPreviewFacade {
    /// Hot 预览宿主进程可执行文件路径解析器。
    ///
    /// 按优先级查找 `LumiHotPreviewHostApp` 可执行文件：
    /// 1. 环境变量 `LUMI_HOT_PREVIEW_HOST_EXECUTABLE` 指定的路径
    /// 2. Bundle 内 `Contents/Helpers/` 目录
    /// 3. Bundle 内 `Contents/MacOS/` 目录
    enum HotPreviewHostExecutableResolver {
        /// 环境变量键：覆盖宿主进程可执行文件路径。
        public static let environmentOverrideKey = "LUMI_HOT_PREVIEW_HOST_EXECUTABLE"

        /// 解析宿主进程可执行文件路径。
        ///
        /// - Parameters:
        ///   - environment: 环境变量字典，默认使用当前进程环境。
        ///   - bundle: 搜索 Bundle，默认使用 `main` Bundle。
        ///   - fileManager: 文件管理器，默认使用 `.default`。
        /// - Returns: 找到的可执行文件 URL；未找到时返回 `nil`。
        public static func resolve(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            bundle: Bundle = .main,
            fileManager: FileManager = .default
        ) -> URL? {
            if let explicitPath = environment[environmentOverrideKey],
               !explicitPath.isEmpty {
                let url = URL(fileURLWithPath: explicitPath)
                if fileManager.isExecutableFile(atPath: url.path) {
                    return url
                }
            }

            return candidates(in: bundle).first {
                fileManager.isExecutableFile(atPath: $0.path)
            }
        }

        /// 返回所有候选的可执行文件路径，按搜索优先级排列。
        public static func candidates(in bundle: Bundle = .main) -> [URL] {
            [
                bundle.bundleURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("Helpers", isDirectory: true)
                    .appendingPathComponent("LumiHotPreviewHostApp"),
                bundle.bundleURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("MacOS", isDirectory: true)
                    .appendingPathComponent("LumiHotPreviewHostApp"),
                bundle.resourceURL?
                    .appendingPathComponent("LumiHotPreviewHostApp")
            ].compactMap { $0 }
        }
    }
}
