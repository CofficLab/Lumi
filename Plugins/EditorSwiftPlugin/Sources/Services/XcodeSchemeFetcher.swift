import Foundation
import SuperLogKit
import XcodeKit

enum XcodeSchemeFetcher: SuperLog {
    static func fetchAvailableSchemes(for workspaceURL: URL) async -> [String] {
        let filesystemSchemes = await Task.detached(priority: .userInitiated) {
            XcodeProjectResolver.discoverSchemeNames(at: workspaceURL)
        }.value
        if !filesystemSchemes.isEmpty {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(Self.t)从 .xcscheme 文件获取 schemes，count=\(filesystemSchemes.count)")
            }
            return filesystemSchemes
        }
        return await fetchSchemesViaXcodebuild(for: workspaceURL)
    }

    private static func fetchSchemesViaXcodebuild(for workspaceURL: URL) async -> [String] {
        var args = ["-list", "-json"]
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        args += [workspaceArg, workspaceURL.path]

        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(Self.t)开始获取 schemes：xcodebuild \(args.joined(separator: " "))")
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/xcodebuild")
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                guard process.terminationStatus == 0,
                      let data = try? JSONSerialization.jsonObject(with: pipe.fileHandleForReading.readDataToEndOfFile()) as? [String: Any] else {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.warning("\(Self.t)xcodebuild 获取 schemes 失败，terminationStatus=\(process.terminationStatus)")
                    }
                    continuation.resume(returning: [])
                    return
                }

                var schemes: [String] = []
                if let project = data["project"] as? [String: Any],
                   let projectSchemes = project["schemes"] as? [String] {
                    schemes.append(contentsOf: projectSchemes)
                }
                if let workspace = data["workspace"] as? [String: Any],
                   let workspaceSchemes = workspace["schemes"] as? [String] {
                    schemes.append(contentsOf: workspaceSchemes)
                }

                let uniqueSchemes = XcodeProjectResolver.uniquePreservingOrder(schemes)
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t)xcodebuild 获取 schemes 完成，count=\(uniqueSchemes.count)")
                }
                continuation.resume(returning: uniqueSchemes)
            }

            do {
                try process.run()
            } catch {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.error("\(Self.t)xcodebuild 启动失败：\(error.localizedDescription)")
                }
                continuation.resume(returning: [])
            }
        }
    }
}
