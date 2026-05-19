import Foundation

public extension LumiPreviewFacade {
    struct IncrementalBuildResult: Sendable, Equatable {
        public let objectURL: URL
        public let dylibURL: URL

        public init(objectURL: URL, dylibURL: URL) {
            self.objectURL = objectURL
            self.dylibURL = dylibURL
        }
    }

    struct ModuleImportPlan: Sendable, Equatable {
        public let moduleName: String
        public let searchPaths: [String]
        public let compilerArguments: [String]
        public let moduleArtifactPath: String?

        public init(
            moduleName: String,
            searchPaths: [String],
            compilerArguments: [String],
            moduleArtifactPath: String? = nil
        ) {
            self.moduleName = moduleName
            self.searchPaths = searchPaths
            self.compilerArguments = compilerArguments
            self.moduleArtifactPath = moduleArtifactPath
        }

        public var hasUsableModuleArtifact: Bool {
            moduleArtifactPath?.isEmpty == false
        }
    }

    final class IncrementalBuildPipeline: Sendable {
        private let incrementalCompiler: LumiPreviewFacade.IncrementalCompiler
        private let xcodeCompiler: LumiPreviewFacade.XcodeCompiler
        private let compilerArgumentResolver: @Sendable (LumiPreviewFacade.BuildStrategy) async throws -> [String]
        private let moduleNameResolver: @Sendable (LumiPreviewFacade.BuildStrategy) async throws -> String?
        private let moduleImportPlanCache: ModuleImportPlanCache

        public init(
            incrementalCompiler: LumiPreviewFacade.IncrementalCompiler = .init(),
            xcodeCompiler: LumiPreviewFacade.XcodeCompiler = .init(),
            compilerArgumentResolver: (@Sendable (LumiPreviewFacade.BuildStrategy) async throws -> [String])? = nil,
            moduleNameResolver: (@Sendable (LumiPreviewFacade.BuildStrategy) async throws -> String?)? = nil,
            moduleImportPlanCache: ModuleImportPlanCache = .init()
        ) {
            self.incrementalCompiler = incrementalCompiler
            self.xcodeCompiler = xcodeCompiler
            self.compilerArgumentResolver = compilerArgumentResolver
                ?? Self.defaultCompilerArgumentResolver(
                    spmCompiler: LumiPreviewFacade.SPMCompiler(),
                    xcodeCompiler: xcodeCompiler
                )
            self.moduleNameResolver = moduleNameResolver
                ?? Self.defaultModuleNameResolver(xcodeCompiler: xcodeCompiler)
            self.moduleImportPlanCache = moduleImportPlanCache
        }

        public func captureBuildLog(
            for buildStrategy: LumiPreviewFacade.BuildStrategy
        ) async throws -> String? {
            switch buildStrategy {
            case .xcode(let projectURL, let scheme, let configuration):
                return try await captureXcodeBuildLog(
                    projectURL: projectURL,
                    scheme: scheme,
                    configuration: configuration,
                    derivedDataPath: xcodeCompiler.derivedDataPath
                )
            case .spm, .incremental:
                return nil
            }
        }

        public func extractCommands(
            from buildLog: String,
            fileURLs: [URL]
        ) -> [URL: String] {
            var extracted: [URL: String] = [:]
            for fileURL in fileURLs {
                if let command = extractCommand(from: buildLog, for: fileURL) {
                    extracted[fileURL] = command
                }
            }
            return extracted
        }

        public func compileSingleFile(
            fileURL: URL,
            compileCommand: String
        ) async throws -> URL {
            try await incrementalCompiler.compile(fileURL: fileURL, compileCommand: compileCommand)
        }

        public func linkPreviewEntry(objectURLs: [URL]) async throws -> URL {
            guard let firstObjectURL = objectURLs.first else {
                throw LumiPreviewFacade.PreviewError.buildProductNotFound
            }

            let dylibURL = firstObjectURL
                .deletingLastPathComponent()
                .appendingPathComponent("PreviewEntry")
                .appendingPathExtension("dylib")
            let command = Self.emitLibraryCommand(
                inputPaths: objectURLs.map(\.path),
                dylibOutputPath: dylibURL.path,
                additionalArguments: [],
                enableInterposableLinking: true,
                enableDeadStripLinking: true
            )
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: dylibURL.path) else {
                throw LumiPreviewFacade.PreviewError.compilationFailed(
                    message: "Failed to link incremental preview entry."
                )
            }

