import Foundation
import OSLog

class AppSettingRepo: ObservableObject, @unchecked Sendable {
    static let shared = AppSettingRepo()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cofficlab.lumi", category: "AppSettingRepo")
    
    @Published var settings: [String: AppSetting] = [:]
    
    private let fileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pluginDir = appSupport.appendingPathComponent("Lumi/NettoPlugin")
        try? FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        self.fileURL = pluginDir.appendingPathComponent("settings.json")
        
        load()
    }
    
    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([AppSetting].self, from: data) {
            self.settings = Dictionary(uniqueKeysWithValues: decoded.map { ($0.appId, $0) })
        }
    }
    
    func save() {
        let array = Array(settings.values)
        if let data = try? JSONEncoder().encode(array) {
            try? data.write(to: fileURL)
        }
    }
    
    func getSetting(for appId: String) -> AppSetting? {
        return settings[appId]
    }
    
    func updateSetting(_ setting: AppSetting) {
        settings[setting.appId] = setting
        save()
    }
    
    func isAllowed(appId: String) -> Bool {
        // Default to allowed if no setting exists? Or blocked?
        // Netto seems to prompt user. 
        // If we have a setting, use it.
        return settings[appId]?.allowed ?? true // Default policy?
    }
    
    func setAllowed(appId: String, allowed: Bool) {
        let setting = AppSetting(appId: appId, allowed: allowed)
        updateSetting(setting)
    }
}
