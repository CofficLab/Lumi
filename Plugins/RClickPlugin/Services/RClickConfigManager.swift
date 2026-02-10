import Foundation

@MainActor
class RClickConfigManager: ObservableObject {
    static let shared = RClickConfigManager()
    
    // TODO: Make sure to replace this with the actual App Group ID configured in Xcode
    private let appGroupId = "group.com.coffic.lumi"
    private let configKey = "RClickConfig"
    
    @Published var config: RClickConfig {
        didSet {
            saveConfig()
        }
    }
    
    private init() {
        self.config = RClickConfig.default
        loadConfig()
    }
    
    private var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }
    
    func loadConfig() {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: configKey) else {
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(RClickConfig.self, from: data)
            self.config = decoded
        } catch {
            print("Failed to decode RClickConfig: \(error)")
        }
    }
    
    func saveConfig() {
        guard let defaults = userDefaults else {
            print("Failed to access App Group UserDefaults: \(appGroupId)")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: configKey)
        } catch {
            print("Failed to encode RClickConfig: \(error)")
        }
    }
    
    func toggleItem(_ item: RClickMenuItem) {
        if let index = config.items.firstIndex(where: { $0.id == item.id }) {
            config.items[index].isEnabled.toggle()
        }
    }
    
    // MARK: - Template Management
    
    func toggleTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index].isEnabled.toggle()
        }
    }
    
    func addTemplate(_ template: NewFileTemplate) {
        config.fileTemplates.append(template)
    }
    
    func deleteTemplate(at offsets: IndexSet) {
        config.fileTemplates.remove(atOffsets: offsets)
    }
    
    func updateTemplate(_ template: NewFileTemplate) {
        if let index = config.fileTemplates.firstIndex(where: { $0.id == template.id }) {
            config.fileTemplates[index] = template
        }
    }
    
    func resetToDefaults() {
        self.config = RClickConfig.default
    }
}
