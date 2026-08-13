import SwiftUI

/// 「打开方式」家族的共享落地页。
///
/// 各「Open in X」插件传入 `displayName`、`icon` 与一句话 `appDescription`,
/// 家族级的「头部按钮一键打开」介绍由本视图统一提供。
public struct OpenInLandingPage: View {
    private let displayName: String
    private let icon: String
    private let appDescription: String

    public init(displayName: String, icon: String, appDescription: String) {
        self.displayName = displayName
        self.icon = icon
        self.appDescription = appDescription
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: icon,
                tagline: appDescription,
                chips: ["头部按钮", "一键打开", "当前项目"],
                metrics: [
                    .init(value: "1", label: "键点击"),
                    .init(value: "当前", label: "项目"),
                    .init(value: "外部", label: "应用")
                ]
            )
            .landingAppear()

            LandingSpotlight(
                icon: "arrow.up.right.square",
                title: "在 \(displayName) 中打开当前项目",
                message: "识别当前项目路径,点击头部按钮即可在外部应用中打开,无需手动定位。"
            )
            .landingAppear(delay: 0.05)

            LandingSection(title: "工作原理", icon: "gearshape.2") {
                LandingStepFlow(steps: [
                    .init(title: "识别项目", description: "读取当前正在编辑的项目路径。", icon: "folder"),
                    .init(title: "点击按钮", description: "在头部点击对应的打开按钮。"),
                    .init(title: "外部打开", description: "在外部应用中直接打开该项目。")
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }
}

#Preview {
    ScrollView {
        OpenInLandingPage(
            displayName: "Open in VSCode",
            icon: "chevron.left.forwardslash.chevron.right",
            appDescription: "Open current project in Visual Studio Code"
        )
        .padding(22)
    }
    .frame(width: 560, height: 800)
}
