import Foundation
import SuperLogKit
import SwiftUI
import Combine

@MainActor
public class HostsManagerViewModel: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true
    @Published var entries: [HostEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedGroup: String?
    
    // Group Management
    public var groups: [String] {
        var groupNames: Set<String> = []
        var currentGroup: String? = nil
        
        for entry in entries {
            if case .groupHeader(let name) = entry.type {
                currentGroup = name
                groupNames.insert(name)
            } else if case .entry = entry.type, let group = currentGroup {
                // Implicitly belongs to current group header
                _ = group
            }
        }
        return Array(groupNames).sorted()
    }
    
    public var filteredEntries: [HostEntry] {
        var result: [HostEntry] = []
        var currentGroup: String? = nil
        
        for entry in entries {
            // Track Group
            if case .groupHeader(let name) = entry.type {
                currentGroup = name
                if selectedGroup == nil || selectedGroup == name {
                    result.append(entry)
                }
                continue
            }
            
            // Filter by Group
            if let selectedGroup = selectedGroup, currentGroup != selectedGroup {
                continue
            }
            
            // Filter by Search Text
            if !searchText.isEmpty {
                switch entry.type {
                case .entry(let ip, let domains, _, let comment):
                    let matchesIp = ip.contains(searchText)
                    let matchesDomain = domains.contains { $0.localizedCaseInsensitiveContains(searchText) }
                    let matchesComment = comment?.localizedCaseInsensitiveContains(searchText) ?? false
                    if matchesIp || matchesDomain || matchesComment {
                        result.append(entry)
                    }
                case .comment(let text):
                     if text.localizedCaseInsensitiveContains(searchText) {
                         result.append(entry)
                     }
                default:
                    break
                }
            } else {
                result.append(entry)
            }
        }
        
        return result
    }
    
    public func loadHosts() async {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Loading hosts file")
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            let content = try await HostsFileService.shared.readHosts()
            self.entries = HostsParser.parse(content: content)
            if Self.verbose {
                if HostsManagerPlugin.verbose {
                                    HostsManagerPlugin.logger.info("\(self.t)Hosts file loaded successfully: \(self.entries.count) entries")
                }
            }
        } catch {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.error("\(self.t)Failed to load hosts file: \(error.localizedDescription)")
            }
            errorMessage = "Load failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    public func saveHosts() async {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Saving hosts file")
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            let content = HostsParser.serialize(entries: entries)
            try await HostsFileService.shared.saveHosts(content: content)
            if Self.verbose {
                if HostsManagerPlugin.verbose {
                                    HostsManagerPlugin.logger.info("\(self.t)Hosts file saved successfully")
                }
            }
            // Reload to reflect changes (and formatting)
            await loadHosts()
        } catch {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.error("\(self.t)Failed to save hosts file: \(error.localizedDescription)")
            }
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    public func toggleEntry(_ entry: HostEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        
        if case .entry(let ip, let domains, let isEnabled, let comment) = entries[index].type {
            entries[index].type = .entry(ip: ip, domains: domains, isEnabled: !isEnabled, comment: comment)
            Task {
                await saveHosts()
            }
        }
    }
    
    public func addEntry(ip: String, domain: String, comment: String?, group: String?) {
        let normalizedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let domains = HostsParser.normalizedDomains(from: domain)

        guard isValidIP(normalizedIP),
              !domains.isEmpty,
              domains.allSatisfy(HostsParser.isValidDomain) else {
            errorMessage = "Invalid host entry"
            return
        }

        let normalizedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGroup = group?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newEntry = HostEntry(
            type: .entry(
                ip: normalizedIP,
                domains: domains,
                isEnabled: true,
                comment: normalizedComment?.isEmpty == false ? normalizedComment : nil
            )
        )
        
        if let group = normalizedGroup, !group.isEmpty {
            // Check if group exists
            if let groupIndex = entries.firstIndex(where: {
                if case .groupHeader(let name) = $0.type, name == group { return true }
                return false
            }) {
                // Add after group header
                entries.insert(newEntry, at: groupIndex + 1)
            } else {
                // Add new group at end
                entries.append(HostEntry(type: .empty))
                entries.append(HostEntry(type: .groupHeader(group)))
                entries.append(newEntry)
            }
        } else {
            // Add to end
            entries.append(newEntry)
        }
        
        Task {
            await saveHosts()
        }
    }
    
    public func deleteEntry(_ entry: HostEntry) {
        entries.removeAll { $0.id == entry.id }
        Task {
            await saveHosts()
        }
    }
    
    public func isValidIP(_ ip: String) -> Bool {
        return HostsParser.isValidIP(ip)
    }

    public func isValidDomainList(_ domain: String) -> Bool {
        let domains = HostsParser.normalizedDomains(from: domain)
        return !domains.isEmpty && domains.allSatisfy(HostsParser.isValidDomain)
    }
}
