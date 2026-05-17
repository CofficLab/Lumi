import Foundation

public extension LumiInlinePreviewFacade {
    /// 定位 `LumiInlinePreviewHostApp` 子进程二进制。
    ///
    /// 解析顺序：
    /// 1. 环境变量 `LUMI_INLINE_PREVIEW_HOST_PATH`（开发期注入）。
    /// 2. 主 bundle 同目录（生产期：`Lumi.app/Contents/MacOS/LumiInlinePreviewHostApp`）。
    /// 3. 主 bundle 的 `Resources/` 目录（备用：嵌入资源拷贝）。
    /// 4. SwiftPM 默认构建目录（仅用于本地 `swift test`）。
    enum InlineHostExecutableResolver {
        public static let executableName = "LumiInlinePreviewHostApp"
        public static let environmentKey = "LUMI_INLINE_PREVIEW_HOST_PATH"

        // MARK: - 公开方法

        public static func resolve() -> URL? {
            for candidate in candidates() where isExecutable(at: candidate) {
                return candidate
            }
            return nil
        }

        // MARK: - 私有

        private static func candidates() -> [URL] {
            var result: [URL] = []
            let fm = FileManager.default

            if let envPath = ProcessInfo.processInfo.environment[environmentKey], !envPath.isEmpty {
                result.append(URL(fileURLWithPath: envPath))
            }

            if let mainExe = Bundle.main.executableURL {
                result.append(mainExe.deletingLastPathComponent().appendingPathComponent(executableName))
            }

            if let resources = Bundle.main.resourceURL {
                result.append(resources.appendingPathComponent(executableName))
            }

            // 本地 SPM 调试：寻找最近的 .build 目录。
            let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
            for arch in ["arm64-apple-macosx", "x86_64-apple-macosx"] {
                for config in ["debug", "release"] {
                    result.append(
                        cwd
                            .appendingPathComponent(".build")
                            .appendingPathComponent(arch)
                            .appendingPathComponent(config)
                            .appendingPathComponent(executableName)
                    )
                }
            }

            return result
        }

        private static func isExecutable(at url: URL) -> Bool {
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    }
}
