import Foundation

/// 插件数据迁移所需的版本根目录上下文。
///
/// 迁移发生在插件 `onBoot` 之前，因此插件可以安全地把历史数据准备到
/// 当前版本目录，再创建自己的 store 或 ViewModel。
@MainActor
public struct PluginDataMigrationContext: Sendable {
    public let pluginID: String
    public let currentMajorVersion: Int
    public let currentDataRootDirectory: URL
    public let legacyDataRootDirectories: [Int: URL]

    public init(
        pluginID: String,
        currentMajorVersion: Int,
        currentDataRootDirectory: URL,
        legacyDataRootDirectories: [Int: URL]
    ) {
        self.pluginID = pluginID
        self.currentMajorVersion = currentMajorVersion
        self.currentDataRootDirectory = currentDataRootDirectory.standardizedFileURL
        self.legacyDataRootDirectories = legacyDataRootDirectories.mapValues(\.standardizedFileURL)
    }

    public var currentPluginDataDirectory: URL {
        currentDataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
    }

    public func legacyPluginDataDirectory(
        named legacyDirectoryName: String,
        in majorVersion: Int
    ) -> URL? {
        legacyDataRootDirectories[majorVersion]?
            .appendingPathComponent(legacyDirectoryName, isDirectory: true)
    }
}

/// 声明插件拥有自己的持久化数据迁移逻辑。
@MainActor
public protocol PluginDataMigrating: SuperPlugin {
    /// 旧版本中使用过的插件目录名。已经使用自身 ID 的插件返回空数组即可。
    var legacyDataDirectoryNames: [String] { get }

    /// 在插件 `onBoot` 前迁移数据。
    func migrateData(context: PluginDataMigrationContext) throws
}

public extension PluginDataMigrating {
    var legacyDataDirectoryNames: [String] { [] }

    func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )
    }
}

/// 文件型插件迁移的通用实现。
///
/// 迁移采用复制而非移动，保留旧版本数据；目标中已有的项目不会被覆盖，
/// 因此中断后可以安全重试。
@MainActor
public enum PluginDataMigrationUtility {
    private static let markerFileName = ".lumi-storage-migration.json"

    public static func copyLegacyDirectories(
        legacyDirectoryNames: [String],
        context: PluginDataMigrationContext,
        fileManager: FileManager = .default
    ) throws {
        let destination = context.currentPluginDataDirectory
        let markerURL = destination.appendingPathComponent(Self.markerFileName)
        if migrationMarkerIsComplete(at: markerURL, context: context, fileManager: fileManager) {
            return
        }

        var sourceDirectoryNames = [context.pluginID]
        for legacyName in legacyDirectoryNames where !sourceDirectoryNames.contains(legacyName) {
            sourceDirectoryNames.append(legacyName)
        }
        let sources: [URL] = context.legacyDataRootDirectories.keys.sorted(by: >).flatMap { version in
            sourceDirectoryNames.compactMap { legacyName -> URL? in
                guard let source = context.legacyPluginDataDirectory(named: legacyName, in: version),
                      fileManager.fileExists(atPath: source.path),
                      source.hasDirectoryPath else {
                    return nil
                }
                return source
            }
        }
        guard !sources.isEmpty else { return }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for source in sources where source.standardizedFileURL != destination.standardizedFileURL {
            try mergeDirectoryContents(from: source, to: destination, fileManager: fileManager)
        }

        let marker: [String: Any] = [
            "completed": true,
            "fromVersions": context.legacyDataRootDirectories.keys.sorted(),
            "toVersion": context.currentMajorVersion,
            "completedAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let markerData = try JSONSerialization.data(withJSONObject: marker, options: [.sortedKeys])
        try markerData.write(to: markerURL, options: .atomic)
    }

    private static func migrationMarkerIsComplete(
        at markerURL: URL,
        context: PluginDataMigrationContext,
        fileManager: FileManager
    ) -> Bool {
        guard let data = try? Data(contentsOf: markerURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["completed"] as? Bool == true,
              object["toVersion"] as? Int == context.currentMajorVersion else {
            return false
        }
        return fileManager.fileExists(atPath: context.currentPluginDataDirectory.path)
    }

    /// 将一个旧目录的内容合并到目标目录；目标中已有文件不会被覆盖。
    public static func mergeDirectoryContents(
        from source: URL,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws {
        let items = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for item in items where item.lastPathComponent != markerFileName {
            let destinationItem = destination.appendingPathComponent(
                item.lastPathComponent,
                isDirectory: item.hasDirectoryPath
            )

            if fileManager.fileExists(atPath: destinationItem.path) {
                if item.hasDirectoryPath, isDirectory(destinationItem, fileManager: fileManager) {
                    try mergeDirectoryContents(from: item, to: destinationItem, fileManager: fileManager)
                }
                continue
            }

            try fileManager.copyItem(at: item, to: destinationItem)
        }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}
