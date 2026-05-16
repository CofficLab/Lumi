import AppKit
import Foundation

public extension LumiPreviewFacade {
    /// Loads PNG preview frames written by the hot preview host.
    final class ImageFileLoader: @unchecked Sendable {
        private let fileManager: FileManager
        private let cacheLimit: Int
        private let sharedMemoryFrameChannel: SharedMemoryFrameChannel
        private let lock = NSLock()
        private var cache: [String: NSImage] = [:]
        private var accessOrder: [String] = []

        public init(
            fileManager: FileManager = .default,
            cacheLimit: Int = 16,
            sharedMemoryFrameChannel: SharedMemoryFrameChannel = .init()
        ) {
            self.fileManager = fileManager
            self.cacheLimit = max(0, cacheLimit)
            self.sharedMemoryFrameChannel = sharedMemoryFrameChannel
        }

        public func loadImage(at fileURL: URL) -> NSImage? {
            let key = fileURL.standardizedFileURL.path
            lock.lock()
            if let cached = cache[key] {
                markAccessed(key)
                lock.unlock()
                return cached
            }
            lock.unlock()

            guard fileManager.fileExists(atPath: fileURL.path),
                  let image = NSImage(contentsOf: fileURL) else {
                return nil
            }

            lock.lock()
            cache[key] = image
            markAccessed(key)
            trimCacheIfNeeded()
            lock.unlock()
            return image
        }

        public func loadSharedMemoryImage(
            tag: String,
            width: Int,
            height: Int,
            bytesPerRow: Int
        ) -> NSImage? {
            let key = "shared-memory:\(tag):\(width)x\(height):\(bytesPerRow)"
            lock.lock()
            if let cached = cache[key] {
                markAccessed(key)
                lock.unlock()
                return cached
            }
            lock.unlock()

            guard let mappedFrame = try? sharedMemoryFrameChannel
                    .mapFrame(tag: tag, width: width, height: height, bytesPerRow: bytesPerRow),
                  let image = mappedFrame.makeImage() else {
                return nil
            }
            try? sharedMemoryFrameChannel.removeFrame(tag: tag)

            lock.lock()
            cache[key] = image
            markAccessed(key)
            trimCacheIfNeeded()
            lock.unlock()
            return image
        }

        public func removeCachedImage(at fileURL: URL) {
            let key = fileURL.standardizedFileURL.path
            lock.lock()
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            lock.unlock()
        }

        public func clearCache() {
            lock.lock()
            cache.removeAll()
            accessOrder.removeAll()
            lock.unlock()
        }

        public func cachedImageCount() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return cache.count
        }

        public static func defaultFrameDirectory(fileManager: FileManager = .default) -> URL {
            if let override = ProcessInfo.processInfo.environment[PreviewStoragePaths.framesDirectoryEnvironmentKey],
               !override.isEmpty {
                return URL(fileURLWithPath: override, isDirectory: true)
            }
            return PreviewStorage.paths.framesDirectory
        }

        @discardableResult
        public static func removeExpiredFrames(
            in directory: URL = defaultFrameDirectory(),
            olderThan age: TimeInterval = 60 * 60,
            fileManager: FileManager = .default,
            now: Date = Date()
        ) -> Int {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            ) else {
                return 0
            }

            var removed = 0
            for file in files {
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true,
                      now.timeIntervalSince(values?.contentModificationDate ?? .distantPast) > age else {
                    continue
                }
                if (try? fileManager.removeItem(at: file)) != nil {
                    removed += 1
                }
            }
            return removed
        }

        private func markAccessed(_ key: String) {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
        }

        private func trimCacheIfNeeded() {
            guard cacheLimit > 0 else {
                cache.removeAll()
                accessOrder.removeAll()
                return
            }

            while cache.count > cacheLimit, let oldest = accessOrder.first {
                accessOrder.removeFirst()
                cache.removeValue(forKey: oldest)
            }
        }
    }
}
