import Foundation
import LumiLoggingKit
import AppKit

@MainActor
public class HostsFileService: SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = false
    public static let shared = HostsFileService()
    private let hostsPath: String

    init(hostsPath: String = "/etc/hosts") {
        self.hostsPath = hostsPath
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Hosts file service initialized")
            }
        }
    }

    public func readHosts() async throws -> String {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Reading hosts file")
            }
        }
        return try Self.readTextFile(at: URL(fileURLWithPath: hostsPath))
    }

    public func saveHosts(content: String) async throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Saving hosts file")
            }
        }

        let hostsPath = self.hostsPath
        try await withTemporaryHostsFile(content: content) { tempURL in
            // Use osascript to move the temp file to /etc/hosts with admin privileges
            let script = """
            do shell script "cp '\(tempURL.path)' '\(hostsPath)' && chmod 644 '\(hostsPath)' && rm '\(tempURL.path)'" with administrator privileges
            """

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    if let scriptObject = NSAppleScript(source: script) {
                        scriptObject.executeAndReturnError(&error)
                        if let error = error {
                            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                            if HostsManagerPlugin.verbose {
                                                    HostsManagerPlugin.logger.error("\(Self.t)Failed to execute AppleScript: \(message)")
                            }
                            continuation.resume(throwing: NSError(domain: "HostsFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                        } else {
                            continuation.resume(returning: ())
                        }
                    } else {
                        if HostsManagerPlugin.verbose {
                                                HostsManagerPlugin.logger.error("\(Self.t)Failed to create NSAppleScript")
                        }
                        continuation.resume(throwing: NSError(domain: "HostsFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create NSAppleScript"]))
                    }
                }
            }
        }
    }

    /// 把 hosts 内容写入临时文件并交给 `install` 执行特权安装，无论成功、失败还是
    /// 用户取消授权，都在返回前尽力删除该临时文件（#256）。
    ///
    /// 临时文件含有即将写入的 hosts 配置；旧实现只在 AppleScript 的
    /// `cp && chmod && rm` 链全部成功时才删除它，取消或失败会把副本留在磁盘上。
    func withTemporaryHostsFile(
        content: String,
        install: (URL) async throws -> Void
    ) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hosts_tmp_\(UUID().uuidString)")
        // 特权命令链可能因取消授权 / cp / chmod 失败而中断，链尾的 rm 不会执行；
        // 用 defer 在所有路径上兜底删除，避免把含 hosts 配置的副本留在磁盘上。
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        try await install(tempURL)
    }

    public func backupHosts(to url: URL) async throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Backing up hosts file to: \(url.path)")
            }
        }
        // 源文件读取、UTF 解码与目标原子写入都是随文件大小增长的阻塞 IO，
        // 移到后台线程，主线程只发起任务（#1208）。
        let hostsPath = self.hostsPath
        try await Task.detached(priority: .userInitiated) {
            try Self.backupSync(hostsPath: hostsPath, to: url)
        }.value
    }

    /// 在后台线程读取 hosts 源文件并原子写入备份目标。
    nonisolated static func backupSync(hostsPath: String, to url: URL) throws {
        let content = try readTextFile(at: URL(fileURLWithPath: hostsPath))
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func importHosts(from url: URL) async throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Importing hosts from file: \(url.path)")
            }
        }
        // 导入接受任意文本/数据文件，读取与解码可能很大；先在后台线程读出内容，
        // 再回到主线程走既有特权保存流程（#1208）。
        let content = try await Task.detached(priority: .userInitiated) {
            try Self.readTextFile(at: url)
        }.value
        try await saveHosts(content: content)
    }

    nonisolated static func readTextFile(at url: URL) throws -> String {
        var encoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &encoding)
    }
}
