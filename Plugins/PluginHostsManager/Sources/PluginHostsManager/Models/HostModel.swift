import Darwin
import Foundation

public enum HostEntryType: Equatable, Hashable {
    case entry(ip: String, domains: [String], isEnabled: Bool, comment: String?)
    case comment(String)
    case empty
    case groupHeader(String) // Special comment: # GROUP: Name
}

public struct HostEntry: Identifiable, Hashable, Equatable {
    public let id = UUID()
    public var type: HostEntryType
    
    // Helper accessors
    public var ip: String? {
        if case .entry(let ip, _, _, _) = type { return ip }
        return nil
    }
    
    public var domains: [String] {
        if case .entry(_, let domains, _, _) = type { return domains }
        return []
    }
    
    public var isEnabled: Bool {
        if case .entry(_, _, let enabled, _) = type { return enabled }
        return false
    }
    
    public var groupName: String? {
        if case .groupHeader(let name) = type { return name }
        return nil
    }
}

public class HostsParser {
    public static func parse(content: String) -> [HostEntry] {
        var entries: [HostEntry] = []
        let lines = content.components(separatedBy: .newlines)
        let hasTerminatingNewline = content.unicodeScalars.last.map(CharacterSet.newlines.contains) ?? false
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if hasTerminatingNewline, index == lines.indices.last, trimmed.isEmpty {
                continue
            }
            
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
    
    public static func isValidIP(_ ip: String) -> Bool {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty, trimmedIP == ip else { return false }

        var ipv4Address = in_addr()
        if trimmedIP.withCString({ inet_pton(AF_INET, $0, &ipv4Address) }) == 1 {
            return true
        }

        var ipv6Address = in6_addr()
        return trimmedIP.withCString { inet_pton(AF_INET6, $0, &ipv6Address) } == 1
    }
    
    public static func serialize(entries: [HostEntry]) -> String {
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
