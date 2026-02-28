import SwiftUI

struct NettoDashboardView: View {
    @StateObject private var service = FirewallService.shared
    @StateObject private var repo = AppSettingRepo.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Netto Firewall")
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
                    Text("Apps")
                        .font(.headline)
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
                    Text("Recent Events")
                        .font(.headline)
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

struct StatusBadge: View {
    let status: FilterStatus
    
    var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .error: return .orange
        case .indeterminate: return .gray
        }
    }
    
    var body: some View {
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

struct NettoAppRow: View {
    let app: SmartApp
    let isAllowed: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
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

struct EventRow: View {
    let event: FirewallEvent
    
    var body: some View {
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
