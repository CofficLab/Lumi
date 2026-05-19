import CryptoKit
import Foundation
import LumiPreviewKit

public extension LumiPreviewFacade {

    /// 把 Swift 源文件中的 `#Preview` 自动编译成可被
    /// `InlinePreviewSession.loadDylib(path:)` 加载的 dylib。
    ///
    /// 流水线：
    /// 1. 用 `LumiPreviewKit.PreviewScanner` 扫源；按 requested index 选择 `PreviewDiscovery`。
    /// 2. 计算源码、文件路径、preview id 的 SHA256 指纹；命中缓存时直接返回上次产物。
    /// 3. 优先用 `LumiPreviewKit.BuildPlanner` 规划 SPM/Xcode 构建上下文。
    /// 4. 有构建上下文时复用 `PreviewEntryBuilder` 生成可导入目标模块的 entry dylib。
    /// 5. 无构建上下文时回退 standalone swiftc，编译"用户源 + entry + 同包 Swift 文件"。
    /// 6. 缓存 (fingerprint → dylib URL) 并返回。
    ///
    /// **范围**：支持 standalone Swift 文件和基础 SPM/Xcode target 上下文；复杂 workspace
    /// 的外部 package link inputs 仍需要真实项目压测继续收敛。
    actor PreviewBuilder {

        // MARK: - 错误

        public enum BuildError: Error, LocalizedError {
            case noPreviewFound
            case sdkResolutionFailed(String)
            case swiftcFailed(stderr: String)
            case plannedBuildFailed(String)

            public var errorDescription: String? {
                switch self {
                case .noPreviewFound:
                    return "No #Preview block found in this file."
                case let .sdkResolutionFailed(message):
                    return "Failed to resolve macOS SDK path: \(message)"
                case let .swiftcFailed(stderr):
                    return "swiftc failed:\n\(stderr)"
                case let .plannedBuildFailed(message):
                    return "Planned preview build failed:\n\(message)"
                }
            }
        }

        // MARK: - 结果

        public struct BuildResult: Sendable, Equatable {
            public let dylibURL: URL
            public let fingerprint: String
            public let usedCache: Bool
            public let primaryTitle: String
            public let selectedPreviewIndex: Int
            public let previewCount: Int
        }

        public struct PreviewSummary: Sendable, Equatable, Identifiable {
            public let id: String
            public let index: Int
            public let title: String
            public let lineNumber: Int
            public let primaryTypeName: String?
        }

        // MARK: - 私有

        private let scanner = LumiPreviewFacade.PreviewScanner()
        private let buildPlanner = LumiPreviewFacade.BuildPlanner()
        private let spmCompiler = LumiPreviewFacade.SPMCompiler()
        private let previewEntryBuilder: LumiPreviewFacade.PreviewEntryBuilder
        private let xcodeCompiler: LumiPreviewFacade.XcodeCompiler
        private let incrementalBuildPipeline: LumiPreviewFacade.IncrementalBuildPipeline
        private let moduleImportEligibilityChecker = LumiPreviewFacade.ModuleImportEligibilityChecker()
        private let workspaceRoot: URL
        private let cacheLimit: Int
        /// fingerprint → dylib URL（最近若干次保存的产物）。
        private var cache: [String: URL] = [:]
        /// LRU 顺序：最旧 → 最新。
        private var cacheOrder: [String] = []

        // MARK: - 初始化

        /// - Parameters:
        ///   - workspaceRoot: dylib 输出目录；默认 `$TMPDIR/LumiPreviewKit-Builds-<pid>/`。
        ///   - cacheLimit: 同时保留的产物数；超过则删除最旧 dylib 文件。
        public init(
            workspaceRoot: URL? = nil,
            cacheLimit: Int = 8,
            xcodeCompiler: LumiPreviewFacade.XcodeCompiler = .init(),
            previewEntryBuilder: LumiPreviewFacade.PreviewEntryBuilder? = nil,
            incrementalBuildPipeline: LumiPreviewFacade.IncrementalBuildPipeline? = nil
        ) {
            self.cacheLimit = max(1, cacheLimit)
            self.xcodeCompiler = xcodeCompiler
            self.previewEntryBuilder = previewEntryBuilder
                ?? LumiPreviewFacade.PreviewEntryBuilder(xcodeCompiler: xcodeCompiler)
            self.incrementalBuildPipeline = incrementalBuildPipeline
                ?? LumiPreviewFacade.IncrementalBuildPipeline(xcodeCompiler: xcodeCompiler)
            if let workspaceRoot {
                self.workspaceRoot = workspaceRoot
            } else {
                let pid = ProcessInfo.processInfo.processIdentifier
                self.workspaceRoot = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("LumiPreviewKit-Builds-\(pid)", isDirectory: true)
            }
        }

        // MARK: - 公开方法

        /// 把 `fileURL` + `sourceText` 编译为预览 dylib。
        ///
        /// - 同样的 `sourceText` 命中缓存直接返回上次产物（`usedCache == true`）。
        /// - 仅扫源不重写磁盘：传入的是 buffer 内容，避免读到未保存的旧文件。
        public func build(
            fileURL: URL,
            sourceText: String,
            previewIndex requestedPreviewIndex: Int = 0
        ) async throws -> BuildResult {
            let discoveries = scanner.scan(fileURL: fileURL, sourceText: sourceText)
            guard !discoveries.isEmpty else {
                throw BuildError.noPreviewFound
            }
            let previewIndex = discoveries.indices.contains(requestedPreviewIndex) ? requestedPreviewIndex : 0
            let discovery = discoveries[previewIndex]

            let fingerprint = Self.fingerprint(
                of: sourceText,
                fileURL: fileURL,
                previewID: discovery.id
            )
            if let cached = cache[fingerprint], FileManager.default.fileExists(atPath: cached.path) {
                touch(fingerprint: fingerprint)
                return BuildResult(
                    dylibURL: cached,
                    fingerprint: fingerprint,
                    usedCache: true,
                    primaryTitle: discovery.title,
                    selectedPreviewIndex: previewIndex,
                    previewCount: discoveries.count
                )
            }

            try ensureWorkspace()
            let dylibURL: URL
            if let buildStrategy = buildPlanner.plan(for: fileURL) {
                dylibURL = try await buildPlannedEntry(
                    discovery: discovery,
                    buildStrategy: buildStrategy,
                    fingerprint: fingerprint
                )
            } else {
                dylibURL = try await buildStandaloneEntry(
                    discovery: discovery,
                    fileURL: fileURL,
                    sourceText: sourceText,
                    fingerprint: fingerprint
                )
            }

            insert(fingerprint: fingerprint, dylibURL: dylibURL)

            return BuildResult(
                dylibURL: dylibURL,
                fingerprint: fingerprint,
                usedCache: false,
                primaryTitle: discovery.title,
                selectedPreviewIndex: previewIndex,
                previewCount: discoveries.count
            )
        }

        /// 使用分级回退机制构建 planned entry dylib。
        ///
        /// 策略选择：
        /// - **SPM target**：尝试 module import → 回退到 legacy builder（收集完整 target 源码）。
        /// - **Xcode target**：直接使用 legacy builder（Xcode app target 不导出 internal 符号，
        ///   module import 不可靠；`compilePreviewEntryIncludingCurrentSource` 只编译单文件，
        ///   无法解决跨文件依赖）。
        /// - **incremental**：直接使用 legacy builder。
        ///
        /// 对 SPM target，module import 失败时自动回退到 legacy builder。
        /// 仅在 legacy builder 也失败时才抛出错误。
        private func buildPlannedEntry(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            buildStrategy: LumiPreviewFacade.BuildStrategy,
            fingerprint: String
        ) async throws -> URL {
            try await buildTargetIfNeeded(buildStrategy)

            // 对 SPM target：先尝试 module import（最快，对 public 符号有效）
            if case .spm = buildStrategy,
               shouldAttemptModuleImport(discovery: discovery, buildStrategy: buildStrategy),
               let importPlan = try? await incrementalBuildPipeline.resolveModuleImportPlan(
                   buildStrategy: buildStrategy
               ),
               importPlan.hasUsableModuleArtifact {
                do {
                    let entryURL = try await incrementalBuildPipeline.compilePreviewEntryImportingModule(
                        discovery: discovery,
                        configuration: .empty,
                        buildStrategy: buildStrategy,
                        importPlan: importPlan
                    )
                    return try copyToWorkspace(entryURL, fingerprint: fingerprint)
                } catch {
                    // module import 失败，回退到 legacy builder
                }
            }

            // 最终兜底：legacy PreviewEntryBuilder（收集完整 target 源码，最稳健）
            // 会通过 BuildPlanner.swiftSourceFiles() 收集 Xcode target 的所有源文件，
            // 并在 entry 中直接内联编译而非 import 模块——从而解决 internal 符号可见性问题。
            let forcedSourceIncludeStrategy = buildStrategy
            do {
                let builtURL = try await previewEntryBuilder.buildEntry(
                    for: discovery,
                    configuration: .empty,
                    buildStrategy: forcedSourceIncludeStrategy,
                    forceSourceInclude: true
                )
                return try copyToWorkspace(builtURL, fingerprint: fingerprint)
            } catch {
                throw BuildError.plannedBuildFailed(error.localizedDescription)
            }
        }

        /// 判断是否应该尝试 module import 路径。
        ///
        /// 仅当预览 body 没有引用 private/fileprivate 符号时才返回 true。
        /// 对于 incremental 策略不支持 module import。
        private func shouldAttemptModuleImport(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            buildStrategy: LumiPreviewFacade.BuildStrategy
        ) -> Bool {
            switch buildStrategy {
            case .spm, .xcode:
                return moduleImportEligibilityChecker.shouldUseModuleImport(
                    discovery: discovery
                )
            case .incremental:
                return false
            }
        }

        /// 将编译产物复制到 workspace 目录中。
        private func copyToWorkspace(_ sourceURL: URL, fingerprint: String) throws -> URL {
            let buildDir = workspaceRoot.appendingPathComponent(fingerprint, isDirectory: true)
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
            let dylibURL = buildDir.appendingPathComponent("PreviewEntry.dylib")
            if FileManager.default.fileExists(atPath: dylibURL.path) {
                try FileManager.default.removeItem(at: dylibURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dylibURL)
            return dylibURL
        }

        private func buildTargetIfNeeded(_ buildStrategy: LumiPreviewFacade.BuildStrategy) async throws {
            switch buildStrategy {
            case .spm(let packageDirectory, let targetName):
                _ = try await spmCompiler.build(packageDirectory: packageDirectory, targetName: targetName)
            case .xcode(let projectURL, let scheme, let configuration):
                _ = try await xcodeCompiler.build(
                    projectURL: projectURL,
                    scheme: scheme,
                    configuration: configuration
                )
            case .incremental:
                break
            }
        }

        private func buildStandaloneEntry(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            fileURL: URL,
            sourceText: String,
            fingerprint: String
        ) async throws -> URL {
            let buildDir = workspaceRoot.appendingPathComponent(fingerprint, isDirectory: true)
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

            let userSourceURL = buildDir.appendingPathComponent("UserSource.swift")
            let entrySourceURL = buildDir.appendingPathComponent("PreviewEntry.swift")
            let dylibURL = buildDir.appendingPathComponent("PreviewEntry.dylib")

            try sourceText.write(to: userSourceURL, atomically: true, encoding: .utf8)
            let entrySource = LumiPreviewFacade.PreviewEntryGenerator.generate(for: discovery)
            try entrySource.write(to: entrySourceURL, atomically: true, encoding: .utf8)

            // 收集编译输入：用户源文件 + entry + 同包内的其他 Swift 文件。
            // 同包文件可能包含被源文件引用的类型（如 DesignTokens），
            // 将它们一起传入 swiftc 以解决跨文件依赖。
            var swiftcInputs = [userSourceURL, entrySourceURL]
            let packageSwiftFiles = Self.collectPeerSwiftFiles(for: fileURL)
            swiftcInputs.append(contentsOf: packageSwiftFiles)

            try await runSwiftc(
                inputs: swiftcInputs,
                output: dylibURL
            )
            return dylibURL
        }

        public func discoverPreviews(fileURL: URL, sourceText: String) -> [PreviewSummary] {
            scanner.scan(fileURL: fileURL, sourceText: sourceText).enumerated().map { index, discovery in
                PreviewSummary(
                    id: discovery.id,
                    index: index,
                    title: discovery.title,
                    lineNumber: discovery.lineNumber,
                    primaryTypeName: discovery.primaryTypeName
                )
            }
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
                "-Onone",
                "-module-name", "LumiPreviewEntry",
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

        private static func fingerprint(of sourceText: String, fileURL: URL, previewID: String) -> String {
            var hasher = SHA256()
            hasher.update(data: Data(fileURL.path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data(previewID.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data(sourceText.utf8))
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
        }

        // MARK: - 私有 — 同包文件收集

        /// 查找与 `fileURL` 同属于一个 SPM 包 / 模块目录的其他 Swift 文件。
        ///
        /// 查找策略：
        /// 1. 从 `fileURL` 向上遍历，找到包含 `Package.swift` 的目录（即 SPM 包根目录）。
        /// 2. 从 `fileURL` 向上遍历，找到 `Sources/` 或 `Sources/<target>/` 目录。
        /// 3. 收集该 `Sources/` 目录下（递归）所有 `.swift` 文件，**排除** `fileURL` 自身
        ///    （因为它已经作为 `UserSource.swift` 写入 build dir 了）。
        ///
        /// 这样做的好处：用户在文件中引用的同包类型（如 `DesignTokens`）能被 swiftc 解析到，
        /// 而不需要完整的 SPM 编译管线。
        ///
        /// 如果找不到 SPM 包结构（如文件不在任何包中），返回空数组——回退到仅编译单文件。
        private static func collectPeerSwiftFiles(for fileURL: URL) -> [URL] {
            let fm = FileManager.default
            let currentDir = fileURL.deletingLastPathComponent()

            // 1. 向上查找 Package.swift → 确定包根目录
            var packageRoot: URL?
            var searchDir = currentDir
            for _ in 0..<8 {
                let packageSwift = searchDir.appendingPathComponent("Package.swift")
                if fm.fileExists(atPath: packageSwift.path) {
                    packageRoot = searchDir
                    break
                }
                let parent = searchDir.deletingLastPathComponent()
                if parent.path == searchDir.path { break } // 到达根目录
                searchDir = parent
            }

            guard let packageRoot else { return [] }

            // 2. 从 fileURL 向上查找 Sources 目录
            var sourcesDir: URL?
            searchDir = currentDir
            for _ in 0..<6 {
                if searchDir.lastPathComponent == "Sources" {
                    sourcesDir = searchDir
                    break
                }
                let parent = searchDir.deletingLastPathComponent()
                if parent.path == searchDir.path { break }
                searchDir = parent
            }

            // 如果没直接找到 Sources 目录，尝试在包根目录下找
            if sourcesDir == nil {
                let candidate = packageRoot.appendingPathComponent("Sources")
                if fm.fileExists(atPath: candidate.path) {
                    sourcesDir = candidate
                }
            }

            guard let sourcesDir else { return [] }

            // 3. 收集 Sources/ 下所有 .swift 文件（排除 fileURL 自身）
            guard let deepEnumerator = fm.enumerator(
                at: sourcesDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            var result: [URL] = []
            for case let url as URL in deepEnumerator {
                guard url.pathExtension == "swift" else { continue }
                // 排除源文件自身（因为 buffer 内容可能已修改，用 UserSource.swift 替代）
                if url.path == fileURL.path { continue }
                result.append(url)
            }

            return result
        }
    }
}
