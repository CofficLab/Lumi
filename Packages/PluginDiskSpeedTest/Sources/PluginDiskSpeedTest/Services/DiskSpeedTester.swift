import Foundation
import os

/// 磁盘顺序读写测速服务。
///
/// ## 实现方式
///
/// 直接用 `FileHandle` 写 / 读临时文件来测量吞吐，不依赖 `dd` / `fio`
/// 等外部命令：
/// - 不受用户 PATH 中同名工具被替换的影响；
/// - 不需要提权，也不需要 shell 转义；
/// - 读写路径完全可控，计时边界清晰。
///
/// ## 缓存对结果的影响
///
/// macOS 的写回缓存会让「写完立刻读回」明显偏快——读操作直接从内存里
/// 取到了刚写的页，测出来的是内存速度而不是磁盘速度。
///
/// 因此本实现刻意在读之前调用 `fsync`（`FileHandle.synchronize()`）
/// 把数据强制刷到物理介质，再重新打开文件读取。这样读到的才是磁盘数据。
///
/// 需要注意的是：`fsync` 之后系统的统一缓存（UBC）仍可能保留部分数据，
/// 所以读速度依然是**偏乐观的上界**。这是单文件测速的固有局限，
/// 真实场景中的持续吞吐通常低于此值。
///
/// ## 为什么只测顺序读写
///
/// 顺序读写是磁盘厂商标称数据的口径，也是用户日常「拷贝大文件」最关心的指标。
/// 随机小 IO 的性能受文件系统、缓存、APFS 压缩等多重因素影响，
/// 单次测量噪声大、参考价值低，因此不在此实现。
public actor DiskSpeedTester {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.disk-speed-test",
        category: "DiskSpeedTester"
    )

    /// 测速过程中的错误。
    public enum TestError: LocalizedError {
        case cannotCreateDirectory(String)
        case cannotCreateFile(String)
        case writeFailed(String)
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .cannotCreateDirectory(let reason):
                return "Failed to create temp directory: \(reason)"
            case .cannotCreateFile(let reason):
                return "Failed to create temp file: \(reason)"
            case .writeFailed(let reason):
                return "Failed to write temp file: \(reason)"
            case .readFailed(let reason):
                return "Failed to read temp file: \(reason)"
            }
        }
    }

    /// 单项测速结果。
    public struct Measurement: Sendable, Equatable {
        /// 吞吐（字节/秒）。
        let bytesPerSecond: Double
        /// 传输的字节数。
        let bytes: Int64
        /// 耗时（秒）。
        let duration: TimeInterval
    }

    /// 默认测试数据量（256 MB）。
    ///
    /// 取这个量级是为了让写入耗时明显超过文件缓存的承接能力，
    /// 否则测出来的多半是内存速度而不是磁盘速度。
    public static let defaultTestBytes: Int64 = 256 * 1024 * 1024

    /// 写入块大小（1 MB）。足够大以摊薄系统调用开销。
    private static let chunkSize = 1024 * 1024

    public init() {}

    /// 在指定目录做一次顺序写 + 顺序读测试。
    ///
    /// 写与读使用**同一个文件**：先写入并 `fsync` 落盘，再重新打开读取。
    /// 这样读测试面对的是已在物理介质上的数据，而不是内存里的缓存页。
    ///
    /// - Parameters:
    ///   - directory: 测试文件所在目录。
    ///   - testBytes: 每项测试的数据量。
    /// - Returns: 写与读的测量结果。
    /// - Throws: 文件操作失败。
    func measure(
        in directory: URL,
        testBytes: Int64 = DiskSpeedTester.defaultTestBytes
    ) async throws -> (write: Measurement, read: Measurement) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw TestError.cannotCreateDirectory(error.localizedDescription)
        }

        let fileURL = directory.appendingPathComponent("lumispeed-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let write = try Self.measureWrite(to: fileURL, testBytes: testBytes)
        let read = try Self.measureRead(from: fileURL, testBytes: testBytes)
        return (write, read)
    }

    // MARK: - Write

    /// 顺序写测试：写入固定大小的数据并计时。
    ///
    /// 计时结束后调用 `synchronize()` 把数据刷到物理介质，
    /// 让随后的读测试面对真实磁盘数据。
    private static func measureWrite(to url: URL, testBytes: Int64) throws -> Measurement {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw TestError.cannotCreateFile(url.path)
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: url)
        } catch {
            throw TestError.cannotCreateFile(error.localizedDescription)
        }
        defer { try? handle.close() }

        let buffer = Data(repeating: 0x5A, count: chunkSize)
        var remaining = testBytes
        let startedAt = Date()

        while remaining > 0 {
            let count = Int(min(Int64(chunkSize), remaining))
            let slice = count == chunkSize ? buffer : buffer.prefix(count)
            do {
                try handle.write(contentsOf: slice)
            } catch {
                throw TestError.writeFailed(error.localizedDescription)
            }
            remaining -= Int64(count)
        }

        let duration = Date().timeIntervalSince(startedAt)

        // 强制刷盘：让读测试测到的是磁盘而不是缓存。
        // 刷盘失败不改变写测试结果（写已经完成了），因此只记录不抛错。
        do {
            try handle.synchronize()
        } catch {
            Self.logger.warning("fsync after write failed: \(error.localizedDescription, privacy: .public)")
        }

        return Measurement(
            bytesPerSecond: duration > 0 ? Double(testBytes) / duration : 0,
            bytes: testBytes,
            duration: duration
        )
    }

    // MARK: - Read

    /// 顺序读测试：重新打开文件并读取固定大小的数据，计时。
    ///
    /// 读之前数据已经由写测试 `fsync` 到物理介质，
    /// 因此这里测到的是磁盘读取速度。
    private static func measureRead(from url: URL, testBytes: Int64) throws -> Measurement {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw TestError.readFailed(error.localizedDescription)
        }
        defer { try? handle.close() }

        var remaining = testBytes
        let startedAt = Date()
        while remaining > 0 {
            let count = Int(min(Int64(chunkSize), remaining))
            do {
                let data = try handle.read(upToCount: count) ?? Data()
                guard !data.isEmpty else { break }
                remaining -= Int64(data.count)
            } catch {
                throw TestError.readFailed(error.localizedDescription)
            }
        }

        let duration = Date().timeIntervalSince(startedAt)
        return Measurement(
            bytesPerSecond: duration > 0 ? Double(testBytes) / duration : 0,
            bytes: testBytes,
            duration: duration
        )
    }
}
