import Foundation

enum HostEntryType: Equatable, Hashable {
    case entry(ip: String, domains: [String], isEnabled: Bool, comment: String?)
    case comment(String)
    case empty
    case groupHeader(String) // Special comment: # GROUP: Name
}

struct HostEntry: Identifiable, Hashable, Equatable {
    let id = UUID()
    var type: HostEntryType
    
    // Helper accessors
    var ip: String? {
        if case .entry(let ip, _, _, _) = type { return ip }
        return nil
    }
    
    var domains: [String] {
        if case .entry(_, let domains, _, _) = type { return domains }
        return []
    }
    
    var isEnabled: Bool {
        if case .entry(_, _, let enabled, _) = type { return enabled }
        return false
    }
    
    var groupName: String? {
        if case .groupHeader(let name) = type { return name }
        return nil
    }
}

class HostsParser {
    static func parse(content: String) -> [HostEntry] {
        var entries: [HostEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                entries.append(HostEntry(type: .empty))
                continue
            }
            
            if trimmed.hasPrefix("#") {
                // Check for Group Header
                if trimmed.hasPrefix("# GROUP:") {
                    let groupName = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    entries.append(HostEntry(type: .groupHeader(groupName)))
                    continue
                }
                
                // Check if it's a commented-out entry (Disabled)
                // Format: # 127.0.0.1 example.com
                let contentWithoutHash = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if let entry = parseEntryLine(contentWithoutHash, isEnabled: false) {
                    entries.append(HostEntry(type: entry))
                } else {
                    entries.append(HostEntry(type: .comment(trimmed)))
                }
                continue
            }
            
            // Standard Entry
            if let entry = parseEntryLine(trimmed, isEnabled: true) {
                entries.append(HostEntry(type: entry))
            } else {
                // Fallback, maybe garbage or comment without #?
                entries.append(HostEntry(type: .comment("# " + trimmed)))
            }
        }
        
        return entries
    }
    
    private static func parseEntryLine(_ line: String, isEnabled: Bool) -> HostEntryType? {
        // Remove inline comments
        let parts = line.components(separatedBy: "#")
        let cleanLine = parts[0].trimmingCharacters(in: .whitespaces)
        let comment = parts.count > 1 ? parts.dropFirst().joined(separator: "#").trimmingCharacters(in: .whitespaces) : nil
        
        let components = cleanLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 2 else { return nil }
        
        let ip = components[0]
        let domains = Array(components.dropFirst())
        
        // Basic IP Validation (Loose)
        if isValidIP(ip) {
            return .entry(ip: ip, domains: domains, isEnabled: isEnabled, comment: comment)
        }
        
        return nil
    }
    
    static func isValidIP(_ ip: String) -> Bool {
        // Simple regex for IPv4 and IPv6
        // IPv4
        let ipv4Regex = "^((\\d{1,3}\\.){3}\\d{1,3})$"
        // IPv6 (Simplified)
        let ipv6Regex = "^([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])$"
        
        let isIPv4 = ip.range(of: ipv4Regex, options: .regularExpression) != nil
        let isIPv6 = ip.range(of: ipv6Regex, options: .regularExpression) != nil
        
        return isIPv4 || isIPv6
    }
    
    static func serialize(entries: [HostEntry]) -> String {
        var output = ""
        
        for entry in entries {
            switch entry.type {
            case .empty:
                output += "\n"
            case .comment(let text):
                output += "\(text)\n"
            case .groupHeader(let name):
                output += "# GROUP: \(name)\n"
            case .entry(let ip, let domains, let isEnabled, let comment):
                let prefix = isEnabled ? "" : "# "
                let line = "\(ip) \(domains.joined(separator: " "))"
                let suffix = comment != nil ? " # \(comment!)" : ""
                output += "\(prefix)\(line)\(suffix)\n"
            }
        }
        
        return output
    }
}
