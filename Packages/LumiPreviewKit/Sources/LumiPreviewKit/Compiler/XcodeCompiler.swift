import Foundation

public extension LumiPreviewFacade {
/// Xcode 编译器：使用 xcodebuild 编译 Xcode 项目中的预览。
final class XcodeCompiler: Sendable {
    public let derivedDataPath: URL?

    /// 创建 Xcode 编译器。
    public convenience init() {
        self.init(derivedDataPath: nil)
    }

    public init(derivedDataPath: URL?) {
        self.derivedDataPath = derivedDataPath
    }

    /// 编译指定 scheme，返回编译产物路径。
    ///
    /// - Parameters:
    ///   - projectURL: `.xcodeproj` 或 `.xcworkspace` 路径。
    ///   - scheme: 要编译的 scheme。
    ///   - configuration: 编译配置，默认 `Debug`。
    /// - Returns: Xcode 构建产物路径。
    public func build(
        projectURL: URL,
        scheme: String,
        configuration: String = "Debug"
    ) async throws -> URL {
        try await Task.detached {
            let buildResult = try Self.runXcodebuild(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                derivedDataPath: self.derivedDataPath,
                action: "build"
            )

            guard buildResult.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: buildResult))
            }

            let settingsResult = try Self.runXcodebuild(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                derivedDataPath: self.derivedDataPath,
                action: "-showBuildSettings"
            )

