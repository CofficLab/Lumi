import AppKit
import CoreGraphics
import Darwin
import Foundation

@_silgen_name("shm_open")
private func lumi_shm_open(
    _ name: UnsafePointer<CChar>,
    _ oflag: Int32,
    _ mode: mode_t
) -> Int32

public extension LumiPreviewFacade {
    final class SharedMemoryFrameChannel: @unchecked Sendable {
        public enum BackendKind: String, Sendable, Equatable {
            case mappedFile
            case mach
        }

        public enum BackendPreference: String, Sendable, Equatable {
            case automatic
            case mappedFile
            case mach
        }

        public enum BackendAvailability: Sendable, Equatable {
            case available
            case unavailable(reason: String)
        }

        public struct BackendResolution: Sendable, Equatable {
            public let requested: BackendPreference
            public let effective: BackendKind
            public let usedFallbackBackend: Bool
            public let reason: String?

            public init(
                requested: BackendPreference,
                effective: BackendKind,
                usedFallbackBackend: Bool,
                reason: String?
            ) {
                self.requested = requested
                self.effective = effective
                self.usedFallbackBackend = usedFallbackBackend
                self.reason = reason
            }
        }

        public struct FrameDescriptor: Sendable, Equatable {
            public let tag: String
            public let width: Int
            public let height: Int
            public let bytesPerRow: Int

            public var byteCount: Int { bytesPerRow * height }

            public init(tag: String, width: Int, height: Int, bytesPerRow: Int) {
                self.tag = tag
                self.width = width
                self.height = height
                self.bytesPerRow = bytesPerRow
            }
        }

        public enum ChannelError: Error, Equatable, LocalizedError {
            case invalidDimensions
            case backendUnavailable(kind: BackendKind, reason: String)
            case openFailed(path: String, code: Int32)
            case truncateFailed(path: String, code: Int32)
            case mapFailed(path: String, code: Int32)
            case removeFailed(path: String, code: Int32)
            case writeFailed

            public var errorDescription: String? {
                switch self {
                case .invalidDimensions:
                    return "Frame dimensions are invalid."
                case .backendUnavailable(let kind, let reason):
                    return "Backend '\(kind.rawValue)' is unavailable: \(reason)"
                case .openFailed(let path, let code):
                    return "Failed to open mapped frame file '\(path)' (\(code))."
                case .truncateFailed(let path, let code):
                    return "Failed to resize mapped frame file '\(path)' (\(code))."
                case .mapFailed(let path, let code):
                    return "Failed to map frame file '\(path)' (\(code))."
                case .removeFailed(let path, let code):
                    return "Failed to remove mapped frame file '\(path)' (\(code))."
                case .writeFailed:
                    return "Failed to write frame bytes into shared memory."
                }
            }
        }

        public final class MappedFrame: @unchecked Sendable {
            public let descriptor: FrameDescriptor
            private let fileDescriptor: Int32
            private let baseAddress: UnsafeMutableRawPointer

            init(
                descriptor: FrameDescriptor,
                fileDescriptor: Int32,
                baseAddress: UnsafeMutableRawPointer
            ) {
                self.descriptor = descriptor
                self.fileDescriptor = fileDescriptor
                self.baseAddress = baseAddress
            }

            deinit {
                munmap(baseAddress, descriptor.byteCount)
                close(fileDescriptor)
            }

            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try body(
                    UnsafeRawBufferPointer(
                        start: UnsafeRawPointer(baseAddress),
                        count: descriptor.byteCount
                    )
                )
            }

            public func makeImage() -> NSImage? {
                let data = Data(bytes: baseAddress, count: descriptor.byteCount)
                guard let provider = CGDataProvider(data: data as CFData),
                      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                      let cgImage = CGImage(
                        width: descriptor.width,
                        height: descriptor.height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 32,
                        bytesPerRow: descriptor.bytesPerRow,
                        space: colorSpace,
                        bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
                            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                        ),
                        provider: provider,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent
                      ) else {
                    return nil
                }

