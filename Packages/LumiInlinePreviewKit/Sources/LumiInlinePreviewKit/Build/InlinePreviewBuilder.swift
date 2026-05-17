import CryptoKit
import Foundation
import LumiPreviewKit

public extension LumiInlinePreviewFacade {

    /// 把 Swift 源文件中的第一个 `#Preview` 自动编译成可被
    /// `InlinePreviewSession.loadDylib(path:)` 加载的 dylib。
    ///
    /// 流水线：
    /// 1. 用 `LumiPreviewKit.PreviewScanner` 扫源；选第一条 `PreviewDiscovery`。
    /// 2. 计算源码 SHA256 指纹；命中缓存时直接返回上次产物。
    /// 3. `InlinePreviewEntryGenerator` 生成 entry .swift。
    /// 4. 把"用户源 + entry"两个文件一起喂给 `xcrun swiftc -emit-library`。
    /// 5. 缓存 (fingerprint → dylib URL) 并返回。
    ///
    /// **范围**：当前阶段仅支持文件本地的 `#Preview`（不导入工程模块、不解析 SPM 依赖）。
    /// 这覆盖大多数 SwiftUI 文档式片段；更复杂的预览仍可走 `Load Dylib…` 手动路径。
    public actor InlinePreviewBuilder {

        // MARK: - 错误

        public enum BuildError: Error, LocalizedError {
            case noPreviewFound
            case sdkResolutionFailed(String)
            case swiftcFailed(stderr: String)

            public var errorDescription: String? {
                switch self {
                case .noPreviewFound:
                    return "No #Preview block found in this file."
                case let .sdkResolutionFailed(message):
                    return "Failed to resolve macOS SDK path: \(message)"
                case let .swiftcFailed(stderr):
                    return "swiftc failed:\n\(stderr)"
                }
            }
        }

        // MARK: - 结果

        public struct BuildResult: Sendable, Equatable {
            public let dylibURL: URL
            public let fingerprint: String
            public let usedCache: Bool
            public let primaryTitle: String
        }

        // MARK: - 私有

        private let scanner = LumiPreviewFacade.PreviewScanner()
        private let workspaceRoot: URL
        private let cacheLimit: Int
        /// fingerprint → dylib URL（最近若干次保存的产物）。
        private var cache: [String: URL] = [:]
        /// LRU 顺序：最旧 → 最新。
        private var cacheOrder: [String] = []

        // MARK: - 初始化

        /// - Parameters:
        ///   - workspaceRoot: dylib 输出目录；默认 `$TMPDIR/LumiInlinePreviewKit-Builds-<pid>/`。
        ///   - cacheLimit: 同时保留的产物数；超过则删除最旧 dylib 文件。
        public init(workspaceRoot: URL? = nil, cacheLimit: Int = 8) {
            self.cacheLimit = max(1, cacheLimit)
            if let workspaceRoot {
                self.workspaceRoot = workspaceRoot
            } else {
                let pid = ProcessInfo.processInfo.processIdentifier
                self.workspaceRoot = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("LumiInlinePreviewKit-Builds-\(pid)", isDirectory: true)
            }
        }

        // MARK: - 公开方法

        /// 把 `fileURL` + `sourceText` 编译为预览 dylib。
        ///
        /// - 同样的 `sourceText` 命中缓存直接返回上次产物（`usedCache == true`）。
        /// - 仅扫源不重写磁盘：传入的是 buffer 内容，避免读到未保存的旧文件。
        public func build(fileURL: URL, sourceText: String) async throws -> BuildResult {
            let discoveries = scanner.scan(fileURL: fileURL, sourceText: sourceText)
            guard let discovery = discoveries.first else {
                throw BuildError.noPreviewFound
            }

            let fingerprint = Self.fingerprint(of: sourceText, fileURL: fileURL)
            if let cached = cache[fingerprint], FileManager.default.fileExists(atPath: cached.path) {
                touch(fingerprint: fingerprint)
                return BuildResult(
                    dylibURL: cached,
                    fingerprint: fingerprint,
                    usedCache: true,
                    primaryTitle: discovery.title
                )
            }

            try ensureWorkspace()
            let buildDir = workspaceRoot.appendingPathComponent(fingerprint, isDirectory: true)
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

            let userSourceURL = buildDir.appendingPathComponent("UserSource.swift")
            let entrySourceURL = buildDir.appendingPathComponent("InlinePreviewEntry.swift")
            let dylibURL = buildDir.appendingPathComponent("InlinePreviewEntry.dylib")

            try sourceText.write(to: userSourceURL, atomically: true, encoding: .utf8)
            let entrySource = LumiInlinePreviewFacade.InlinePreviewEntryGenerator.generate(for: discovery)
            try entrySource.write(to: entrySourceURL, atomically: true, encoding: .utf8)

            try await runSwiftc(
                inputs: [userSourceURL, entrySourceURL],
                output: dylibURL
            )

            insert(fingerprint: fingerprint, dylibURL: dylibURL)

            return BuildResult(
                dylibURL: dylibURL,
                fingerprint: fingerprint,
                usedCache: false,
                primaryTitle: discovery.title
            )
        }

        /// 清空缓存与磁盘产物；下次 `build` 必定走完整 swiftc。
        public func purge() {
            cache.removeAll()
            cacheOrder.removeAll()
            try? FileManager.default.removeItem(at: workspaceRoot)
        }

        // MARK: - 私有 — 缓存

        private func touch(fingerprint: String) {
            cacheOrder.removeAll { $0 == fingerprint }
            cacheOrder.append(fingerprint)
        }

        private func insert(fingerprint: String, dylibURL: URL) {
            cache[fingerprint] = dylibURL
            cacheOrder.removeAll { $0 == fingerprint }
            cacheOrder.append(fingerprint)
            while cacheOrder.count > cacheLimit {
                let evicted = cacheOrder.removeFirst()
                if let url = cache.removeValue(forKey: evicted) {
                    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
                }
            }
        }

        // MARK: - 私有 — 工作目录

        private func ensureWorkspace() throws {
            try FileManager.default.createDirectory(
                at: workspaceRoot,
                withIntermediateDirectories: true
            )
        }

        // MARK: - 私有 — swiftc

        private func runSwiftc(inputs: [URL], output: URL) async throws {
            let sdkPath = try await resolveMacOSSDKPath()

            let arch: String
            #if arch(arm64)
            arch = "arm64"
            #else
            arch = "x86_64"
            #endif

            let process = Process()
            process.launchPath = "/usr/bin/xcrun"
            process.arguments = [
                "swiftc",
                "-emit-library",
                "-O",
                "-module-name", "LumiInlinePreviewEntry",
                "-sdk", sdkPath,
                "-target", "\(arch)-apple-macosx14.0",
                "-o", output.path
            ] + inputs.map(\.path)

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()

            try process.run()
            await waitForExit(process)

            guard process.terminationStatus == 0 else {
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                throw BuildError.swiftcFailed(stderr: stderr)
            }
        }

        private func resolveMacOSSDKPath() async throws -> String {
            let process = Process()
            process.launchPath = "/usr/bin/xcrun"
            process.arguments = ["--show-sdk-path", "--sdk", "macosx"]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                throw BuildError.sdkResolutionFailed(error.localizedDescription)
            }
            await waitForExit(process)

            guard process.terminationStatus == 0 else {
                throw BuildError.sdkResolutionFailed("xcrun exited with status \(process.terminationStatus)")
            }

            let path = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !path.isEmpty else {
                throw BuildError.sdkResolutionFailed("xcrun returned empty path")
            }
            return path
        }

        /// 把同步阻塞的 `Process.waitUntilExit` 桥到 actor 友好的 await。
        private nonisolated func waitForExit(_ process: Process) async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
                if !process.isRunning {
                    process.terminationHandler = nil
                    continuation.resume()
                }
            }
        }

        // MARK: - 私有 — 指纹

        private static func fingerprint(of sourceText: String, fileURL: URL) -> String {
            var hasher = SHA256()
            hasher.update(data: Data(fileURL.path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data(sourceText.utf8))
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
        }
    }
}
