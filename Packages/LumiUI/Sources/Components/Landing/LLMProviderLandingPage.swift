import SwiftUI

/// LLM 提供商家族的共享落地页。
///
/// 各 LLM 提供商插件只传入自身的 `displayName` 与 `icon`,家族级的介绍内容
/// (对话 / Agent / 流式 / 多模型 / API 密钥)由本视图统一提供,保证同家族观感一致、
/// 又比旧版「一行字」丰富得多。
public struct LLMProviderLandingPage: View {
    private let displayName: String
    private let icon: String

    public init(displayName: String, icon: String) {
        self.displayName = displayName
        self.icon = icon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: icon,
                tagline: "把 \(displayName) 接入 Lumi:驱动对话与 Agent 工具调用,流式响应、按需切换模型。",
                chips: ["对话", "Agent", "流式响应", "多模型"],
                metrics: [
                    .init(value: "多", label: "模型可选"),
                    .init(value: "流式", label: "实时输出"),
                    .init(value: "API", label: "密钥配置")
                ]
            )
            .landingAppear()

            LandingSection(title: "核心能力", icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "bubble.left.and.bubble.right", title: "对话补全",
                          description: "为聊天与多轮对话提供大模型能力。"),
                    .init(icon: "wrench.and.screwdriver", title: "Agent 工具调用",
                          description: "支持工具调用,驱动 Agent 自动完成任务。"),
                    .init(icon: "waveform", title: "流式响应",
                          description: "逐字流式输出,响应即时可见。"),
                    .init(icon: "rectangle.stack", title: "多模型切换",
                          description: "在不同模型之间按需切换。")
                ])
            }
            .landingAppear(delay: 0.05)

            LandingSection(title: "上手三步", icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: "填入密钥", description: "在设置中配置该提供商的 API 密钥。", icon: "key.fill"),
                    .init(title: "选择提供商", description: "在模型选择里选用 \(displayName)。"),
                    .init(title: "开始使用", description: "即可在对话与 Agent 中调用。")
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }
}

#Preview {
    ScrollView {
        LLMProviderLandingPage(displayName: "OpenAI", icon: "sparkles")
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
