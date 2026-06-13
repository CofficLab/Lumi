import Foundation
import LumiCoreKit
import os
import SuperLogKit
import XcodeKit

enum EditorXcodeProjectPreloader {
    private static let logPrefix = "🚀 "

    public static func filterXcodeProjects(_ projects: [Project]) async -> [Project] {
        await Task.detached(priority: .utility) {
            projects.filter { project in
                let isXcodeProject = XcodeProjectResolver.isXcodeProjectRoot(URL(fileURLWithPath: project.path))
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(logPrefix)检查最近项目：\(project.name) -> isXcodeProject=\(isXcodeProject)")
                    }
                }
                return isXcodeProject
            }
        }.value
    }

    public static func preloadProject(_ project: Project, store: XcodeBuildServerStore) async -> Bool {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)开始预加载项目：\(project.name)，path=\(project.path)")
            }
        }
        guard let workspaceURL = await XcodeProjectBackgroundQuery.findWorkspace(in: project.path) else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.warning("\(logPrefix)预加载失败：未找到 workspace/xcodeproj，project=\(project.name)")
                }
            }
            return false
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)找到 workspace：\(workspaceURL.path)")
            }
        }

        if store.validate(forWorkspace: workspaceURL.path) != nil {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(logPrefix)buildServer 已存在且有效，跳过生成：\(workspaceURL.path)")
                }
            }
            return true
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)buildServer 不存在或无效，开始后台生成：\(workspaceURL.path)")
            }
        }
        return await Task.detached(priority: .background) {
            return await generateBuildServer(for: workspaceURL, projectName: project.name, store: store)
        }.value
    }

    private static func generateBuildServer(for workspaceURL: URL, projectName: String, store: XcodeBuildServerStore) async -> Bool {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)开始生成 buildServer：project=\(projectName)，workspace=\(workspaceURL.path)")
            }
        }

        let xcodeBuildServerPaths = [
            "/opt/homebrew/bin/xcode-build-server",
            "/usr/local/bin/xcode-build-server",
        ]

        var xcodeBuildServerPath: String?
        for path in xcodeBuildServerPaths {
            if FileManager.default.fileExists(atPath: path) {
                xcodeBuildServerPath = path
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(logPrefix)找到 xcode-build-server：\(path)")
                    }
                }
                break
            }
        }

        if xcodeBuildServerPath == nil {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(logPrefix)默认路径未找到 xcode-build-server，尝试 which")
                }
            }
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/which")
            process.arguments = ["xcode-build-server"]
            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0,
                   let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
                   let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    xcodeBuildServerPath = path
                    if SwiftPluginLog.verbose {
                        if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(logPrefix)which 找到 xcode-build-server：\(path)")
                        }
                    }
                } else if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.warning("\(logPrefix)which xcode-build-server 未找到，terminationStatus=\(process.terminationStatus)")
                    }
                }
            } catch {
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.error("\(logPrefix)执行 which xcode-build-server 失败：\(error.localizedDescription)")
                    }
                }
            }
        }

        guard let serverPath = xcodeBuildServerPath else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.warning("\(logPrefix)生成 buildServer 失败：找不到 xcode-build-server")
                }
            }
            return false
        }

        let schemes = await XcodeSchemeFetcher.fetchAvailableSchemes(for: workspaceURL)
        guard let scheme = schemes.first else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.warning("\(logPrefix)生成 buildServer 失败：未找到可用 scheme，workspace=\(workspaceURL.path)")
                }
            }
            return false
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)使用 scheme 生成 buildServer：\(scheme)，schemesCount=\(schemes.count)")
            }
        }

        let outputDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)

        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        let args = ["config", workspaceArg, workspaceURL.path, "-scheme", scheme]

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(logPrefix)执行 xcode-build-server：\(serverPath) \(args.joined(separator: " "))，cwd=\(outputDirectory.path)")
            }
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: serverPath)
            process.arguments = args
            process.currentDirectoryURL = outputDirectory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                let success = process.terminationStatus == 0
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(logPrefix)xcode-build-server 结束，success=\(success)，terminationStatus=\(process.terminationStatus)")
                    }
                }
                continuation.resume(returning: success)
            }

            do {
                try process.run()
            } catch {
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.error("\(logPrefix)xcode-build-server 启动失败：\(error.localizedDescription)")
                    }
                }
                continuation.resume(returning: false)
            }
        }
    }

}