import Foundation

public extension LumiPreviewFacade {
    /// Root-relative paths for preview caches and build work directories.
    struct PreviewStoragePaths: Sendable, Equatable {
        public static let framesDirectoryEnvironmentKey = "LUMI_PREVIEW_FRAMES_DIRECTORY"
        public static let rootDirectoryEnvironmentKey = "LUMI_PREVIEW_STORAGE_ROOT"

        public let rootDirectory: URL

        public init(rootDirectory: URL) {
            self.rootDirectory = rootDirectory
        }

        public var previewEntryCacheDirectory: URL {
            subdirectory("preview-entry-cache")
        }

        public var entryCacheDirectory: URL {
            subdirectory("entry-cache")
        }

        public var compileCommandCacheDirectory: URL {
            subdirectory("compile-command-cache")
        }

        public var framesDirectory: URL {
            subdirectory("frames")
        }

        public var sharedMemoryDirectory: URL {
            subdirectory("shared-memory")
        }

        public var workDirectory: URL {
            subdirectory("work")
        }

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

        /// Creates a unique work directory, falling back to the system temp directory if needed.
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
