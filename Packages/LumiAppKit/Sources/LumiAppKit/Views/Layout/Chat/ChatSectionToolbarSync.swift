import LumiChatKit
import LumiCoreKit
import SwiftUI

// MARK: - Chat Section Toolbar Sync

/// Synchronizes chat section toolbar items with the coordinator
struct ChatSectionToolbarSync: View {
    let items: [LumiChatSectionToolbarItem]
    @ObservedObject var coordinator: ChatSectionCoordinator

    private var syncKey: String {
        items.map(\.id).joined(separator: "|")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: syncKey, initial: true) { _, _ in
                coordinator.setChatSectionToolbarItems(items)
            }
    }
}
