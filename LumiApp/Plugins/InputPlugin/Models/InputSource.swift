import Foundation
import Carbon

struct InputSource: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: String
    let isSelectable: Bool
    
    // TISInputSource is not Codable, so we store properties.
    // We can't store the TISInputSourceRef directly for persistence, 
    // but we can look it up by ID when needed.
    
    init(tisSource: TISInputSource) {
        self.id = InputSource.getProperty(source: tisSource, key: kTISPropertyInputSourceID) as? String ?? "unknown"
        self.name = InputSource.getProperty(source: tisSource, key: kTISPropertyLocalizedName) as? String ?? "unknown"
        self.category = InputSource.getProperty(source: tisSource, key: kTISPropertyInputSourceCategory) as? String ?? "unknown"
        self.isSelectable = InputSource.getProperty(source: tisSource, key: kTISPropertyInputSourceIsSelectCapable) as? Bool ?? false
    }
    
    init(id: String, name: String, category: String, isSelectable: Bool) {
        self.id = id
        self.name = name
        self.category = category
        self.isSelectable = isSelectable
    }
    
    static func getProperty(source: TISInputSource, key: CFString) -> Any? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
    }
    
    static func getAll() -> [InputSource] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return sourceList.map { InputSource(tisSource: $0) }
    }
    
    static func current() -> InputSource? {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return InputSource(tisSource: currentSource)
    }
    
    @discardableResult
    func select() -> Bool {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        
        // Find the TISInputSource by ID
        if let target = sourceList.first(where: { 
            let id = InputSource.getProperty(source: $0, key: kTISPropertyInputSourceID) as? String
            return id == self.id 
        }) {
            let status = TISSelectInputSource(target)
            return status == noErr
        }
        return false
    }
}
