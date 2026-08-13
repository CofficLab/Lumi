import SwiftUI
import KernelLumi
import LumiUI

/// 单个工具的展示行:图标 + 名称 + 描述,右侧显示参数数量。
public struct ToolManagerToolRowView: View {
    let tool: any LumiAgentTool

    public init(tool: any LumiAgentTool) {
        self.tool = tool
    }

    public var body: some View {
        AppSettingRow(
            title: tool.name,
            description: tool.toolDescription,
            icon: "wrench.and.screwdriver"
        ) {
            EmptyView()
        }
    }
}
