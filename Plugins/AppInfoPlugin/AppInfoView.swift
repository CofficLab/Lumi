import SwiftUI

/// 应用信息视图：显示完整的应用信息
struct AppInfoView: View {
    /// 从 Bundle 获取应用信息
    private let appInfo: DetailedAppInfo = DetailedAppInfo()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 应用图标和标题
                headerSection

                // 应用信息卡片
                appInfoCard

                // 版本信息卡片
                versionInfoCard

                // 系统信息卡片
                systemInfoCard

                // 技术栈卡片
                techStackCard

                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 20) {
            // 应用图标
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(18)
                    .shadow(radius: 5)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(appInfo.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text(appInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let version = appInfo.shortVersionString {
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
            AppInfoRow(label: "应用名称", value: appInfo.name)
            AppInfoRow(label: "Bundle ID", value: appInfo.bundleIdentifier)
            AppInfoRow(label: "开发团队", value: appInfo.developmentRegion ?? "Unknown")
            if let executableName = appInfo.executableName {
                AppInfoRow(label: "可执行文件", value: executableName)
            }
        }
    }

    private var versionInfoCard: some View {
        InfoCard(title: "版本信息", icon: "number.circle.fill") {
            AppInfoRow(label: "版本号", value: appInfo.shortVersionString ?? "Unknown")
            AppInfoRow(label: "构建号", value: appInfo.bundleVersion ?? "Unknown")
            AppInfoRow(label: "最低系统版本", value: appInfo.minimumOSVersion ?? "Unknown")
        }
    }

    private var systemInfoCard: some View {
        InfoCard(title: "系统信息", icon: "desktopcomputer") {
            AppInfoRow(label: "操作系统", value: systemVersion)
            AppInfoRow(label: "架构", value: architecture)
            AppInfoRow(label: "应用路径", value: appPath)
        }
    }

    private var techStackCard: some View {
        InfoCard(title: "技术栈", icon: "hammer.fill") {
            AppInfoRow(label: "语言", value: "Swift")
            AppInfoRow(label: "UI 框架", value: "SwiftUI")
            AppInfoRow(label: "最低系统", value: "macOS 15.0+")
            AppInfoRow(label: "架构模式", value: "MVVM + Plugin")
        }
    }

    // MARK: - Computed Properties

    private var systemVersion: String {
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersionString
        return osVersion
    }

    private var architecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        return machine
    }

    private var appPath: String {
        Bundle.main.bundlePath
    }
}

// MARK: - AppInfo Model

struct DetailedAppInfo {
    let name: String
    let bundleIdentifier: String
    let shortVersionString: String?
    let bundleVersion: String?
    let developmentRegion: String?
    let executableName: String?
    let minimumOSVersion: String?

    init() {
        let bundle = Bundle.main

        self.name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? "Unknown App"

        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.unknown.app"
        self.shortVersionString = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        self.bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.developmentRegion = bundle.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String
        self.executableName = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        self.minimumOSVersion = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String
    }
}

// MARK: - Info Card Component

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

// MARK: - Info Row Component

struct AppInfoRow: View {
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

#Preview("App Info View") {
    AppInfoView()
        .withDebugBar()
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
