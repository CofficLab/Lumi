import SwiftUI
import LumiCoreKit

public struct AutoTabContent: View {
    @EnvironmentObject private var llmVM: AppLLMVM

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto", bundle: .module)
                        .font(.system(size: 20, weight: .semibold))
                    Text("根据消息内容、工具需求、模型能力和可用性自动选择模型。", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
            }

            Toggle("启用 Auto 模型路由", isOn: $llmVM.isAutoMode)
                .toggleStyle(.switch)

            if let summary = llmVM.lastAutoRouteSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近一次路由", bundle: .module)
                        .font(.system(size: 13, weight: .semibold))
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.adaptive(light: "F5F5F7", dark: "1C1C1E"))
                )
            }

            Text("当前为基础路由版本：不可用模型会被排除，已检测可用模型优先；未检测模型仍可作为候选。", bundle: .module)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
