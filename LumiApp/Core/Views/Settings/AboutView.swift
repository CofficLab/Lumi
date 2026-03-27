import SwiftUI

/// About view, displays app details
struct AboutView: View {
    /// App info
    private var appInfo: AppInfo {
        AppInfo()
    }

    /// Version info
    private var versionInfo: VersionInfo {
        VersionInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 顶部说明卡片
                headerCard

                // 应用信息卡片
                appInfoCard

                // 版本信息卡片
                versionInfoCard

                // 构建历史卡片
                buildHistoryCard

                // 系统信息卡片
                systemInfoCard

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("关于")
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "info.circle.fill",
                    title: "关于 Lumi",
                    subtitle: "了解应用的版本和系统信息"
                )

                GlassDivider()

                HStack(spacing: DesignTokens.Spacing.md) {
                    // 应用图标
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(appInfo.name)
                            .font(DesignTokens.Typography.bodyEmphasized)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        if let version = appInfo.version {
                            Text("版本 \(version)")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Info Cards

    private var appInfoCard: some View {
        GlassInfoCard(title: "应用信息", icon: "app.badge.fill") {
            GlassKeyValueRow(label: "应用名称", value: appInfo.name)
            GlassKeyValueRow(label: "Bundle ID", value: appInfo.bundleIdentifier)
            if let description = appInfo.description {
                GlassKeyValueRow(label: "描述", value: description)
            }
        }
    }

    private var versionInfoCard: some View {
        GlassInfoCard(title: "版本信息", icon: "number.circle.fill") {
            GlassKeyValueRow(label: "版本", value: appInfo.version ?? "未知")
            GlassKeyValueRow(label: "构建号", value: appInfo.build ?? "未知")
            GlassKeyValueRow(label: "构建配置", value: versionInfo.buildConfiguration)
            GlassKeyValueRow(label: "构建日期", value: versionInfo.buildDate)
        }
    }

    private var buildHistoryCard: some View {
        GlassInfoCard(title: "构建历史", icon: "clock.arrow.circlepath") {
            GlassKeyValueRow(label: "最低支持", value: "macOS \(versionInfo.minimumOSVersion)")
            GlassKeyValueRow(label: "SDK 版本", value: versionInfo.sdkVersion)
            GlassKeyValueRow(label: "Swift 版本", value: versionInfo.swiftVersion)
            GlassKeyValueRow(label: "Xcode 版本", value: versionInfo.xcodeVersion)
        }
    }

    private var systemInfoCard: some View {
        GlassInfoCard(title: "系统信息", icon: "desktopcomputer") {
            GlassKeyValueRow(label: "操作系统", value: versionInfo.systemVersion)
            GlassKeyValueRow(label: "架构", value: versionInfo.architecture)
            GlassKeyValueRow(label: "应用路径", value: versionInfo.appPath)
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

        // Basic info
        self.shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        self.buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        // Build configuration
        #if DEBUG
        self.buildConfiguration = "Debug"
        #else
        self.buildConfiguration = "Release"
        #endif

        // Build date
        if let buildDateString = bundle.object(forInfoDictionaryKey: "BuildDate") as? String {
            self.buildDate = buildDateString
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.buildDate = formatter.string(from: Date())
        }

        // System info
        self.minimumOSVersion = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String ?? "15.0"

        // SDK info
        self.sdkVersion = "macOS 26.2"

        // Swift version
        self.swiftVersion = "6.0"

        // Xcode version
        self.xcodeVersion = "17.2"

        // Architecture
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "Unknown"
            }
        }
        self.architecture = machine

        // System version
        let processInfo = ProcessInfo.processInfo
        self.systemVersion = processInfo.operatingSystemVersionString

        // App path
        self.appPath = bundle.bundlePath
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
