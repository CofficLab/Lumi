import Foundation
import GitHubKit
import os
import SuperLogKit

public final class GitHubPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-tools.local-store")

    nonisolated(unsafe) public static var dbFolderURLProvider: @Sendable () -> URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
    }

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "GitHubPluginLocalStore.queue", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    public convenience init() {
        self.init(settingsDirectory: Self.dbFolderURLProvider()
            .appendingPathComponent("GitHubPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true))
    }

    init(settingsDirectory root: URL) {
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
        do {
            try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create GitHub tools settings directory failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func migrateLegacyValueIfMissing(forKey key: String) -> Bool {
        guard object(forKey: key) == nil else { return true }
        guard let legacy = readLegacyObject(forKey: key) else { return true }
        return set(legacy, forKey: key)
    }

    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync {
            var dict = readDict()
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
            return writeDict(dict)
        }
    }

    public func object(forKey key: String) -> Any? { queue.sync { readDict()[key] } }
    public func string(forKey key: String) -> String? { object(forKey: key) as? String }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read GitHub tools settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read GitHub tools settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(self.t)Encode GitHub tools settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = settingsDirectory.appendingPathComponent("settings.tmp")
        do {
            try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) { _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp) }
            else { try fileManager.moveItem(at: tmp, to: settingsFileURL) }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist GitHub tools settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
            return false
        }
    }

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt GitHub tools settings failed: \(error.localizedDescription)")
        }
    }

    private func readLegacyObject(forKey key: String) -> Any? {
        let legacyDir = Self.dbFolderURLProvider().appendingPathComponent("app_settings", isDirectory: true)
        let legacyFile = legacyDir.appendingPathComponent(sanitize(key) + ".plist")
        guard fileManager.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        if let dict = plist as? [String: Any], let dataVal = dict["_data"] as? Data { return dataVal }
        return plist
    }

    private func sanitize(_ key: String) -> String {
        let safe = key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }.joined()
        return safe.isEmpty ? "key" : safe
    }
}

extension GitHubPluginLocalStore: GitHubTokenProviding {
    public var accessToken: String? {
        string(forKey: "GitHubToken")
    }
}
