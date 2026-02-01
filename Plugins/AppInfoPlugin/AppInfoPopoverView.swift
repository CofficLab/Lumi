import SwiftUI

/// 应用信息弹出视图：显示应用详细信息
struct AppInfoPopoverView: View {
    /// 关闭 popover 的回调
    var dismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            headerSection

            Divider()

            // 应用信息区域
            appInfoSection

            Divider()

            // 版本信息区域
            versionSection

            Divider()

            // 操作按钮区域
            actionButtons
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - 标题区域

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftUI Template")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("现代化 macOS 应用模板")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - 应用信息区域

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用信息")
                .font(.subheadline)
                .fontWeight(.semibold)

            AppInfoRow(label: "应用名称", value: "SwiftUI Template")
            AppInfoRow(label: "Bundle ID", value: "com.nookery.swiftui-template")
            AppInfoRow(label: "开发团队", value: "Nookery")
            AppInfoRow(label: "语言", value: "Swift / SwiftUI")
        }
    }

    // MARK: - 版本信息区域

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("版本信息")
                .font(.subheadline)
                .fontWeight(.semibold)

            AppInfoRow(label: "版本号", value: "1.0.0")
            AppInfoRow(label: "构建号", value: "1")
            AppInfoRow(label: "Swift 版本", value: "6.0")
            AppInfoRow(label: "平台", value: "macOS 15.0+")
        }
    }

    // MARK: - 操作按钮区域

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: {
                // 打开设置
                dismiss()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("打开设置")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: {
                // 访问 GitHub
                if let url = URL(string: "https://github.com/Nookery/SwiftUI-Template") {
                    NSWorkspace.shared.open(url)
                }
                dismiss()
            }) {
                HStack {
                    Image(systemName: "link")
                    Text("访问 GitHub")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview

#Preview("App Info Popover View") {
    AppInfoPopoverView()
        .frame(width: 350, height: 500)
}