            guard settingsResult.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: settingsResult))
            }

            let buildSettings = Self.parseBuildSettings(settingsResult.stdout)
            guard let productURL = Self.findBuildProduct(from: buildSettings) else {
                throw PreviewError.buildProductNotFound
            }

            return productURL
        }.value
    }

    /// Returns compiler search arguments that allow a generated preview entry
    /// to import modules built by the Xcode target and its package products.
    public func previewCompilerArguments(
        projectURL: URL,
        scheme: String,
        configuration: String = "Debug"
    ) async throws -> [String] {
        try await Task.detached {
            let settingsResult = try Self.runXcodebuild(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                derivedDataPath: self.derivedDataPath,
                action: "-showBuildSettings"
            )

            guard settingsResult.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: settingsResult))
            }

            return Self.previewCompilerArguments(from: Self.parseBuildSettings(settingsResult.stdout))
        }.value
    }

    /// 从 build log 中提取指定文件的 `swift-frontend` 编译命令。
    ///
    /// - Parameters:
    ///   - fileURL: 需要增量编译的 Swift 文件。
    ///   - buildLog: `xcodebuild` 输出日志。
    /// - Returns: 匹配到的完整编译命令；未找到时返回 `nil`。
    public func extractCompileCommand(for fileURL: URL, buildLog: String) -> String? {
        let filePath = fileURL.standardizedFileURL.path
        return buildLog
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .first { line in
                line.contains("swift-frontend")
                    && (line.contains(filePath) || line.contains(fileURL.lastPathComponent))
            }
    }

    private struct BuildResult: Sendable {
        let terminationStatus: Int32
        let stdout: String
        let stderr: String
    }

    private static func runXcodebuild(
        projectURL: URL,
        scheme: String,
        configuration: String,
        derivedDataPath: URL?,
        action: String
    ) throws -> BuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments(
            projectURL: projectURL,
            scheme: scheme,
            configuration: configuration,
            derivedDataPath: derivedDataPath,
            action: action
        )
        process.currentDirectoryURL = projectURL.deletingLastPathComponent()

        let outputDirectory = PreviewStoragePaths.makeTransientWorkDirectory(component: "xcode-compiler")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        let stderrURL = outputDirectory.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        guard let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            throw PreviewError.compilationFailed(message: "Failed to capture xcodebuild output.")
        }
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            throw PreviewError.compilationFailed(message: "Failed to launch xcodebuild: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        return BuildResult(
            terminationStatus: process.terminationStatus,
            stdout: (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        )
    }

    private static func arguments(
        projectURL: URL,
        scheme: String,
        configuration: String,
        derivedDataPath: URL?,
        action: String
    ) -> [String] {
        var arguments = ["xcodebuild"]

        if projectURL.pathExtension == "xcworkspace" {
            arguments.append(contentsOf: ["-workspace", projectURL.path])
        } else {
            arguments.append(contentsOf: ["-project", projectURL.path])
        }

        arguments.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", "platform=macOS"
        ])

        if let derivedDataPath {
            arguments.append(contentsOf: ["-derivedDataPath", derivedDataPath.path])
        }

        arguments.append(action)

        return arguments
    }

    private static func parseBuildSettings(_ output: String) -> [String: String] {
        var settings: [String: String] = [:]

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }

            settings[key] = value
        }

        return settings
    }

    private static func findBuildProduct(from settings: [String: String]) -> URL? {
        let fileManager = FileManager.default
        let directoryKeys = ["TARGET_BUILD_DIR", "BUILT_PRODUCTS_DIR", "CONFIGURATION_BUILD_DIR"]
        let productKeys = ["FULL_PRODUCT_NAME", "WRAPPER_NAME", "EXECUTABLE_PATH", "EXECUTABLE_NAME"]

        for directoryKey in directoryKeys {
            guard let directory = settings[directoryKey] else { continue }

            for productKey in productKeys {
                guard let product = settings[productKey] else { continue }

                let candidate: URL
                if product.hasPrefix("/") {
                    candidate = URL(fileURLWithPath: product)
                } else {
                    candidate = URL(fileURLWithPath: directory)
                        .appendingPathComponent(product)
                }

                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func previewCompilerArguments(from settings: [String: String]) -> [String] {
        let directoryKeys = [
            "BUILT_PRODUCTS_DIR",
            "TARGET_BUILD_DIR",
            "CONFIGURATION_BUILD_DIR"
        ]
        let searchPathKeys = [
            "FRAMEWORK_SEARCH_PATHS",
            "LIBRARY_SEARCH_PATHS",
            "SWIFT_INCLUDE_PATHS",
            "HEADER_SEARCH_PATHS"
        ]

        var directories: [String] = []
        for key in directoryKeys {
            if let value = settings[key], !value.isEmpty {
                directories.append(value)
            }
        }
        for key in searchPathKeys {
            directories.append(contentsOf: splitBuildSettingList(settings[key] ?? ""))
        }

        let existingDirectories = directories
            .uniqued()
            .filter { FileManager.default.fileExists(atPath: $0) }

        var arguments: [String] = []
        for directory in existingDirectories {
            arguments.append(contentsOf: ["-I", directory, "-F", directory, "-L", directory])
            arguments.append(contentsOf: ["-Xlinker", "-rpath", "-Xlinker", directory])

            let includeDirectory = URL(fileURLWithPath: directory)
                .appendingPathComponent("include", isDirectory: true)
                .path
            if FileManager.default.fileExists(atPath: includeDirectory) {
                arguments.append(contentsOf: ["-Xcc", "-I", "-Xcc", includeDirectory])
            }
        }

        if isEnabled(settings["ENABLE_CODE_COVERAGE"]) {
            arguments.append("-profile-generate")
        }

        // For SPM packages embedded in Xcode projects, collect .o files from
        // DerivedData's Build/Products directory and Intermediates.
        // Xcode produces a merged .o per package target (e.g. LumiUI.o) which
        // contains all symbols — these MUST be linked even if the name matches
        // a product name, because they're the actual implementations.
        arguments.append(contentsOf: spmPackageObjectFileArguments(from: settings))

        // Also collect dependency .o files from the build products directory,
        // but exclude the main app's own .o file.
        arguments.append(
            contentsOf: linkInputArguments(
                in: existingDirectories.map { URL(fileURLWithPath: $0, isDirectory: true) },
                excludingProductNames: productNames(from: settings)
            )
        )
        arguments.append(contentsOf: packageLinkedLibraryArguments(from: settings))

        if let sdkRoot = settings["SDKROOT"], !sdkRoot.isEmpty {
            arguments.append(contentsOf: ["-sdk", sdkRoot])
        }
        arguments.append(contentsOf: moduleMapArguments(from: settings))
        if let deploymentTarget = settings["MACOSX_DEPLOYMENT_TARGET"],
           !deploymentTarget.isEmpty {
            arguments.append(contentsOf: [
                "-target",
                "\(targetArchitecture(from: settings))-apple-macos\(deploymentTarget)"
            ])
        }

        return deduplicatingLinkInputs(arguments)
    }

    private static func deduplicatingLinkInputs(_ arguments: [String]) -> [String] {
        var seenLinkInputs: Set<String> = []
        var result: [String] = []

        for argument in arguments {
            let url = URL(fileURLWithPath: argument)
            if url.pathExtension == "o" || url.pathExtension == "a" {
                guard seenLinkInputs.insert(url.standardizedFileURL.path).inserted else {
                    continue
                }
            }
            result.append(argument)
        }

        return result
    }

    private static func moduleMapArguments(from settings: [String: String]) -> [String] {
        let urls = moduleMapURLs(from: settings)
        let includeArguments = urls
            .map { $0.deletingLastPathComponent().path }
            .uniqued()
            .flatMap { ["-Xcc", "-I", "-Xcc", $0] }
        let moduleMapArguments = urls
            .sorted { $0.path < $1.path }
            .flatMap { ["-Xcc", "-fmodule-map-file=\($0.path)"] }
        return includeArguments + moduleMapArguments
    }

    private static func moduleMapURLs(from settings: [String: String]) -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        // 1. GENERATED_MODULEMAP_DIR — Xcode 自动生成的 Swift modulemaps
        if let directory = settings["GENERATED_MODULEMAP_DIR"],
           !directory.isEmpty,
           let entries = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: directory, isDirectory: true),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
           ) {
            urls.append(contentsOf: entries.filter { $0.pathExtension == "modulemap" })
        }

        if let builtProductsDirectory = settings["BUILT_PRODUCTS_DIR"] {
            let derivedDataDirectory = URL(fileURLWithPath: builtProductsDirectory)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()

            // 2. SourcePackages/checkouts — 远程 SPM 依赖中的 C/ObjC 模块
            let checkoutsDirectory = derivedDataDirectory
                .appendingPathComponent("SourcePackages", isDirectory: true)
                .appendingPathComponent("checkouts", isDirectory: true)
            if let enumerator = fileManager.enumerator(
                at: checkoutsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator where url.lastPathComponent == "module.modulemap" {
                    urls.append(url)
                }
            }

            // 3. Build/Intermediates — 通过 common-args.resp 发现本地 SPM 包中的 ObjC/C 模块。
            //    不直接收集 Intermediates 中的 modulemap 文件——Swift 模块的 modulemap
            //    已由 GENERATED_MODULEMAP_DIR（步骤 1）完整覆盖，
            //    各 .build 目录下的同名 modulemap 会导致 redefinition 错误。
            //    唯一目的是通过 ObjC target 的编译参数发现本地包源码中的 modulemap。
            let intermediatesDirectory = derivedDataDirectory
                .appendingPathComponent("Build", isDirectory: true)
                .appendingPathComponent("Intermediates.noindex", isDirectory: true)
            if fileManager.fileExists(atPath: intermediatesDirectory.path),
               let enumerator = fileManager.enumerator(
                at: intermediatesDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
               ) {
                for case let url as URL in enumerator {
                    // 只解析 common-args.resp，不收集散落的 modulemap
                    if url.lastPathComponent.hasSuffix("-common-args.resp") {
                        urls.append(contentsOf: moduleMapURLsFromCommonArgs(url))
                    }
                }
            }
        }

        // 4. HEADER_SEARCH_PATHS / USER_HEADER_SEARCH_PATHS —
        //    Xcode target 可能通过 header search paths 引用本地包中的 ObjC 模块。
        let headerSearchPathKeys = [
            "HEADER_SEARCH_PATHS",
            "USER_HEADER_SEARCH_PATHS",
            "SYSTEM_HEADER_SEARCH_PATHS"
        ]
        for key in headerSearchPathKeys {
            for path in splitBuildSettingList(settings[key] ?? "") {
                let headerDir = URL(fileURLWithPath: path, isDirectory: true)
                guard fileManager.fileExists(atPath: headerDir.path) else { continue }

                // 直接检查该目录下的 modulemap
                if let entries = try? fileManager.contentsOfDirectory(
                    at: headerDir,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    urls.append(contentsOf: entries.filter { $0.pathExtension == "modulemap" })
                }
            }
        }

        return urls
            .filter { $0.pathExtension == "modulemap" }
            .filter { isCompatibleModuleMap($0) }
            .uniqued()
    }

    /// 从 Xcode 中间产物 `common-args.resp` 文件中提取包含 modulemap 的 `-I` 路径。
    ///
    /// Xcode 为每个 target 生成 `common-args.resp`，其中包含实际的编译参数。
    /// 对于本地 SPM 包中的 ObjC target（如 `CodeEditTextViewObjC`），
    /// 文件会包含 `-I /path/to/Sources/TargetName/include` 这样的参数，
    /// 而 modulemap 就在该 include 目录中。
    static func moduleMapURLsFromCommonArgs(_ respURL: URL) -> [URL] {
        guard let content = try? String(contentsOf: respURL, encoding: .utf8) else { return [] }
        var urls: [URL] = []

        // 提取 -I 参数中的路径
        let args = content.split(separator: " ").map(String.init)
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "-I" && index + 1 < args.count {
                let path = args[index + 1]
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let includeDir = URL(fileURLWithPath: path, isDirectory: true)
                if FileManager.default.fileExists(atPath: includeDir.path),
                   let entries = try? FileManager.default.contentsOfDirectory(
                    at: includeDir,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                   ) {
                    urls.append(contentsOf: entries.filter { $0.pathExtension == "modulemap" })
                }
                index += 2
                continue
            }
            // 处理 -I/Path 形式
            if arg.hasPrefix("-I/") {
                let path = String(arg.dropFirst(2))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let includeDir = URL(fileURLWithPath: path, isDirectory: true)
                if FileManager.default.fileExists(atPath: includeDir.path),
                   let entries = try? FileManager.default.contentsOfDirectory(
                    at: includeDir,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                   ) {
                    urls.append(contentsOf: entries.filter { $0.pathExtension == "modulemap" })
                }
            }
            index += 1
        }

        return urls
    }

    private static func isCompatibleModuleMap(_ url: URL) -> Bool {
        let path = url.path
        guard path.contains(".xcframework/") else {
            return true
        }
        return path.contains("/macos-")
    }

    private static func targetArchitecture(from settings: [String: String]) -> String {
        for key in ["NATIVE_ARCH_ACTUAL", "CURRENT_ARCH", "ARCHS"] {
            guard let value = settings[key] else { continue }
            let candidates = splitBuildSettingList(value)
            if let architecture = candidates.first(where: { !$0.isEmpty && !$0.contains("$") && $0 != "undefined_arch" }) {
                return architecture
            }
        }

        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "arm64"
        #endif
    }

    /// Collects .o files for SPM package targets built by Xcode.
    ///
    /// Xcode compiles each SPM package target into a single merged .o file
    /// (e.g. `LumiUI.o`) in `Build/Products/`. These contain all symbols
    /// including types used by previews and must be linked into the preview dylib.
    private static func spmPackageObjectFileArguments(from settings: [String: String]) -> [String] {
        let productDirectories = [
            settings["BUILT_PRODUCTS_DIR"],
            settings["TARGET_BUILD_DIR"],
            settings["CONFIGURATION_BUILD_DIR"]
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }

        var objectFiles: [String] = []
        let mainTargetName = settings["TARGET_NAME"] ?? ""
        let productName = settings["PRODUCT_NAME"] ?? ""

        for directory in productDirectories {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "o" {
                let baseName = entry.deletingPathExtension().lastPathComponent
                // Only include .o files that are NOT the main app's own object file.
                // SPM package targets produce separate .o files (e.g. LumiUI.o).
                guard baseName != mainTargetName && baseName != productName else { continue }
                objectFiles.append(entry.path)
            }
        }

        return objectFiles.sorted().uniqued()
    }

    private static func splitBuildSettingList(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map(String.init)
            .map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            .filter { !$0.isEmpty && $0 != "$(inherited)" }
    }

    private static func isEnabled(_ value: String?) -> Bool {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "YES", "TRUE", "1":
            return true
        default:
            return false
        }
    }

    private static func productNames(from settings: [String: String]) -> Set<String> {
        let names = [
            settings["TARGET_NAME"],
            settings["PRODUCT_NAME"],
            settings["EXECUTABLE_NAME"],
            settings["FULL_PRODUCT_NAME"]?.replacingOccurrences(of: ".app", with: "")
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return Set(names)
    }

    private static func linkInputArguments(
        in directories: [URL],
        excludingProductNames productNames: Set<String>
    ) -> [String] {
        let fileManager = FileManager.default
        var inputs: [String] = []

        for directory in directories {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries {
                guard isLinkInput(entry, excludingProductNames: productNames) else { continue }
                inputs.append(entry.path)
            }
        }

        return inputs.sorted().uniqued()
    }

    private static func isLinkInput(_ url: URL, excludingProductNames productNames: Set<String>) -> Bool {
        let fileName = url.lastPathComponent
        let baseName = url.deletingPathExtension().lastPathComponent
        guard url.pathExtension == "o" || url.pathExtension == "a" else {
            return false
        }

        for productName in productNames {
            if fileName == "\(productName).o"
                || fileName == "lib\(productName).a"
                || baseName == productName {
                return false
            }
        }

        return true
    }

    private static func packageLinkedLibraryArguments(from settings: [String: String]) -> [String] {
        let libraryNames = sourcePackageCheckoutDirectories(from: settings)
            .flatMap(packageLinkedLibraries(in:))
            .uniqued()
        return libraryNames.map { "-l\($0)" }
    }

    private static func sourcePackageCheckoutDirectories(from settings: [String: String]) -> [URL] {
        let productDirectories = [
            settings["BUILT_PRODUCTS_DIR"],
            settings["TARGET_BUILD_DIR"],
            settings["CONFIGURATION_BUILD_DIR"]
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return productDirectories
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .compactMap { productDirectory -> URL? in
                let derivedDataDirectory = productDirectory
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                let checkoutsDirectory = derivedDataDirectory
                    .appendingPathComponent("SourcePackages", isDirectory: true)
                    .appendingPathComponent("checkouts", isDirectory: true)
                return FileManager.default.fileExists(atPath: checkoutsDirectory.path) ? checkoutsDirectory : nil
            }
            .map(\.path)
            .uniqued()
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private static func packageLinkedLibraries(in checkoutsDirectory: URL) -> [String] {
        let fileManager = FileManager.default
        guard let packages = try? fileManager.contentsOfDirectory(
            at: checkoutsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return packages.flatMap { packageDirectory -> [String] in
            let packageManifest = packageDirectory.appendingPathComponent("Package.swift")
            guard let source = try? String(contentsOf: packageManifest, encoding: .utf8) else {
                return []
            }
            return linkedLibraries(in: source)
        }
    }

    private static func linkedLibraries(in packageManifest: String) -> [String] {
        let pattern = /\.linkedLibrary\(\s*"([^"]+)"/
        return packageManifest
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let sourceLine = String(line)
                guard let match = sourceLine.firstMatch(of: pattern) else { return nil }
                if sourceLine.contains(".when(platforms:")
                    && !sourceLine.contains(".macOS")
                    && !sourceLine.contains(".macos") {
                    return nil
                }
                return String(match.1)
            }
    }

    private static func failureMessage(from result: BuildResult) -> String {
        let combinedOutput = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !combinedOutput.isEmpty else {
            return "xcodebuild failed with exit code \(result.terminationStatus)"
        }

        // 优先提取编译/链接级别的诊断行（file:line:col: error/warning: 格式）
        let diagnosticPattern = #":\d+:\d+:\s*(?:error|warning):"#
        let diagnosticLines = combinedOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                line.range(of: diagnosticPattern, options: .regularExpression) != nil
            }

        if !diagnosticLines.isEmpty {
            return diagnosticLines.joined(separator: "\n")
        }

        // 其次匹配 xcodebuild 自身的 error 行（但不匹配命令行回显中的 -scheme 等参数）
        let errorLines = combinedOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // 排除 xcodebuild 命令行回显（以 / 开头 + xcodebuild 参数）
                guard !trimmed.hasPrefix("/") || !trimmed.contains("xcodebuild") else {
                    return false
                }
                return trimmed.contains(": error:")
                    || trimmed.hasPrefix("error:")
                    || trimmed.contains("No such file")
                    || trimmed.contains("does not exist")
                    || trimmed.contains("BUILD FAILED")
                    || trimmed.contains("Undefined symbol")
                    || trimmed.contains("linker command failed")
                    || trimmed.contains("clang: error:")
                    || trimmed.contains("ld:")
            }

        if !errorLines.isEmpty {
            return errorLines.joined(separator: "\n")
        }

        // 最终兜底：返回输出中排除 xcodebuild 命令行回显后的内容
        let filteredOutput = combinedOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // 排除 xcodebuild 命令行回显
                guard !trimmed.hasPrefix("/") || !trimmed.contains("xcodebuild") else {
                    return false
                }
                // 排除纯空白行
                return !trimmed.isEmpty
            }
            .joined(separator: "\n")

        return filteredOutput.isEmpty
            ? "xcodebuild failed with exit code \(result.terminationStatus)"
            : filteredOutput
    }
}

}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in self where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for value in self where seen.insert(value.path).inserted {
            result.append(value)
        }
        return result
    }
}
