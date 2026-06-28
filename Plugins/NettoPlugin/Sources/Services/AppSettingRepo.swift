import Foundation
import os
import SuperLogKit

public class AppSettingRepo: ObservableObject, SuperLog, @unchecked Sendable {
    public static let shared = AppSettingRepo()
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    
    @Published var settings: [String: AppSetting] = [:]
    
    private let fileURL: URL
    
    private init() {
        self.fileURL = Self.defaultSettingsFileURL()
        load()
    }

    init(fileURL: URL, loadImmediately: Bool = true) {
        self.fileURL = fileURL
        if loadImmediately {
            load()
        }
    }

    private static func defaultSettingsFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let pluginDir = appSupport.appendingPathComponent("Lumi/NettoPlugin")
        do {
            try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        } catch {
            Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
                .error("Failed to create Netto settings directory: \(error.localizedDescription)")
        }
        return pluginDir.appendingPathComponent("settings.json")
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([AppSetting].self, from: data)
            self.settings = Self.settingsByAppId(decoded)
        } catch {
            logger.error("\(Self.t)Failed to load Netto settings, preserving corrupt file: \(error.localizedDescription)")
            preserveCorruptSettingsFile()
            self.settings = [:]
        }
    }
    
    public func save() {
        let array = Array(settings.values)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(array)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("\(Self.t)Failed to save Netto settings: \(error.localizedDescription)")
        }
    }
    
    public func getSetting(for appId: String) -> AppSetting? {
        return settings[appId]
    }
    
    public func updateSetting(_ setting: AppSetting) {
        settings[setting.appId] = setting
        save()
    }
    
    public func isAllowed(appId: String) -> Bool {
        // Default to allowed if no setting exists? Or blocked?
        // Netto seems to prompt user. 
        // If we have a setting, use it.
        return settings[appId]?.allowed ?? true // Default policy?
    }
    
    public func setAllowed(appId: String, allowed: Bool) {
        let setting = AppSetting(appId: appId, allowed: allowed)
        updateSetting(setting)
    }

    private static func settingsByAppId(_ settings: [AppSetting]) -> [String: AppSetting] {
        var result: [String: AppSetting] = [:]
        for setting in settings {
            result[setting.appId] = setting
        }
        return result
    }

    private func preserveCorruptSettingsFile() {
        let backupURL = fileURL.appendingPathExtension("corrupt")
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.moveItem(at: fileURL, to: backupURL)
        } catch {
            logger.error("\(Self.t)Failed to move corrupt Netto settings aside: \(error.localizedDescription)")
        }
    }
}
