import SwiftUI
import LumiUI

public struct NettoDashboardView: View {
    @StateObject private var service = FirewallService.shared
    @StateObject private var repo = AppSettingRepo.shared
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(LumiPluginLocalization.string("Netto Firewall", bundle: .module))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                
                StatusBadge(status: service.status)
                
                Button(action: {
                    if service.status == .running {
                        service.stopFilter()
                    } else {
                        service.startFilter()
                    }
                }) {
                    Text(service.status == .running ? "Stop" : "Start")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            HSplitView {
                // Left: Apps List
                VStack(alignment: .leading) {
                    Text(LumiPluginLocalization.string("Apps", bundle: .module))
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    List {
                        ForEach(SmartApp.appList) { app in
                            NettoAppRow(app: app, isAllowed: repo.isAllowed(appId: app.id)) { allowed in
                                repo.setAllowed(appId: app.id, allowed: allowed)
                            }
                        }
                    }
                }
                .frame(minWidth: 200, maxWidth: .infinity)
                
                // Right: Events
                VStack(alignment: .leading) {
                    Text(LumiPluginLocalization.string("Recent Events", bundle: .module))
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    List(service.events) { event in
                        EventRow(event: event)
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
    }
}

public struct StatusBadge: View {
    public let status: FilterStatus
    
    public var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .error: return .orange
        case .indeterminate: return .gray
        }
    }
    
    public var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }
}

public struct NettoAppRow: View {
    public let app: SmartApp
    public let isAllowed: Bool
    public let onToggle: (Bool) -> Void
    
    public var body: some View {
        HStack {
            app.getIcon()
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading) {
                Text(app.name)
                    .font(.body)
                Text(app.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(get: { isAllowed }, set: { onToggle($0) }))
                .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}

public struct EventRow: View {
    public let event: FirewallEvent
    
    public var body: some View {
        HStack {
            Image(systemName: event.isAllowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(event.isAllowed ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(event.address + ":" + event.port)
                    .font(.system(.body, design: .monospaced))
                Text(event.sourceAppIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(event.timeFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
