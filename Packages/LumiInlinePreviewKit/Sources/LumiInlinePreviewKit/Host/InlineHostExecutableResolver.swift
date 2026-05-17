import Foundation

public extension LumiInlinePreviewFacade {
    /// 定位 `LumiInlinePreviewHostApp` 子进程二进制。
    ///
    /// 解析顺序：
    /// 1. 环境变量 `LUMI_INLINE_PREVIEW_HOST_PATH`（开发期注入）。
    /// 2. 主 bundle 同目录（生产期：`Lumi.app/Contents/MacOS/LumiInlinePreviewHostApp`）。
    /// 3. 主 bundle 的 `Helpers/` 目录（嵌入脚本目标位置）。
    /// 4. 主 bundle 的 `Resources/` 目录（备用：嵌入资源拷贝）。
    /// 5. 包目录（Xcode 本地 SPM 构建产物）。
    /// 6. SwiftPM 默认构建目录（仅用于本地 `swift test`）。
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

            // 1. 环境变量（开发期最高优先级）
            if let envPath = ProcessInfo.processInfo.environment[environmentKey], !envPath.isEmpty {
                result.append(URL(fileURLWithPath: envPath))
            }

            // 2. 主 bundle 同目录（Contents/MacOS/）
            if let mainExe = Bundle.main.executableURL {
                result.append(mainExe.deletingLastPathComponent().appendingPathComponent(executableName))
            }

            // 3. 主 bundle 的 Helpers/ 目录（嵌入脚本放置的位置）
            let bundleURL = Bundle.main.bundleURL
            result.append(bundleURL.appendingPathComponent("Contents/Helpers/\(executableName)"))

            // 4. 主 bundle 的 Resources/ 目录（备用）
            if let resources = Bundle.main.resourceURL {
                result.append(resources.appendingPathComponent(executableName))
            }

            // 5. 通过 bundle 定位 SPM 包目录下的构建产物
            // LumiInlinePreviewKit 作为 Xcode 本地包依赖时，Xcode 直接编译产物到
            // DerivedData，不走 swift build；所以尝试从包源码目录的 .build 查找。
            if let packageURL = packageDirectory() {
                for arch in ["arm64-apple-macosx", "x86_64-apple-macosx"] {
                    for config in ["debug", "release"] {
                        result.append(
                            packageURL
                                .appendingPathComponent(".build")
                                .appendingPathComponent(arch)
                                .appendingPathComponent(config)
                                .appendingPathComponent(executableName)
                        )
                    }
                }
            }

            // 6. SwiftPM 本地测试 fallback：基于 cwd
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

        /// 尝试通过 bundle 中某个已知的 LumiInlinePreviewKit 资源反推包目录。
        private static func packageDirectory() -> URL? {
            // 最直接的方案：检查环境变量 LUMI_INLINE_PREVIEW_PACKAGE_PATH
            if let envPath = ProcessInfo.processInfo.environment["LUMI_INLINE_PREVIEW_PACKAGE_PATH"],
               !envPath.isEmpty {
                return URL(fileURLWithPath: envPath)
            }

            return nil
        }

        private static func isExecutable(at url: URL) -> Bool {
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    }
}
