import SwiftUI

/// 一条步骤数据,供 `LandingStepFlow` 渲染。
public struct LandingStep: Identifiable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let icon: String?

    public init(title: String, description: String, icon: String? = nil) {
        self.title = title
        self.description = description
        self.icon = icon
    }
}

/// 带连接竖线的编号步骤流。
///
/// 左侧是一条贯穿的「轨道」,圆点之间用细线相连,适合展示「工作原理 / 使用流程」。
/// 每一步出现时按索引错峰淡入。
public struct LandingStepFlow: View {
    @LumiTheme private var theme

    private let steps: [LandingStep]

    public init(steps: [LandingStep]) {
        self.steps = steps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(index, step, isLast: index == steps.count - 1)
                    .landingAppear(delay: Double(index) * 0.06)
            }
        }
    }

    private func stepRow(_ index: Int, _ step: LandingStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧轨道:圆点 + 连接线
            VStack(spacing: 0) {
                circle(index)
                if !isLast {
                    Rectangle()
                        .fill(theme.appDivider)
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 28)

            // 右侧文本
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                Text(step.description)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 22)
        }
    }

    private func circle(_ index: Int) -> some View {
        ZStack {
            Circle()
                .fill(theme.primary.opacity(0.15))
            if let icon = steps[index].icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)
            }
        }
        .frame(width: 28, height: 28)
    }
}

#Preview {
    LandingStepFlow(steps: [
        .init(title: "激活防休眠", description: "从菜单栏一键开启,或设定时长。", icon: "bolt.fill"),
        .init(title: "任务运行", description: "系统保持唤醒,可选手动关闭屏幕以省电。"),
        .init(title: "自动收尾", description: "定时模式下到点自动解除。")
    ])
    .padding()
    .frame(width: 420)
}
