import SwiftUI

/// 一条管线阶段数据,供 `LandingPipeline` 渲染。
public struct LandingStage: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let subtitle: String?

    public init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

/// 横向管线:阶段之间以箭头相连,适合展示「输入 → 处理 → 输出」式流程。
///
/// 与纵向的 `LandingStepFlow` 互补:管线强调「数据流向」,步骤流强调「先后顺序」。
public struct LandingPipeline: View {
    @LumiTheme private var theme

    private let stages: [LandingStage]
    private let tint: Color?

    private var accent: Color { tint ?? theme.primary }

    public init(tint: Color? = nil, stages: [LandingStage]) {
        self.tint = tint
        self.stages = stages
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                if index > 0 {
                    arrow
                }
                stageCell(stage)
            }
        }
        .landingAppear(delay: 0.05)
    }

    private func stageCell(_ stage: LandingStage) -> some View {
        VStack(spacing: 8) {
            Image(systemName: stage.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .background(
                    Circle().fill(accent.opacity(0.12))
                )
            Text(stage.title)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
            if let subtitle = stage.subtitle {
                Text(subtitle)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var arrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .frame(width: 20)
            .padding(.top, 14)
    }
}

#Preview {
    LandingPipeline(stages: [
        .init(icon: "film", title: "视频", subtitle: "任意常见格式"),
        .init(icon: "gearshape.2", title: "转码", subtitle: "FFmpeg 引擎"),
        .init(icon: "checkmark.seal", title: "输出", subtitle: "MP4 / GIF / 音频")
    ])
    .padding()
    .frame(width: 480)
}