                return NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: descriptor.width, height: descriptor.height)
                )
            }
        }

        private let namePrefix: String
        private let directory: URL
        private let backend: any FrameStorageBackend
        public let preferredBackend: BackendPreference
        public let usedFallbackBackend: Bool
        public let backendResolution: BackendResolution

        public static let backendOverrideEnvironmentKey = "LUMI_HOT_PREVIEW_SHARED_MEMORY_BACKEND"

        public var backendKind: BackendKind {
            backend.kind
        }

        public static var machBackendAvailability: BackendAvailability {
            .available
        }

        public static func defaultDirectory(fileManager: FileManager = .default) -> URL {
            PreviewStorage.paths.sharedMemoryDirectory
        }

        public init(
            namePrefix: String = "lumi-hot-preview-frame-",
            directory: URL = defaultDirectory(),
            preferredBackend: BackendPreference = .automatic,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) {
            self.namePrefix = namePrefix
            self.directory = directory
            let requestedBackend = Self.backendPreference(from: environment) ?? preferredBackend
            self.preferredBackend = requestedBackend
            let resolved = Self.resolveBackend(preferredBackend: requestedBackend)
            self.backend = resolved.backend
            self.usedFallbackBackend = resolved.usedFallbackBackend
            self.backendResolution = BackendResolution(
                requested: requestedBackend,
                effective: resolved.backend.kind,
                usedFallbackBackend: resolved.usedFallbackBackend,
                reason: resolved.reason
            )
        }

        @discardableResult
        public static func removeExpiredFrames(
            in directory: URL = defaultDirectory(),
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

        public func writeFrame(
            tag: String = UUID().uuidString,
            bytes: Data,
            width: Int,
            height: Int,
            bytesPerRow: Int
        ) throws -> FrameDescriptor {
            let descriptor = FrameDescriptor(
                tag: tag,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )
            try validate(descriptor)
            let fileURL = try frameFileURL(for: tag)
            try backend.writeFrame(descriptor: descriptor, bytes: bytes, at: fileURL)
            return descriptor
        }

        public func mapFrame(
            tag: String,
            width: Int,
            height: Int,
            bytesPerRow: Int
        ) throws -> MappedFrame {
            let descriptor = FrameDescriptor(
                tag: tag,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )
            try validate(descriptor)
            let fileURL = try frameFileURL(for: tag)
            return try backend.mapFrame(descriptor: descriptor, at: fileURL)
        }

        public func removeFrame(tag: String) throws {
            let fileURL = try frameFileURL(for: tag)
            try backend.removeFrame(at: fileURL)
        }

        private func validate(_ descriptor: FrameDescriptor) throws {
            guard descriptor.width > 0,
                  descriptor.height > 0,
                  descriptor.bytesPerRow >= descriptor.width * 4 else {
                throw ChannelError.invalidDimensions
            }
        }

        private func frameFileURL(for tag: String) throws -> URL {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent(fileName(for: tag))
        }

        private func fileName(for tag: String) -> String {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            let scalars = tag.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
            let suffix = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            return namePrefix + (suffix.isEmpty ? UUID().uuidString : suffix)
        }

        private static func resolveBackend(
            preferredBackend: BackendPreference
        ) -> (backend: any FrameStorageBackend, usedFallbackBackend: Bool, reason: String?) {
            switch preferredBackend {
            case .mappedFile:
                return (MappedFileFrameStorageBackend(), false, nil)
            case .mach:
                switch machBackendAvailability {
                case .available:
                    return (MachFrameStorageBackend(), false, nil)
                case .unavailable(let reason):
                    return (MappedFileFrameStorageBackend(), true, reason)
                }
            case .automatic:
                switch machBackendAvailability {
                case .available:
                    return (MachFrameStorageBackend(), false, nil)
                case .unavailable(let reason):
                    return (MappedFileFrameStorageBackend(), false, reason)
                }
            }
        }

        public static func backendPreference(
            from environment: [String: String]
        ) -> BackendPreference? {
            guard let rawValue = environment[backendOverrideEnvironmentKey]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
                  !rawValue.isEmpty else {
                return nil
            }

            switch rawValue {
            case "automatic", "auto":
                return .automatic
            case "mappedfile", "mapped-file", "mapped_file":
                return .mappedFile
            case "mach":
                return .mach
            default:
                return BackendPreference(rawValue: rawValue)
            }
        }
    }
}

private protocol FrameStorageBackend: Sendable {
    var kind: LumiPreviewFacade.SharedMemoryFrameChannel.BackendKind { get }

    func writeFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        bytes: Data,
        at fileURL: URL
    ) throws

    func mapFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        at fileURL: URL
    ) throws -> LumiPreviewFacade.SharedMemoryFrameChannel.MappedFrame

    func removeFrame(at fileURL: URL) throws
}

private struct MappedFileFrameStorageBackend: FrameStorageBackend {
    var kind: LumiPreviewFacade.SharedMemoryFrameChannel.BackendKind { .mappedFile }

