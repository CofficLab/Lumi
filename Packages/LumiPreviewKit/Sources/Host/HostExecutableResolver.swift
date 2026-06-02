import Foundation

public extension LumiPreviewFacade {
    /// 定位 `LumiPreviewHostApp` 子进程二进制。
    ///
    /// 解析顺序：
    /// 1. 环境变量 `LUMI_INLINE_PREVIEW_HOST_PATH`（开发期注入）。
    /// 2. 主 bundle 同目录（生产期：`Lumi.app/Contents/MacOS/LumiPreviewHostApp`）。
    /// 3. 主 bundle 的 `Helpers/` 目录（嵌入脚本目标位置）。
    /// 4. 主 bundle 的 `Resources/` 目录（备用：嵌入资源拷贝）。
    /// 5. Xcode 产品目录（Debug 运行：`Build/Products/Debug/LumiPreviewHostApp`）。
    /// 6. 包目录（SwiftPM 构建产物）。
    /// 7. SwiftPM 默认构建目录（仅用于本地 `swift test`）。
    enum HostExecutableResolver {
        public static let executableName = "LumiPreviewHostApp"
        public static let environmentKey = "LUMI_INLINE_PREVIEW_HOST_PATH"
        static let packagePathEnvironmentKey = "LUMI_INLINE_PREVIEW_PACKAGE_PATH"

        // MARK: - 公开方法

        public static func resolve() -> URL? {
            resolve(
                environment: ProcessInfo.processInfo.environment,
                mainExecutableURL: Bundle.main.executableURL,
                bundleURL: Bundle.main.bundleURL,
                resourceURL: Bundle.main.resourceURL,
                currentDirectoryPath: FileManager.default.currentDirectoryPath,
                isExecutable: { FileManager.default.isExecutableFile(atPath: $0.path) }
            )
        }

        static func resolve(
            environment: [String: String],
            mainExecutableURL: URL?,
            bundleURL: URL,
            resourceURL: URL?,
            currentDirectoryPath: String,
            isExecutable: (URL) -> Bool
        ) -> URL? {
            for candidate in candidates(
                environment: environment,
                mainExecutableURL: mainExecutableURL,
                bundleURL: bundleURL,
                resourceURL: resourceURL,
                currentDirectoryPath: currentDirectoryPath
            ) where isExecutable(candidate) {
                return candidate
            }
            return nil
        }

        // MARK: - 私有

        static func candidates(
            environment: [String: String],
            mainExecutableURL: URL?,
            bundleURL: URL,
            resourceURL: URL?,
            currentDirectoryPath: String
        ) -> [URL] {
            var result: [URL] = []

            // 1. 环境变量（开发期最高优先级）
            if let envPath = environment[environmentKey], !envPath.isEmpty {
                result.append(URL(fileURLWithPath: envPath))
            }

            // 2. 主 bundle 同目录（Contents/MacOS/）
            if let mainExe = mainExecutableURL {
                result.append(mainExe.deletingLastPathComponent().appendingPathComponent(executableName))
            }

            // 3. 主 bundle 的 Helpers/ 目录（嵌入脚本放置的位置）
            result.append(bundleURL.appendingPathComponent("Contents/Helpers/\(executableName)"))

            // 4. 主 bundle 的 Resources/ 目录（备用）
            if let resources = resourceURL {
                result.append(resources.appendingPathComponent(executableName))
            }

            // 5. Xcode Debug 运行时，executable target 会落在 app bundle 的父级产品目录。
            if bundleURL.pathExtension == "app" {
                result.append(
                    bundleURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(executableName)
                )
            }

            // 6. 通过包源码目录定位 SwiftPM 构建产物。Xcode 运行 app 时 cwd 通常是 `/`，
            // 不能依赖 cwd 找到本地包的 `.build`。
            if let packageURL = packageDirectory(environment: environment) {
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

            // 7. SwiftPM 本地测试 fallback：基于 cwd
            let cwd = URL(fileURLWithPath: currentDirectoryPath)
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

        /// 尝试通过 bundle 中某个已知的 LumiPreviewKit 资源反推包目录。
        private static func packageDirectory(environment: [String: String]) -> URL? {
            // 最直接的方案：检查环境变量 LUMI_INLINE_PREVIEW_PACKAGE_PATH
            if let envPath = environment[packagePathEnvironmentKey],
               !envPath.isEmpty {
                return URL(fileURLWithPath: envPath)
            }

            return sourcePackageDirectory()
        }

        private static func sourcePackageDirectory(filePath: String = #filePath) -> URL? {
            let fileURL = URL(fileURLWithPath: filePath)
            let packageURL = fileURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()

            return packageURL.lastPathComponent == "LumiPreviewKit" ? packageURL : nil
        }
    }
}
