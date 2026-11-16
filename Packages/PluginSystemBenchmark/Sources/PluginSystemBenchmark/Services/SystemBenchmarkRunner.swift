import Darwin
import Foundation

/// Runs explicit, local-only hardware benchmarks. It never starts by itself.
public actor SystemBenchmarkRunner {
    public struct Configuration: Sendable {
        public let cpuIterations: Int
        public let memoryBufferBytes: Int
        public let memoryPasses: Int
        public let diskBytes: Int
        public let diskChunkBytes: Int

        public init(
            cpuIterations: Int = 12_000_000,
            memoryBufferBytes: Int = 64 * 1024 * 1024,
            memoryPasses: Int = 2,
            diskBytes: Int = 64 * 1024 * 1024,
            diskChunkBytes: Int = 1024 * 1024
        ) {
            self.cpuIterations = cpuIterations
            self.memoryBufferBytes = memoryBufferBytes
            self.memoryPasses = memoryPasses
            self.diskBytes = diskBytes
            self.diskChunkBytes = diskChunkBytes
        }

        fileprivate func validate() throws {
            guard cpuIterations > 0 else { throw BenchmarkError.invalidConfiguration("CPU iterations must be positive") }
            guard memoryBufferBytes >= 4096, memoryPasses > 0 else {
                throw BenchmarkError.invalidConfiguration("Memory benchmark configuration is too small")
            }
            guard diskBytes >= 4096, diskChunkBytes > 0 else {
                throw BenchmarkError.invalidConfiguration("Disk benchmark configuration is invalid")
            }
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func run(
        progress: @escaping @Sendable (BenchmarkProgress) async -> Void = { _ in }
    ) async throws -> BenchmarkReport {
        try configuration.validate()
        await progress(.preparing)

        var measurements: [BenchmarkMeasurement] = []

        try Task.checkCancellation()
        await progress(.cpu)
        measurements.append(contentsOf: try await Self.runCPU(configuration: configuration))

        try Task.checkCancellation()
        await progress(.memory)
        measurements.append(contentsOf: try Self.runMemory(configuration: configuration))

        try Task.checkCancellation()
        await progress(.disk)
        measurements.append(contentsOf: try Self.runDisk(configuration: configuration))

        await progress(.finished)
        return BenchmarkReport(measurements: measurements)
    }

    private nonisolated static func runCPU(configuration: Configuration) async throws -> [BenchmarkMeasurement] {
        let singleStart = DispatchTime.now().uptimeNanoseconds
        let singleChecksum = try cpuWork(iterations: configuration.cpuIterations, seed: 0xA5A5_A5A5)
        let singleMilliseconds = elapsedMilliseconds(since: singleStart)

        try Task.checkCancellation()
        let workerCount = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 8))
        let iterationsPerWorker = max(1, configuration.cpuIterations / workerCount)
        let multiStart = DispatchTime.now().uptimeNanoseconds
        // 用可抛出的任务组：任一 worker 因取消抛出时，组会取消其余 worker 并尽快返回，
        // 而不是等非抛出的组把整段多核负载跑完（#257）。
        let multiChecksum = try await withThrowingTaskGroup(of: UInt64.self, returning: UInt64.self) { group in
            for worker in 0..<workerCount {
                group.addTask {
                    try cpuWork(iterations: iterationsPerWorker, seed: UInt64(worker + 1))
                }
            }

            var checksum: UInt64 = 0
            for try await value in group {
                checksum ^= value
            }
            return checksum
        }
        let multiMilliseconds = elapsedMilliseconds(since: multiStart)

        // Keep the checksums live so an optimizer cannot remove the benchmark loop.
        withExtendedLifetime((singleChecksum, multiChecksum)) {}

        let singleSeconds = max(singleMilliseconds / 1_000, 0.000_001)
        let multiSeconds = max(multiMilliseconds / 1_000, 0.000_001)
        return [
            BenchmarkMeasurement(
                kind: .cpu,
                label: "single-core",
                value: Double(configuration.cpuIterations) / singleSeconds,
                unit: "ops/s",
                durationMilliseconds: singleMilliseconds,
                detail: "Fixed integer workload"
            ),
            BenchmarkMeasurement(
                kind: .cpu,
                label: "multi-core",
                value: Double(iterationsPerWorker * workerCount) / multiSeconds,
                unit: "ops/s",
                durationMilliseconds: multiMilliseconds,
                detail: "\(workerCount) concurrent workers"
            ),
        ]
    }

    @inline(never)
    private nonisolated static func cpuWork(iterations: Int, seed: UInt64) throws -> UInt64 {
        var value = seed
        // 每 65536 次迭代检查一次取消：被取消时尽快退出，而不是把整段 CPU 负载跑完，
        // 让 Cancel / shutdown 不必等待剩余迭代（#257）。分块以保持内层循环紧凑。
        let blockSize = 65_536
        var index = 0
        while index < iterations {
            try Task.checkCancellation()
            let blockEnd = min(index + blockSize, iterations)
            while index < blockEnd {
                value = value &* 1_664_525 &+ 1_013_904_223 &+ UInt64(index)
                value ^= value >> 13
                value = value &* 2_862_933_555_777_941_757
                value ^= value << 17
                index += 1
            }
        }
        return value
    }

    private nonisolated static func runMemory(configuration: Configuration) throws -> [BenchmarkMeasurement] {
        let size = configuration.memoryBufferBytes
        let passes = configuration.memoryPasses
        let source = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 64)
        let destination = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 64)
        defer {
            source.deallocate()
            destination.deallocate()
        }

        source.initializeMemory(as: UInt8.self, repeating: 0xA5, count: size)
        destination.initializeMemory(as: UInt8.self, repeating: 0, count: size)

        let writeStart = DispatchTime.now().uptimeNanoseconds
        for pass in 0..<passes {
            try Task.checkCancellation()
            memset(destination, Int32((pass + 1) & 0xFF), size)
        }
        let writeMilliseconds = elapsedMilliseconds(since: writeStart)

        let copyStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<passes {
            try Task.checkCancellation()
            destination.copyMemory(from: source, byteCount: size)
        }
        let copyMilliseconds = elapsedMilliseconds(since: copyStart)

        let readStart = DispatchTime.now().uptimeNanoseconds
        var checksum: UInt64 = 0
        // read 按 64 字节跨步、每次只 load 8 字节；吞吐须按实际采样量而非整缓冲区计。
        var sampledBytes = 0
        for _ in 0..<passes {
            try Task.checkCancellation()
            let lastReadableOffset = size - MemoryLayout<UInt64>.size + 1
            for offset in stride(from: 0, to: lastReadableOffset, by: 64) {
                checksum &+= source.load(fromByteOffset: offset, as: UInt64.self)
                sampledBytes += MemoryLayout<UInt64>.size
            }
        }
        let readMilliseconds = elapsedMilliseconds(since: readStart)
        withExtendedLifetime(checksum) {}

        return [
            memoryMeasurement(label: "write", bytes: size * passes, milliseconds: writeMilliseconds, detail: "\(size / (1024 * 1024)) MiB buffer"),
            memoryMeasurement(label: "copy", bytes: size * passes, milliseconds: copyMilliseconds, detail: "\(size / (1024 * 1024)) MiB buffer"),
            memoryMeasurement(label: "read", bytes: sampledBytes, milliseconds: readMilliseconds, detail: "\(size / (1024 * 1024)) MiB buffer"),
        ]
    }

    private nonisolated static func memoryMeasurement(
        label: String,
        bytes: Int,
        milliseconds: Double,
        detail: String
    ) -> BenchmarkMeasurement {
        let seconds = max(milliseconds / 1_000, 0.000_001)
        let mebibytesPerSecond = Double(bytes) / (1024 * 1024) / seconds
        return BenchmarkMeasurement(
            kind: .memory,
            label: label,
            value: mebibytesPerSecond,
            unit: "MiB/s",
            durationMilliseconds: milliseconds,
            detail: detail
        )
    }

    private nonisolated static func runDisk(configuration: Configuration) throws -> [BenchmarkMeasurement] {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-system-benchmark-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let chunkSize = min(configuration.diskChunkBytes, configuration.diskBytes)
        var buffer = Data(count: chunkSize)
        buffer.withUnsafeMutableBytes { rawBuffer in
            for index in 0..<rawBuffer.count {
                rawBuffer[index] = UInt8(truncatingIfNeeded: index &* 31 &+ 0xA5)
            }
        }

        let writeStart = DispatchTime.now().uptimeNanoseconds
        try withOpenFile(fileURL.path, flags: O_CREAT | O_TRUNC | O_WRONLY) { descriptor in
            _ = fcntl(descriptor, F_NOCACHE, 1)
            try buffer.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { throw BenchmarkError.io("Disk buffer allocation failed") }
                try writeBytes(
                    descriptor: descriptor,
                    baseAddress: baseAddress,
                    totalBytes: configuration.diskBytes,
                    chunkBytes: chunkSize
                )
            }
            guard fsync(descriptor) == 0 else { throw ioError("fsync failed") }
        }
        let writeMilliseconds = elapsedMilliseconds(since: writeStart)

        let readStart = DispatchTime.now().uptimeNanoseconds
        var checksum: UInt64 = 0
        try withOpenFile(fileURL.path, flags: O_RDONLY) { descriptor in
            _ = fcntl(descriptor, F_NOCACHE, 1)
            try buffer.withUnsafeMutableBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { throw BenchmarkError.io("Disk buffer allocation failed") }
                var remaining = configuration.diskBytes
                while remaining > 0 {
                    try Task.checkCancellation()
                    let requested = min(remaining, chunkSize)
                    let count = read(descriptor, baseAddress, requested)
                    guard count > 0 else { throw ioError("Disk read failed") }
                    for index in stride(from: 0, to: count, by: 64) {
                        checksum &+= UInt64(baseAddress.load(fromByteOffset: index, as: UInt8.self))
                    }
                    remaining -= count
                }
            }
        }
        let readMilliseconds = elapsedMilliseconds(since: readStart)
        withExtendedLifetime(checksum) {}

        return [
            diskMeasurement(label: "write", bytes: configuration.diskBytes, milliseconds: writeMilliseconds, detail: "Temporary file, F_NOCACHE + fsync"),
            diskMeasurement(label: "read", bytes: configuration.diskBytes, milliseconds: readMilliseconds, detail: "Temporary file, F_NOCACHE"),
        ]
    }

    private nonisolated static func diskMeasurement(
        label: String,
        bytes: Int,
        milliseconds: Double,
        detail: String
    ) -> BenchmarkMeasurement {
        let seconds = max(milliseconds / 1_000, 0.000_001)
        return BenchmarkMeasurement(
            kind: .disk,
            label: label,
            value: Double(bytes) / (1024 * 1024) / seconds,
            unit: "MiB/s",
            durationMilliseconds: milliseconds,
            detail: detail
        )
    }

    private nonisolated static func withOpenFile<T>(
        _ path: String,
        flags: Int32,
        operation: (Int32) throws -> T
    ) throws -> T {
        let descriptor = path.withCString { open($0, flags, S_IRUSR | S_IWUSR) }
        guard descriptor >= 0 else { throw ioError("Unable to open benchmark file") }
        defer { close(descriptor) }
        return try operation(descriptor)
    }

    private nonisolated static func writeBytes(
        descriptor: Int32,
        baseAddress: UnsafeRawPointer,
        totalBytes: Int,
        chunkBytes: Int
    ) throws {
        var remaining = totalBytes
        while remaining > 0 {
            try Task.checkCancellation()
            let requested = min(remaining, chunkBytes)
            let count = write(descriptor, baseAddress, requested)
            guard count > 0 else { throw ioError("Disk write failed") }
            remaining -= count
        }
    }

    private nonisolated static func elapsedMilliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    private nonisolated static func ioError(_ message: String) -> BenchmarkError {
        let reason = String(cString: strerror(errno))
        return .io("\(message): \(reason)")
    }
}
