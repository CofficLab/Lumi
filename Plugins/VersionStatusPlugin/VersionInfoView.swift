import SwiftUI

/// 版本信息视图：显示详细的版本和构建信息
struct VersionInfoView: View {
    /// 版本信息数据
    private let versionInfo = VersionInfo()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 版本号标题卡片
                versionHeaderCard

                // 当前版本信息
                currentVersionCard

                // 构建历史卡片
                buildHistoryCard

                // 系统要求卡片
                systemRequirementsCard

                // 更新信息卡片
                updateInfoCard

                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Version Header Card

    private var versionHeaderCard: some View {
        VStack(spacing: 16) {
            // 大图标
            Image(systemName: "number.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 版本号
            VStack(spacing: 8) {
                Text("v\(versionInfo.shortVersion)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Build \(versionInfo.buildVersion)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Info Cards

    private var currentVersionCard: some View {
        VersionInfoCard(title: "当前版本", icon: "info.circle.fill") {
            VersionInfoRow(label: "版本号", value: "v\(versionInfo.shortVersion)")
            VersionInfoRow(label: "构建号", value: versionInfo.buildVersion)
            VersionInfoRow(label: "构建类型", value: versionInfo.buildConfiguration)
            VersionInfoRow(label: "构建时间", value: versionInfo.buildDate)
        }
    }

    private var buildHistoryCard: some View {
        VersionInfoCard(title: "构建历史", icon: "clock.arrow.circlepath") {
            VersionInfoRow(label: "最低支持", value: "macOS \(versionInfo.minimumOSVersion)")
            VersionInfoRow(label: "SDK 版本", value: versionInfo.sdkVersion)
            VersionInfoRow(label: "Swift 版本", value: versionInfo.swiftVersion)
            VersionInfoRow(label: "Xcode 版本", value: versionInfo.xcodeVersion)
        }
    }

    private var systemRequirementsCard: some View {
        VersionInfoCard(title: "系统要求", icon: "cpu") {
            VersionInfoRow(label: "操作系统", value: "macOS \(versionInfo.minimumOSVersion) 或更高")
            VersionInfoRow(label: "架构", value: versionInfo.architecture)
            VersionInfoRow(label: "磁盘空间", value: "约 100 MB")
            VersionInfoRow(label: "内存", value: "建议 4 GB 以上")
        }
    }

    private var updateInfoCard: some View {
        VersionInfoCard(title: "更新信息", icon: "arrow.down.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("当前版本是最新稳定版本")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Lumi 使用 Sparkle 框架进行自动更新。当有新版本可用时，应用会自动提示您更新。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - VersionInfo Model

struct VersionInfo {
    let shortVersion: String
    let buildVersion: String
    let buildConfiguration: String
    let buildDate: String
    let minimumOSVersion: String
    let sdkVersion: String
    let swiftVersion: String
    let xcodeVersion: String
    let architecture: String

    init() {
        let bundle = Bundle.main

        // 基本信息
        self.shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        self.buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        // 构建配置
        #if DEBUG
        self.buildConfiguration = "Debug"
        #else
        self.buildConfiguration = "Release"
        #endif

        // 构建时间（从编译时获取或使用当前时间）
        if let buildDateString = bundle.object(forInfoDictionaryKey: "BuildDate") as? String {
            self.buildDate = buildDateString
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.buildDate = formatter.string(from: Date())
        }

        // 系统信息
        self.minimumOSVersion = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String ?? "15.0"

        // SDK 信息
        self.sdkVersion = "macOS 26.2" // 可以从环境变量或配置获取

        // Swift 版本
        self.swiftVersion = "6.0" // 可以从环境变量获取

        // Xcode 版本
        self.xcodeVersion = "17.2" // 可以从环境变量获取

        // 架构
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        self.architecture = machine
    }
}

// MARK: - VersionInfoRow Component

struct VersionInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(":")
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - VersionInfoCard Component

struct VersionInfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 卡片标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Version Info View") {
    VersionInfoView()
        .frame(width: 600, height: 700)
}