            try await incrementalCompiler.codesign(dylibURL: dylibURL)
            return dylibURL
        }

        public func buildSingleFilePreview(
            fileURL: URL,
            compileCommand: String
        ) async throws -> IncrementalBuildResult {
            let objectURL = try await compileSingleFile(fileURL: fileURL, compileCommand: compileCommand)
            let dylibURL = try await linkPreviewEntry(objectURLs: [objectURL])
            return IncrementalBuildResult(objectURL: objectURL, dylibURL: dylibURL)
        }

        public func compilePreviewEntryImportingModule(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewFacade.BuildStrategy,
            importPlan: ModuleImportPlan? = nil
        ) async throws -> URL {
            let importPlan = try await resolvedImportPlan(
                buildStrategy: buildStrategy,
                importPlan: importPlan
            )
            let source = try await generateEntryImportingModule(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                importPlan: importPlan
            )
            let directory = PreviewStoragePaths.makeTransientWorkDirectory(component: "import-entry")

            let sourceURL = directory.appendingPathComponent("PreviewEntry.swift")
            let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")
            try source.write(to: sourceURL, atomically: true, encoding: .utf8)

            let moduleName = Self.previewEntryModuleName(
                previewID: discovery.id,
                importedModuleName: importPlan.moduleName
            )
            let dylib = try await compileLibrary(
                sourceURLs: [sourceURL],
                dylibURL: dylibURL,
                compilerArguments: LumiPreviewFacade.SPMCompiler.filterDedicatedPreviewObjectArguments(
                    importPlan.compilerArguments
                ),
                moduleName: moduleName
            )
            try await incrementalCompiler.codesign(dylibURL: dylib)
            return dylib
        }

        public func compilePreviewEntryIncludingCurrentSource(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewFacade.BuildStrategy
        ) async throws -> URL {
            let compilerArguments = try await compilerArgumentResolver(buildStrategy)
            let directory = PreviewStoragePaths.makeTransientWorkDirectory(component: "source-entry")

            let currentSourceURL = directory.appendingPathComponent("CurrentSource.swift")
            let entrySourceURL = directory.appendingPathComponent("PreviewEntry.swift")
            let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")

            let currentSource = try sanitizedCurrentSource(discovery: discovery)
            let entrySource = try generateEntryIncludingCurrentSource(
                discovery: discovery,
                configuration: configuration
            )

            try currentSource.write(to: currentSourceURL, atomically: true, encoding: .utf8)
            try entrySource.write(to: entrySourceURL, atomically: true, encoding: .utf8)

            let moduleName = Self.previewEntryModuleName(
                previewID: discovery.id,
                importedModuleName: "SourceInclude"
            )
            let prebuiltObjectName = discovery.sourceFileURL
                .deletingPathExtension()
                .lastPathComponent + ".swift.o"
            let linkArguments = LumiPreviewFacade.SPMCompiler.filterDedicatedPreviewObjectArguments(
                Self.filterCompilerArguments(
                    compilerArguments,
                    excludingPrebuiltObjectNamed: prebuiltObjectName
                )
            )
            let dylib = try await compileLibrary(
                sourceURLs: [currentSourceURL, entrySourceURL],
                dylibURL: dylibURL,
                compilerArguments: linkArguments,
                moduleName: moduleName
            )
            try await incrementalCompiler.codesign(dylibURL: dylib)
            return dylib
        }

        public func resolveModuleSearchPaths(
            buildStrategy: LumiPreviewFacade.BuildStrategy
        ) async throws -> [String] {
            let arguments = try await compilerArgumentResolver(buildStrategy)
            return Self.moduleSearchPaths(from: arguments)
        }

