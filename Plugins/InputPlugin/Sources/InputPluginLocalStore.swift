import Foundation
import LumiCoreKit
import os
import SuperLogKit

public final class InputPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input.local-store")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "InputPluginLocalStore.queue", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    public convenience init() {
        self.init(settingsDirectory: (InputPluginRuntimeBridge.dataRootDirectory ?? InputPluginRuntimeBridge.fallbackRootDirectory)
            .appendingPathComponent("InputPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true))
    }

    init(settingsDirectory root: URL) {
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
        do {
            try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create input plugin settings directory failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func migrateLegacyValueIfMissing(forKey key: String) -> Bool {
        guard data(forKey: key) == nil else { return true }
        guard let legacy = readLegacyObject(forKey: key) else { return true }
        return set(legacy, forKey: key)
    }

    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync {
            guard var dict = readDict() else {
                return false
            }
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
            return writeDict(dict)
        }
    }

    public func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    public func object(forKey key: String) -> Any? { queue.sync { readDict()?[key] } }

    private func readDict() -> [String: Any]? {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read input plugin settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read input plugin settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Encode input plugin settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Persist input plugin settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Quarantine corrupt input plugin settings failed: \(error.localizedDescription)")
        }
    }

    private func readLegacyObject(forKey key: String) -> Any? {
        let legacyDir = (InputPluginRuntimeBridge.dataRootDirectory ?? InputPluginRuntimeBridge.fallbackRootDirectory)
            .appendingPathComponent("app_settings", isDirectory: true)
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
