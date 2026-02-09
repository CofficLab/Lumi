import SwiftUI

struct RClickSettingsView: View {
    @StateObject private var configManager = RClickConfigManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Right Click Menu Items")
                .font(.headline)
            
            Text("Select the items you want to appear in the Finder context menu.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            List {
                ForEach(configManager.config.items) { item in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in configManager.toggleItem(item) }
                        )) {
                            HStack {
                                Image(systemName: iconName(for: item.type))
                                Text(item.title)
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            
            Spacer()
            
            HStack {
                Image(systemName: "info.circle")
                Text("Changes require the Finder extension to be enabled in System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func iconName(for type: RClickActionType) -> String {
        switch type {
        case .newFile: return "doc.badge.plus"
        case .copyPath: return "link"
        case .openInTerminal: return "terminal"
        case .openInVSCode: return "hammer"
        }
    }
}