        public func generateEntryImportingModule(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration = .empty,
            buildStrategy: LumiPreviewFacade.BuildStrategy,
            importPlan: ModuleImportPlan? = nil
        ) async throws -> String {
            let plan = try await resolvedImportPlan(
                buildStrategy: buildStrategy,
                importPlan: importPlan
            )
            let previewBody = discovery.bodySource?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let previewBody, !previewBody.isEmpty else {
                throw LumiPreviewFacade.PreviewError.compilationFailed(
                    message: "Missing preview body for import-based entry generation."
                )
            }

            let descriptor = Self.previewEntryDescriptorJSON(
                discovery: discovery,
                configuration: configuration
            )

            return """
            import AppKit
            import Darwin
            import SwiftUI
            import \(plan.moduleName)

            @_cdecl("\(LumiPreviewFacade.PreviewEntryBuilder.symbolName)")
            public func \(Self.previewDescriptorFunctionName)() -> UnsafePointer<CChar>? {
                let json = "\(Self.swiftStringLiteralContents(descriptor))"
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("\(LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName)")
            public func \(Self.previewViewFunctionName)() -> UnsafeMutableRawPointer? {
                let rootView = AnyView({ \(previewBody) }())
                let hostingView = NSHostingView(rootView: rootView)
                hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(hostingView).toOpaque()
            }
            """
        }

        public func resolveModuleImportPlan(
            buildStrategy: LumiPreviewFacade.BuildStrategy
        ) async throws -> ModuleImportPlan {
            if let cached = await moduleImportPlanCache.plan(for: buildStrategy) {
                return cached
            }

            let compilerArguments = try await compilerArgumentResolver(buildStrategy)
            let moduleName = try await inferModuleName(
                from: buildStrategy,
                compilerArguments: compilerArguments
            )
            let plan = ModuleImportPlan(
                moduleName: moduleName,
                searchPaths: Self.moduleSearchPaths(from: compilerArguments),
                compilerArguments: compilerArguments,
                moduleArtifactPath: Self.findModuleArtifactPath(
                    moduleName: moduleName,
                    searchPaths: Self.moduleSearchPaths(from: compilerArguments)
                )
            )
            await moduleImportPlanCache.store(plan, for: buildStrategy)
            return plan
        }

        private func resolvedImportPlan(
            buildStrategy: LumiPreviewFacade.BuildStrategy,
            importPlan: ModuleImportPlan?
        ) async throws -> ModuleImportPlan {
            if let importPlan {
                return importPlan
            }
            return try await resolveModuleImportPlan(buildStrategy: buildStrategy)
        }

        public func generateEntryIncludingCurrentSource(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration = .empty
        ) throws -> String {
            let previewBody = discovery.bodySource?.trimmingCharacters(in: .whitespacesAndNewlines)
            let viewBody = (previewBody?.isEmpty == false) ? previewBody! : #"Text("Empty Preview")"#
            let descriptor = Self.previewEntryDescriptorJSON(
                discovery: discovery,
                configuration: configuration
            )

            return """
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("\(LumiPreviewFacade.PreviewEntryBuilder.symbolName)")
            public func \(Self.previewDescriptorFunctionName)() -> UnsafePointer<CChar>? {
                let json = "\(Self.swiftStringLiteralContents(descriptor))"
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("\(LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName)")
            public func \(Self.previewViewFunctionName)() -> UnsafeMutableRawPointer? {
                let rootView = AnyView({
            \(Self.indented(viewBody, spaces: 8))
                }())
                let view = NSHostingView(rootView: rootView)
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """
        }

        private func extractCommand(from buildLog: String, for fileURL: URL) -> String? {
            if let xcodeCommand = xcodeCompiler.extractCompileCommand(for: fileURL, buildLog: buildLog) {
                return xcodeCommand
            }

            let filePath = fileURL.standardizedFileURL.path
            return buildLog
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .first { line in
                    line.contains("swift-frontend")
                        && (line.contains(filePath) || line.contains(fileURL.lastPathComponent))
                }
        }

        private func captureXcodeBuildLog(
            projectURL: URL,
            scheme: String,
            configuration: String,
            derivedDataPath: URL?
        ) async throws -> String {
            try await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = Self.xcodebuildArguments(
                    projectURL: projectURL,
                    scheme: scheme,
                    configuration: configuration,
                    derivedDataPath: derivedDataPath
                )
                process.currentDirectoryURL = projectURL.deletingLastPathComponent()

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    throw LumiPreviewFacade.PreviewError.compilationFailed(
                        message: "Failed to launch xcodebuild for compile command capture: \(error.localizedDescription)"
                    )
                }

                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let combined = [stdout, stderr]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                guard process.terminationStatus == 0 else {
                    throw LumiPreviewFacade.PreviewError.compilationFailed(
                        message: combined.isEmpty
                            ? "xcodebuild failed during compile command capture."
                            : combined
                    )
                }

