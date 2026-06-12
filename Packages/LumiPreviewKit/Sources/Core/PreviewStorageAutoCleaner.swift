import Foundation

public extension LumiPreviewFacade {
    enum PreviewStorageAutoCleaner {
        public struct Policy: Sendable, Equatable {
            public let maximumAge: TimeInterval
            public let maximumSizeBytes: Int64
            public let targetSizeBytes: Int64

            public init(
                maximumAge: TimeInterval,
                maximumSizeBytes: Int64,
                targetSizeBytes: Int64
            ) {
                self.maximumAge = max(0, maximumAge)
                self.maximumSizeBytes = max(0, maximumSizeBytes)
                self.targetSizeBytes = max(0, min(targetSizeBytes, maximumSizeBytes))
            }
        }

        public struct Result: Sendable, Equatable {
            public let removedItemCount: Int
            public let removedByteCount: Int64
            public let remainingByteCount: Int64

            public static let empty = Result(
                removedItemCount: 0,
                removedByteCount: 0,
                remainingByteCount: 0
            )
        }

        private struct CacheItem {
            let url: URL
            let modifiedAt: Date
            let byteCount: Int64
        }

        public static func clean(
            directories: [URL],
            policy: Policy,
            now: Date = Date(),
            fileManager: FileManager = .default
        ) -> Result {
            let uniqueDirectories = Array(Set(directories))
            var items = uniqueDirectories.flatMap { directory in
                topLevelItems(in: directory, fileManager: fileManager)
            }

            var removedItemCount = 0
            var removedByteCount: Int64 = 0
            let ageCutoff = now.addingTimeInterval(-policy.maximumAge)

            for item in items where item.modifiedAt < ageCutoff {
                if remove(item, fileManager: fileManager) {
                    removedItemCount += 1
                    removedByteCount += item.byteCount
                }
            }

            items.removeAll { $0.modifiedAt < ageCutoff }
            var remainingByteCount = items.reduce(Int64(0)) { $0 + $1.byteCount }

            if policy.maximumSizeBytes > 0, remainingByteCount > policy.maximumSizeBytes {
                for item in items.sorted(by: { $0.modifiedAt < $1.modifiedAt }) {
                    guard remainingByteCount > policy.targetSizeBytes else { break }
                    if remove(item, fileManager: fileManager) {
                        removedItemCount += 1
                        removedByteCount += item.byteCount
                        remainingByteCount -= item.byteCount
                    }
                }
            }

            for directory in uniqueDirectories {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                removeEmptyDescendantDirectories(in: directory, fileManager: fileManager)
            }

            return Result(
                removedItemCount: removedItemCount,
                removedByteCount: removedByteCount,
                remainingByteCount: max(0, remainingByteCount)
            )
        }

        private static func topLevelItems(
            in directory: URL,
            fileManager: FileManager
        ) -> [CacheItem] {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return urls.map { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                return CacheItem(
                    url: url,
                    modifiedAt: values?.contentModificationDate ?? .distantPast,
                    byteCount: recursiveByteCount(url, fileManager: fileManager)
                )
            }
        }

        private static func recursiveByteCount(
            _ url: URL,
            fileManager: FileManager
        ) -> Int64 {
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
            if let values = try? url.resourceValues(forKeys: keys),
               values.isRegularFile == true {
                return Int64(values.fileSize ?? 0)
            }

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            ) else {
                return 0
            }

            var total: Int64 = 0
            for case let child as URL in enumerator {
                guard let values = try? child.resourceValues(forKeys: keys),
                      values.isRegularFile == true else {
                    continue
                }
                total += Int64(values.fileSize ?? 0)
            }
            return total
        }

        private static func remove(_ item: CacheItem, fileManager: FileManager) -> Bool {
            do {
                try fileManager.removeItem(at: item.url)
                return true
            } catch {
                return false
            }
        }

        private static func removeEmptyDescendantDirectories(
            in directory: URL,
            fileManager: FileManager
        ) {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return
            }

            let directories = enumerator.compactMap { element -> URL? in
                guard let url = element as? URL,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true else {
                    return nil
                }
                return url
            }

            for url in directories.sorted(by: { $0.path.count > $1.path.count }) {
                guard let contents = try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil
                ), contents.isEmpty else {
                    continue
                }
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
