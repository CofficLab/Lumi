import SwiftUI

/// 关于页面视图，显示应用详细信息
struct AboutView: View {
    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    /// 版本信息
    private var versionInfo: VersionInfo {
        VersionInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 应用图标和标题
                headerSection

                // 应用信息卡片
                appInfoCard

                // 版本信息卡片
                versionInfoCard

                // 构建历史卡片
                buildHistoryCard

                // 系统信息卡片
                systemInfoCard

                // 更新信息卡片
                updateInfoCard

                Spacer()
            }
            .padding(32)
        }
        .navigationTitle("关于")
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 20) {
            // 应用图标
            LogoView(variant: .about)
                .frame(width: 80, height: 80)
                .cornerRadius(18)
                .shadow(radius: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(appInfo.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text(appInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let version = appInfo.version {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Info Cards

    private var appInfoCard: some View {
        InfoCard(title: "应用信息", icon: "info.circle.fill") {
            AboutInfoRow(label: "应用名称", value: appInfo.name)
            AboutInfoRow(label: "Bundle ID", value: appInfo.bundleIdentifier)
            if let description = appInfo.description {
                AboutInfoRow(label: "描述", value: description)
            }
        }
    }

    private var versionInfoCard: some View {
        InfoCard(title: "版本信息", icon: "number.circle.fill") {
            AboutInfoRow(label: "版本号", value: appInfo.version ?? "Unknown")
            AboutInfoRow(label: "构建号", value: appInfo.build ?? "Unknown")
            AboutInfoRow(label: "构建类型", value: versionInfo.buildConfiguration)
            AboutInfoRow(label: "构建时间", value: versionInfo.buildDate)
        }
    }

    private var buildHistoryCard: some View {
        InfoCard(title: "构建历史", icon: "clock.arrow.circlepath") {
            AboutInfoRow(label: "最低支持", value: "macOS \(versionInfo.minimumOSVersion)")
            AboutInfoRow(label: "SDK 版本", value: versionInfo.sdkVersion)
            AboutInfoRow(label: "Swift 版本", value: versionInfo.swiftVersion)
            AboutInfoRow(label: "Xcode 版本", value: versionInfo.xcodeVersion)
        }
    }

    private var systemInfoCard: some View {
        InfoCard(title: "系统信息", icon: "desktopcomputer") {
            AboutInfoRow(label: "操作系统", value: versionInfo.systemVersion)
            AboutInfoRow(label: "架构", value: versionInfo.architecture)
            AboutInfoRow(label: "应用路径", value: versionInfo.appPath)
        }
    }

    private var updateInfoCard: some View {
        InfoCard(title: "更新信息", icon: "arrow.down.circle.fill") {
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

// MARK: - AppInfo Model

struct AppInfo {
    let name: String
    let version: String?
    let build: String?
    let bundleIdentifier: String
    let description: String?

    init() {
        let bundle = Bundle.main
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Lumi"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.lumi.app"
        self.description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String
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
    let systemVersion: String
    let appPath: String

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

        // 构建时间
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
        self.sdkVersion = "macOS 26.2"

        // Swift 版本
        self.swiftVersion = "6.0"

        // Xcode 版本
        self.xcodeVersion = "17.2"

        // 架构
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        self.architecture = machine

        // 系统版本
        let processInfo = ProcessInfo.processInfo
        self.systemVersion = processInfo.operatingSystemVersionString

        // 应用路径
        self.appPath = bundle.bundlePath
    }
}

// MARK: - InfoCard Component

struct InfoCard<Content: View>: View {
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

// MARK: - AboutInfoRow Component

struct AboutInfoRow: View {
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

// MARK: - Preview

#Preview {
    AboutView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