                return combined
            }.value
        }

        private static func xcodebuildArguments(
            projectURL: URL,
            scheme: String,
            configuration: String,
            derivedDataPath: URL?
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

            arguments.append("build")

            return arguments
        }

        private func shellQuoted(_ value: String) -> String {
            "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
        }

        private func inferModuleName(
            from buildStrategy: LumiPreviewFacade.BuildStrategy,
            compilerArguments: [String]
        ) async throws -> String {
            if let explicit = Self.argumentValue(named: "-module-name", in: compilerArguments) {
                return explicit
            }

            if let resolved = try await moduleNameResolver(buildStrategy),
               !resolved.isEmpty {
                return resolved
            }

            switch buildStrategy {
            case .spm(_, let targetName):
                return targetName
            case .xcode(_, let scheme, _):
                return scheme
            case .incremental(let fileURL, _):
                throw LumiPreviewFacade.PreviewError.compilationFailed(
                    message: "Cannot infer module name for incremental file \(fileURL.lastPathComponent)."
                )
            }
        }

        static func previewEntryCompilerArguments(
            appendingTo arguments: [String]
        ) -> [String] {
            arguments + LumiPreviewFacade.PreviewEntryBuilder.previewDebugConditionArguments
        }

        private static func defaultCompilerArgumentResolver(
            spmCompiler: LumiPreviewFacade.SPMCompiler,
            xcodeCompiler: LumiPreviewFacade.XcodeCompiler
        ) -> @Sendable (LumiPreviewFacade.BuildStrategy) async throws -> [String] {
            { buildStrategy in
                let arguments: [String]
                switch buildStrategy {
                case .spm(let packageDirectory, let targetName):
                    arguments = spmCompiler.previewCompilerArguments(
                        packageDirectory: packageDirectory,
                        targetName: targetName
                    )
                case .xcode(let projectURL, let scheme, let configuration):
                    arguments = try await xcodeCompiler.previewCompilerArguments(
                        projectURL: projectURL,
                        scheme: scheme,
                        configuration: configuration
                    )
                case .incremental:
                    arguments = []
                }
                return Self.previewEntryCompilerArguments(appendingTo: arguments)
            }
        }

        private static func defaultModuleNameResolver(
            xcodeCompiler: LumiPreviewFacade.XcodeCompiler
        ) -> @Sendable (LumiPreviewFacade.BuildStrategy) async throws -> String? {
            { buildStrategy in
                switch buildStrategy {
                case .spm(_, let targetName):
                    return targetName
                case .xcode(let projectURL, let scheme, let configuration):
                    return try await resolveXcodeModuleName(
                        projectURL: projectURL,
                        scheme: scheme,
                        configuration: configuration,
                        derivedDataPath: xcodeCompiler.derivedDataPath
                    )
                case .incremental:
                    return nil
                }
            }
        }

        private static func moduleSearchPaths(from compilerArguments: [String]) -> [String] {
            var paths: [String] = []
            var index = 0

            while index < compilerArguments.count {
                let argument = compilerArguments[index]
                if argument == "-I", index + 1 < compilerArguments.count {
                    paths.append(compilerArguments[index + 1])
                    index += 2
                    continue
                }
                if argument.hasPrefix("-I"), argument.count > 2 {
                    paths.append(String(argument.dropFirst(2)))
                }
                index += 1
            }

            var seen = Set<String>()
            return paths.filter { seen.insert($0).inserted }
        }

        private static func argumentValue(named name: String, in arguments: [String]) -> String? {
            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                if argument == name, index + 1 < arguments.count {
                    return arguments[index + 1]
                }
                if argument.hasPrefix("\(name)=") {
                    return String(argument.dropFirst(name.count + 1))
                }
                index += 1
            }
            return nil
        }

        private static func findModuleArtifactPath(
            moduleName: String,
            searchPaths: [String]
        ) -> String? {
            let fileManager = FileManager.default

            for searchPath in searchPaths {
                let root = URL(fileURLWithPath: searchPath, isDirectory: true)
                let candidates = [
                    root.appendingPathComponent("\(moduleName).swiftmodule").path,
                    root.appendingPathComponent("Modules", isDirectory: true)
                        .appendingPathComponent("\(moduleName).swiftmodule").path,
                    root.appendingPathComponent("\(moduleName).framework", isDirectory: true)
                        .appendingPathComponent("Modules", isDirectory: true)
                        .appendingPathComponent("\(moduleName).swiftmodule").path,
                    root.appendingPathComponent("\(moduleName).swiftinterface").path
                ]

                for candidate in candidates where fileManager.fileExists(atPath: candidate) {
                    return candidate
                }
            }

            return nil
        }

        private static func resolveXcodeModuleName(
            projectURL: URL,
            scheme: String,
            configuration: String,
            derivedDataPath: URL?
        ) async throws -> String? {
            try await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = xcodebuildSettingsArguments(
                    projectURL: projectURL,
                    scheme: scheme,
                    configuration: configuration,
                    derivedDataPath: derivedDataPath
                )
                process.currentDirectoryURL = projectURL.deletingLastPathComponent()

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    throw LumiPreviewFacade.PreviewError.compilationFailed(
                        message: "Failed to launch xcodebuild for module resolution: \(error.localizedDescription)"
                    )
                }
                process.waitUntilExit()

                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let combined = [stdout, stderr]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                guard process.terminationStatus == 0 else {
                    throw LumiPreviewFacade.PreviewError.compilationFailed(
                        message: combined.isEmpty
                            ? "xcodebuild failed during module resolution."
                            : combined
                    )
                }

                let settings = parseBuildSettings(stdout)
                for key in ["PRODUCT_MODULE_NAME", "SWIFT_MODULE_NAME", "PRODUCT_NAME", "TARGET_NAME"] {
                    if let value = settings[key], !value.isEmpty {
                        return value
                    }
                }
                return nil
            }.value
        }

        private static func xcodebuildSettingsArguments(
            projectURL: URL,
            scheme: String,
            configuration: String,
            derivedDataPath: URL?
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

            arguments.append("-showBuildSettings")

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

        private func compileLibrary(
            sourceURLs: [URL],
            dylibURL: URL,
            compilerArguments: [String],
            moduleName: String
        ) async throws -> URL {
            try await Task.detached {
                let sourceArguments = sourceURLs
                    .map(\.path)
                let extraArguments = Self.compilerArguments(
                    compilerArguments,
                    replacingModuleNameWith: moduleName
                )
                let command = Self.emitLibraryCommand(
                    inputPaths: sourceArguments,
                    dylibOutputPath: dylibURL.path,
                    additionalArguments: extraArguments,
                    enableInterposableLinking: true,
                    enableDeadStripLinking: true
                )

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: dylibURL.path) else {
                    throw LumiPreviewFacade.PreviewError.compilationFailed(
                        message: "Failed to compile import-based preview entry."
                    )
                }

                return dylibURL
            }.value
        }

        private static func previewEntryDescriptorJSON(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration
        ) -> String {
            var payload: [String: Any] = [
                "title": discovery.title,
                "isFallback": false
            ]
            if let subtitle = discovery.primaryTypeName, !subtitle.isEmpty {
                payload["subtitle"] = subtitle
            }

            var bodyParts: [String] = []
            if let bodySource = discovery.bodySource?.trimmingCharacters(in: .whitespacesAndNewlines),
               !bodySource.isEmpty {
                bodyParts.append(bodySource)
            }
            if configuration.hasEnvironmentInjections {
                bodyParts.append("\(configuration.environmentInjections.count) environment mock(s)")
            }
            if !bodyParts.isEmpty {
                payload["body"] = bodyParts.joined(separator: "\n")
            }

            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else {
                return #"{"title":"Preview","isFallback":false}"#
            }
            return json
        }

        private static func previewEntryModuleName(
            previewID: String,
            importedModuleName: String
        ) -> String {
            let raw = "LumiPreview_\(importedModuleName)_\(previewID)"
            let sanitizedScalars = raw.unicodeScalars.map { scalar -> Character in
                if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
                    return Character(scalar)
                }
                return "_"
            }
            return String(sanitizedScalars)
        }

        private static func swiftStringLiteralContents(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
        }

        static func filterCompilerArguments(
            _ arguments: [String],
            excludingPrebuiltObjectNamed objectName: String
        ) -> [String] {
            guard !objectName.isEmpty else { return arguments }
            return arguments.filter { argument in
                guard argument.hasSuffix(".o") || argument.hasSuffix(".a") else {
                    return true
                }
                return !argument.hasSuffix(objectName)
            }
        }

        private static func compilerArguments(
            _ arguments: [String],
            replacingModuleNameWith moduleName: String
        ) -> [String] {
            var filtered: [String] = []
            var iterator = arguments.makeIterator()
            while let argument = iterator.next() {
                if argument == "-module-name" {
                    _ = iterator.next()
                    continue
                }
                if argument.hasPrefix("-module-name=") {
                    continue
                }
                filtered.append(argument)
            }

            filtered.append(contentsOf: ["-module-name", moduleName])
            return filtered
        }

        static func emitLibraryCommand(
            inputPaths: [String],
            dylibOutputPath: String,
            additionalArguments: [String],
            enableInterposableLinking: Bool,
            enableDeadStripLinking: Bool = false
        ) -> String {
            let inputs = inputPaths
                .map(shellQuoted)
                .joined(separator: " ")
            var linkerArguments: [String] = []
            if enableDeadStripLinking {
                linkerArguments.append(contentsOf: ["-Xlinker", "-dead_strip"])
            }
            if enableInterposableLinking {
                linkerArguments.append(contentsOf: ["-Xlinker", "-interposable"])
            }
            let extraArguments = (additionalArguments + linkerArguments)
                .map(shellQuoted)
                .joined(separator: " ")

            return [
                "/usr/bin/env swiftc -emit-library",
                extraArguments,
                inputs,
                "-o \(shellQuoted(dylibOutputPath))"
            ]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        private static func shellQuoted(_ value: String) -> String {
            "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
        }

        private func sanitizedCurrentSource(
            discovery: LumiPreviewFacade.PreviewDiscovery
        ) throws -> String {
            let source: String
            if let existingSource = discovery.sourceText {
                source = existingSource
            } else {
                source = try String(contentsOf: discovery.sourceFileURL, encoding: .utf8)
            }
            let previews = LumiPreviewFacade.PreviewScanner().scan(
                fileURL: discovery.sourceFileURL,
                sourceText: source
            )
            var lines = source.components(separatedBy: .newlines)
            for preview in previews.sorted(by: { $0.lineNumber > $1.lineNumber }) {
                let start = max(preview.lineNumber - 1, 0)
                let end = min(preview.endLineNumber - 1, lines.count - 1)
                guard start <= end else { continue }
                lines.replaceSubrange(start...end, with: [])
            }
            Self.removeMainAttribute(from: &lines)
            Self.replaceBundleModuleReferences(in: &lines)
            return lines.joined(separator: "\n")
        }

        private static func removeMainAttribute(from lines: inout [String]) {
            for index in lines.indices.reversed() {
                let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "@main" {
                    lines.remove(at: index)
                } else if trimmed.hasPrefix("@main "),
                          let range = lines[index].range(of: "@main") {
                    lines[index].removeSubrange(range)
                }
            }
        }

        /// Replaces `Bundle.module` with `Bundle.main` so preview entry dylibs compile
        /// outside the original SPM target context.
        ///
        /// SwiftPM auto-generates a `resource_bundle_accessor.swift` that declares
        /// `Bundle.module` as `internal`.  Preview entry dylibs are compiled in an
        /// isolated context without that accessor, so any `Bundle.module` reference
        /// produces "'module' is inaccessible due to 'internal' protection level".
        private static func replaceBundleModuleReferences(in lines: inout [String]) {
            for index in lines.indices {
                if lines[index].contains("Bundle.module") {
                    lines[index] = lines[index].replacingOccurrences(
                        of: "Bundle.module",
                        with: "Bundle.main"
                    )
                }
            }
        }

        private static func indented(_ value: String, spaces: Int) -> String {
            let padding = String(repeating: " ", count: spaces)
            return value
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "\(padding)\($0)" }
                .joined(separator: "\n")
        }

        private static let previewDescriptorFunctionName = "lumiPreviewEntry"
        private static let previewViewFunctionName = "lumiPreviewMakeNSView"
    }
}
