import Foundation
import LumiKernel
import SuperLogKit
import os

/// 布局状态持久化存储
///
/// 负责 `LayoutStateInfo`（`activeSectionID`、`activeSectionTitle`、`chatSectionVisible`）的磁盘读写。
/// 数据目录来自构造时注入的 `pluginDirectory`，其获取方式与 `ProjectsPlugin.onReady` 一致：
/// `kernel.storage.pluginDataDirectory(for: "LayoutKernel")`。
///
/// 写入采用临时文件 + `replaceItemAt` 的原子写策略，避免崩溃导致半截文件。
@MainActor
public final class LayoutStore: SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.layoutkernel.store"
    )
    public nonisolated static let emoji = "📐"
    public static var verbose = false

    // MARK: - Constants

    private static let settingsDirectoryName = "settings"
    private static let layoutInfoFileName = "layout-info.json"

    // MARK: - Properties

    public let settingsDirectory: URL

    // MARK: - Init

    /// - Parameter pluginDirectory: 插件数据目录（由 `kernel.storage.pluginDataDirectory(for:)` 传入）。
    ///   为 `nil` 时回落到临时目录，仅用于无内核场景（如单元测试）。
    public init(pluginDirectory: URL?) {
        let directory = pluginDirectory ?? Self.defaultPluginDirectory
        self.settingsDirectory = directory
            .appendingPathComponent(Self.settingsDirectoryName, isDirectory: true)

        if Self.verbose {
            Self.logger.info("\(Self.t)初始化完成, settingsDirectory: \(self.settingsDirectory.path)")
        }
    }

    /// 无内核场景下的兜底目录。
    private static var defaultPluginDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/LayoutKernel")
    }

    // MARK: - Read

    /// 从磁盘读取已保存的布局信息。
    /// - Returns: 已保存的 `LayoutStateInfo`；文件不存在、空或损坏时返回 `nil`。
    public func loadLayoutInfo() -> LayoutStateInfo? {
        guard let data = try? Data(contentsOf: layoutInfoFileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(LayoutStateInfo.self, from: data)
    }

    // MARK: - Write

    /// 将布局信息写入磁盘。
    ///
    /// 传入 `nil` 时等价于清除（删除文件，保持目录干净）。
    public func saveLayoutInfo(_ info: LayoutStateInfo?) {
        guard let info else {
            removeLayoutInfoFile()
            return
        }
        try? FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        Self.write(info, to: layoutInfoFileURL)
    }

    // MARK: - Private

    private var layoutInfoFileURL: URL {
        settingsDirectory.appendingPathComponent(Self.layoutInfoFileName, isDirectory: false)
    }

    /// 删除持久化文件（若存在）。
    private func removeLayoutInfoFile() {
        let url = layoutInfoFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 原子写入：先写临时文件，再 `replaceItemAt` 替换目标。
    private static func write<Value: Encodable>(_ value: Value, to fileURL: URL) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        let temporaryURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).tmp", isDirectory: false)

        do {
            try data.write(to: temporaryURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}