    func writeFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        bytes: Data,
        at fileURL: URL
    ) throws {
        let fileDescriptor = try openFrameFile(
            path: fileURL.path,
            flags: O_CREAT | O_RDWR
        )
        defer { close(fileDescriptor) }

        guard ftruncate(fileDescriptor, off_t(descriptor.byteCount)) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: fileURL)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.truncateFailed(
                path: fileURL.path,
                code: code
            )
        }

        guard let baseAddress = mmap(
            nil,
            descriptor.byteCount,
            PROT_READ | PROT_WRITE,
            MAP_SHARED,
            fileDescriptor,
            0
        ), baseAddress != MAP_FAILED else {
            let code = errno
            try? FileManager.default.removeItem(at: fileURL)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.mapFailed(
                path: fileURL.path,
                code: code
            )
        }
        defer { munmap(baseAddress, descriptor.byteCount) }

        let copied = bytes.withUnsafeBytes { buffer -> Bool in
            guard let source = buffer.baseAddress,
                  buffer.count == descriptor.byteCount else {
                return false
            }
            memcpy(baseAddress, source, descriptor.byteCount)
            return true
        }
        guard copied else {
            try? FileManager.default.removeItem(at: fileURL)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.writeFailed
        }
    }

    func mapFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        at fileURL: URL
    ) throws -> LumiPreviewFacade.SharedMemoryFrameChannel.MappedFrame {
        let fileDescriptor = try openFrameFile(path: fileURL.path, flags: O_RDONLY)
        guard let baseAddress = mmap(
            nil,
            descriptor.byteCount,
            PROT_READ,
            MAP_SHARED,
            fileDescriptor,
            0
        ), baseAddress != MAP_FAILED else {
            let code = errno
            close(fileDescriptor)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.mapFailed(
                path: fileURL.path,
                code: code
            )
        }

        return LumiPreviewFacade.SharedMemoryFrameChannel.MappedFrame(
            descriptor: descriptor,
            fileDescriptor: fileDescriptor,
            baseAddress: baseAddress
        )
    }

    func removeFrame(at fileURL: URL) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard unlink(fileURL.path) == 0 else {
                throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.removeFailed(
                    path: fileURL.path,
                    code: errno
                )
            }
        }
    }

    private func openFrameFile(path: String, flags: Int32) throws -> Int32 {
        let fileDescriptor = open(path, flags, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.openFailed(
                path: path,
                code: errno
            )
        }
        return fileDescriptor
    }
}

private struct MachFrameStorageBackend: FrameStorageBackend {
    var kind: LumiPreviewFacade.SharedMemoryFrameChannel.BackendKind { .mach }

    func writeFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        bytes: Data,
        at fileURL: URL
    ) throws {
        let sharedMemoryName = sharedMemoryName(for: fileURL)
        let fileDescriptor = try openSharedMemoryObject(
            name: sharedMemoryName,
            flags: O_CREAT | O_RDWR
        )
        defer { close(fileDescriptor) }

        guard ftruncate(fileDescriptor, off_t(descriptor.byteCount)) == 0 else {
            let code = errno
            shm_unlink(sharedMemoryName)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.truncateFailed(
                path: sharedMemoryName,
                code: code
            )
        }

        guard let baseAddress = mmap(
            nil,
            descriptor.byteCount,
            PROT_READ | PROT_WRITE,
            MAP_SHARED,
            fileDescriptor,
            0
        ), baseAddress != MAP_FAILED else {
            let code = errno
            shm_unlink(sharedMemoryName)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.mapFailed(
                path: sharedMemoryName,
                code: code
            )
        }
        defer { munmap(baseAddress, descriptor.byteCount) }

        let copied = bytes.withUnsafeBytes { buffer -> Bool in
            guard let source = buffer.baseAddress,
                  buffer.count == descriptor.byteCount else {
                return false
            }
            memcpy(baseAddress, source, descriptor.byteCount)
            return true
        }
        guard copied else {
            shm_unlink(sharedMemoryName)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.writeFailed
        }
    }

    func mapFrame(
        descriptor: LumiPreviewFacade.SharedMemoryFrameChannel.FrameDescriptor,
        at fileURL: URL
    ) throws -> LumiPreviewFacade.SharedMemoryFrameChannel.MappedFrame {
        let sharedMemoryName = sharedMemoryName(for: fileURL)
        let fileDescriptor = try openSharedMemoryObject(name: sharedMemoryName, flags: O_RDONLY)
        guard let baseAddress = mmap(
            nil,
            descriptor.byteCount,
            PROT_READ,
            MAP_SHARED,
            fileDescriptor,
            0
        ), baseAddress != MAP_FAILED else {
            let code = errno
            close(fileDescriptor)
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.mapFailed(
                path: sharedMemoryName,
                code: code
            )
        }

        return LumiPreviewFacade.SharedMemoryFrameChannel.MappedFrame(
            descriptor: descriptor,
            fileDescriptor: fileDescriptor,
            baseAddress: baseAddress
        )
    }

    func removeFrame(at fileURL: URL) throws {
        let sharedMemoryName = sharedMemoryName(for: fileURL)
        guard shm_unlink(sharedMemoryName) == 0 || errno == ENOENT else {
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.removeFailed(
                path: sharedMemoryName,
                code: errno
            )
        }
    }

    private func sharedMemoryName(for fileURL: URL) -> String {
        let stableHash = fnv1a64Hex(of: fileURL.lastPathComponent)
        return "/lhtp-\(stableHash)"
    }

    private func openSharedMemoryObject(name: String, flags: Int32) throws -> Int32 {
        let fileDescriptor = name.withCString { rawName in
            lumi_shm_open(rawName, flags, S_IRUSR | S_IWUSR)
        }
        guard fileDescriptor >= 0 else {
            throw LumiPreviewFacade.SharedMemoryFrameChannel.ChannelError.openFailed(
                path: name,
                code: errno
            )
        }
        return fileDescriptor
    }

    private func fnv1a64Hex(of string: String) -> String {
        let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        var hash = offsetBasis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(format: "%016llx", hash)
    }
}
