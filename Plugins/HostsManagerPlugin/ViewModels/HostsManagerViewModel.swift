import Foundation
import SwiftUI
import Combine
import OSLog
import MagicKit

@MainActor
class HostsManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    @Published var entries: [HostEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedGroup: String?
    
    // Group Management
    var groups: [String] {
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
    
    var filteredEntries: [HostEntry] {
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
    
    func loadHosts() async {
        if Self.verbose {
            os_log("\(self.t)加载 hosts 文件")
        }
        isLoading = true
        errorMessage = nil
        do {
            let content = try await HostsFileService.shared.readHosts()
            self.entries = HostsParser.parse(content: content)
            if Self.verbose {
                os_log("\(self.t)hosts 文件加载成功: \(self.entries.count) 个条目")
            }
        } catch {
            os_log(.error, "\(self.t)加载 hosts 文件失败: \(error.localizedDescription)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func saveHosts() async {
        if Self.verbose {
            os_log("\(self.t)保存 hosts 文件")
        }
        isLoading = true
        errorMessage = nil
        do {
            let content = HostsParser.serialize(entries: entries)
            try await HostsFileService.shared.saveHosts(content: content)
            if Self.verbose {
                os_log("\(self.t)hosts 文件保存成功")
            }
            // Reload to reflect changes (and formatting)
            await loadHosts()
        } catch {
            os_log(.error, "\(self.t)保存 hosts 文件失败: \(error.localizedDescription)")
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func toggleEntry(_ entry: HostEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        
        if case .entry(let ip, let domains, let isEnabled, let comment) = entries[index].type {
            entries[index].type = .entry(ip: ip, domains: domains, isEnabled: !isEnabled, comment: comment)
            Task {
                await saveHosts()
            }
        }
    }
    
    func addEntry(ip: String, domain: String, comment: String?, group: String?) {
        let newEntry = HostEntry(type: .entry(ip: ip, domains: [domain], isEnabled: true, comment: comment))
        
        if let group = group, !group.isEmpty {
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
    
    func deleteEntry(_ entry: HostEntry) {
        entries.removeAll { $0.id == entry.id }
        Task {
            await saveHosts()
        }
    }
    
    func isValidIP(_ ip: String) -> Bool {
        return HostsParser.isValidIP(ip)
    }
}
