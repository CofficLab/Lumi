import SwiftUI

/// DevAssistant 头部包装视图 - 管理头部所需的状态
struct DevAssistantHeaderView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var isProjectSelectorPresented = false
    @State private var isMCPSettingsPresented = false

    var body: some View {
        ChatHeaderView(
            isProjectSelectorPresented: $isProjectSelectorPresented,
            isMCPSettingsPresented: $isMCPSettingsPresented
        )
        .popover(isPresented: $isMCPSettingsPresented, arrowEdge: .top) {
            MCPSettingsView()
        }
        .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
            ProjectSelectorView(isPresented: $isProjectSelectorPresented)
                .frame(width: 400, height: 500)
        }
    }
}
