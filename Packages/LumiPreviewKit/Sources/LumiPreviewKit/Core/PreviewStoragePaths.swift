import Foundation

public extension LumiPreviewFacade {
    /// 预览系统的存储路径配置。
    ///
    /// 以一个根目录为基础，为各类缓存、帧数据、共享内存和构建工作目录
    /// 提供统一的子目录管理。支持通过环境变量覆盖特定路径。
    struct PreviewStoragePaths: Sendable, Equatable {
        /// 环境变量键：覆盖帧数据存储目录。
        public static let framesDirectoryEnvironmentKey = "LUMI_PREVIEW_FRAMES_DIRECTORY"

        /// 环境变量键：覆盖存储根目录。
        public static let rootDirectoryEnvironmentKey = "LUMI_PREVIEW_STORAGE_ROOT"

        /// 存储根目录，所有子目录均基于此路径派生。
        public let rootDirectory: URL

        public init(rootDirectory: URL) {
            self.rootDirectory = rootDirectory
        }

        /// 预览入口 dylib 缓存目录（由 `PreviewEntryBuilder` 生成的 dylib）。
        public var previewEntryCacheDirectory: URL {
            subdirectory("preview-entry-cache")
        }

        /// 入口缓存元数据目录（由 `EntryCacheManager` 管理）。
        public var entryCacheDirectory: URL {
            subdirectory("entry-cache")
        }

        /// 编译命令缓存目录（由 `CompileCommandCache` 管理）。
        public var compileCommandCacheDirectory: URL {
            subdirectory("compile-command-cache")
        }

        /// PNG 帧图片目录（用于宿主进程写入离屏渲染截图）。
        public var framesDirectory: URL {
            subdirectory("frames")
        }

        /// 共享内存目录（用于跨进程帧数据传输的 mmap 文件）。
        public var sharedMemoryDirectory: URL {
            subdirectory("shared-memory")
        }

        /// 临时构建工作目录（用于增量编译产物）。
        public var workDirectory: URL {
            subdirectory("work")
        }

        /// 创建一个带有 UUID 的临时工作子目录。
        ///
        /// - Parameter component: 子目录分类名，如 `"incremental-compiler"`。
        /// - Returns: 新创建的临时目录 URL。
        public func transientWorkDirectory(
            component: String,
            fileManager: FileManager = .default
        ) throws -> URL {
            let parent = workDirectory
                .appendingPathComponent(component, isDirectory: true)
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            let directory = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }

        /// 确保所有预定义子目录均已创建。
        ///
        /// 在首次使用存储路径前调用，避免后续操作因目录不存在而失败。
        public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
            for directory in [
                rootDirectory,
                previewEntryCacheDirectory,
                entryCacheDirectory,
                compileCommandCacheDirectory,
                framesDirectory,
                sharedMemoryDirectory,
                workDirectory
            ] {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }

        /// 系统默认存储路径，使用用户 Caches 目录下的 `LumiPreviewKit` 子目录。
        /// 若 Caches 目录不可用，则降级到系统临时目录。
        public static var systemDefault: PreviewStoragePaths {
            let fileManager = FileManager.default
            if let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                return PreviewStoragePaths(
                    rootDirectory: cachesRoot
                        .appendingPathComponent("LumiPreviewKit", isDirectory: true)
                )
            }
            return PreviewStoragePaths(
                rootDirectory: fileManager.temporaryDirectory
                    .appendingPathComponent("LumiPreviewKit-Storage", isDirectory: true)
            )
        }

        /// 创建一个唯一临时工作目录，失败时降级到系统临时目录。
        ///
        /// - Parameter component: 子目录分类名，如 `"incremental-compiler"`。
        /// - Returns: 新创建的临时目录 URL。
        public static func makeTransientWorkDirectory(
            component: String,
            fileManager: FileManager = .default
        ) -> URL {
            if let directory = try? PreviewStorage.paths.transientWorkDirectory(
                component: component,
                fileManager: fileManager
            ) {
                return directory
            }

            let directory = fileManager.temporaryDirectory
                .appendingPathComponent("LumiPreviewKit-\(component)-\(UUID().uuidString)", isDirectory: true)
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }

        private func subdirectory(_ name: String) -> URL {
            rootDirectory.appendingPathComponent(name, isDirectory: true)
        }
    }
}
